const express = require('express');
const MedicalRecord = require('../models/MedicalRecord');
const Appointment = require('../models/Appointment');
const Clinic = require('../models/Clinic');
const User = require('../models/User');
const auth = require('../middleware/auth');
const upload = require('../middleware/upload');

const router = express.Router();

async function getAdminClinicIds(userId) {
  const admin = await User.findById(userId).select('clinics');
  const clinicIds = new Set();
  (admin?.clinics || []).forEach((id) => clinicIds.add(id.toString()));
  const ownedClinics = await Clinic.find({ admin: userId }).select('_id');
  ownedClinics.forEach((clinic) => clinicIds.add(clinic._id.toString()));
  return Array.from(clinicIds);
}

function idsEqual(left, right) {
  if (!left || !right) return false;
  return left.toString() === right.toString();
}

async function filterAccessibleRecords(records, user, adminClinicIds = []) {
  const appointmentIds = records
    .map((record) => record.appointment)
    .filter(Boolean)
    .map((appointmentId) => appointmentId.toString());

  if (appointmentIds.length === 0) {
    return records.filter((record) => {
      if (user.role === 'doctor') {
        return idsEqual(record.doctor, user.id);
      }
      if (user.role === 'admin') {
        return record.appointment == null && idsEqual(record.createdBy, user.id);
      }
      return true;
    });
  }

  const appointments = await Appointment.find({ _id: { $in: appointmentIds } }).select(
    'patient doctor clinic',
  );
  const appointmentMap = new Map(
    appointments.map((appointment) => [appointment._id.toString(), appointment]),
  );

  return records.filter((record) => {
    if (!record.appointment) {
      if (user.role === 'doctor') {
        return idsEqual(record.doctor, user.id);
      }
      if (user.role === 'admin') {
        return idsEqual(record.createdBy, user.id);
      }
      return true;
    }

    const appointment = appointmentMap.get(record.appointment.toString());
    if (!appointment) {
      return false;
    }
    if (!idsEqual(appointment.patient, record.patient)) {
      return false;
    }
    if (!idsEqual(appointment.doctor, record.doctor)) {
      return false;
    }
    if (user.role === 'doctor') {
      return idsEqual(appointment.doctor, user.id);
    }
    if (user.role === 'admin') {
      return adminClinicIds.includes(appointment.clinic.toString());
    }
    return true;
  });
}

router.post(
  '/',
  auth(['doctor', 'admin', 'superadmin']),
  upload.array('files', 5),
  async (req, res) => {
    try {
      const { patientId, appointmentId, title, description, tags } = req.body;
      if (!patientId) {
        return res.status(400).json({ message: 'Не указан пациент для медицинской записи.' });
      }

      let adminClinicIds = [];
      if (req.user.role === 'admin') {
        adminClinicIds = await getAdminClinicIds(req.user.id);
        if (adminClinicIds.length === 0) {
          return res.status(403).json({ message: 'Нет доступа к клиникам для создания записи.' });
        }
      }

      let relatedAppointment = null;
      if (appointmentId) {
        relatedAppointment = await Appointment.findById(appointmentId).select('patient doctor clinic');
        if (!relatedAppointment) {
          return res.status(400).json({ message: 'Указанный приём не найден.' });
        }
        if (!idsEqual(relatedAppointment.patient, patientId)) {
          return res.status(400).json({ message: 'Пациент не совпадает с выбранным приёмом.' });
        }
        if (req.user.role === 'doctor' && !idsEqual(relatedAppointment.doctor, req.user.id)) {
          return res.status(403).json({ message: 'Можно создавать записи только по своим приёмам.' });
        }
        if (
          req.user.role === 'admin' &&
          !adminClinicIds.includes(relatedAppointment.clinic.toString())
        ) {
          return res.status(403).json({ message: 'Нет доступа к клинике этого приёма.' });
        }
      } else if (req.user.role === 'doctor') {
        const hasPatientAccess = await Appointment.exists({ patient: patientId, doctor: req.user.id });
        if (!hasPatientAccess) {
          return res
            .status(403)
            .json({ message: 'Можно создавать записи только для своих пациентов.' });
        }
      } else if (req.user.role === 'admin') {
        const hasPatientAccess = await Appointment.exists({
          patient: patientId,
          clinic: { $in: adminClinicIds },
        });
        if (!hasPatientAccess) {
          return res
            .status(403)
            .json({ message: 'Можно создавать записи только для пациентов своих клиник.' });
        }
      }

      let toothMap = req.body.toothMap;
      if (typeof toothMap === 'string') {
        try {
          toothMap = JSON.parse(toothMap);
        } catch (_) {
          toothMap = [];
        }
      }
      if (!Array.isArray(toothMap)) toothMap = [];
      const attachments = (req.files || []).map((file) => ({
        url: file.path,
        cloudinaryId: file.filename,
        format: file.mimetype,
      }));

      const record = await MedicalRecord.create({
        patient: patientId,
        doctor: relatedAppointment ? relatedAppointment.doctor : req.user.id,
        appointment: relatedAppointment ? relatedAppointment._id : undefined,
        title,
        description,
        attachments,
        tags: tags ? tags.split(',').map((tag) => tag.trim()) : [],
        toothMap,
        createdBy: req.user.id,
      });

      res.status(201).json(record);
    } catch (error) {
      console.error('Ошибка сохранения записи:', error);
      res.status(500).json({ message: 'Не удалось сохранить медицинскую запись.' });
    }
  },
);

router.get('/mine', auth(['patient']), async (req, res) => {
  const records = await MedicalRecord.find({ patient: req.user.id })
    .populate('doctor', 'firstName lastName specialties')
    .sort({ createdAt: -1 });
  res.json(records);
});

router.get('/:patientId', auth(['doctor', 'admin', 'superadmin']), async (req, res) => {
  try {
    const { patientId } = req.params;
    const filter = { patient: patientId };
    let adminClinicIds = [];

    if (req.user.role === 'doctor') {
      filter.doctor = req.user.id;
    } else if (req.user.role === 'admin') {
      adminClinicIds = await getAdminClinicIds(req.user.id);
      if (adminClinicIds.length === 0) {
        return res.json([]);
      }

      const appointments = await Appointment.find({
        patient: patientId,
        clinic: { $in: adminClinicIds },
      }).select('_id');

      if (appointments.length === 0) {
        return res.json([]);
      }

      filter.$or = [
        { appointment: { $in: appointments.map((appointment) => appointment._id) } },
        { appointment: null, createdBy: req.user.id },
      ];
    }

    let records = await MedicalRecord.find(filter).sort({ createdAt: -1 });
    if (req.user.role !== 'superadmin') {
      records = await filterAccessibleRecords(records, req.user, adminClinicIds);
    }

    const populatedRecords = await MedicalRecord.populate(records, {
      path: 'doctor',
      select: 'firstName lastName specialties',
    });

    res.json(populatedRecords);
  } catch (error) {
    console.error('Ошибка получения медицинских записей:', error);
    res.status(500).json({ message: 'Не удалось загрузить медицинские записи.' });
  }
});

router.patch('/:id', auth(['doctor', 'admin', 'superadmin']), async (req, res) => {
  try {
    const record = await MedicalRecord.findById(req.params.id);
    if (!record) {
      return res.status(404).json({ message: 'Запись не найдена.' });
    }

    let relatedAppointment = null;
    if (record.appointment) {
      relatedAppointment = await Appointment.findById(record.appointment).select('patient doctor clinic');
      if (!relatedAppointment) {
        return res.status(409).json({ message: 'Связанный приём записи не найден.' });
      }
      if (!idsEqual(relatedAppointment.patient, record.patient)) {
        return res.status(409).json({ message: 'Пациент записи не совпадает с приёмом.' });
      }
      if (!idsEqual(relatedAppointment.doctor, record.doctor)) {
        return res.status(409).json({ message: 'Врач записи не совпадает с приёмом.' });
      }
    }

    if (req.user.role === 'doctor') {
      if (!idsEqual(record.doctor, req.user.id)) {
        return res.status(403).json({ message: 'Можно редактировать только свои записи.' });
      }
    }

    if (req.user.role === 'admin') {
      const adminClinicIds = await getAdminClinicIds(req.user.id);
      if (adminClinicIds.length === 0) {
        return res.status(403).json({ message: 'Нет доступа к клиникам для редактирования записи.' });
      }

      if (relatedAppointment) {
        if (!adminClinicIds.includes(relatedAppointment.clinic.toString())) {
          return res.status(403).json({ message: 'Нет доступа к клинике этой записи.' });
        }
      } else {
        const hasPatientAccess = await Appointment.exists({
          patient: record.patient,
          clinic: { $in: adminClinicIds },
        });
        if (!hasPatientAccess || !idsEqual(record.createdBy, req.user.id)) {
          return res
            .status(403)
            .json({ message: 'Можно редактировать только записи своих клиник.' });
        }
      }
    }

    const updatable = {};
    ['title', 'description'].forEach((field) => {
      if (req.body[field] !== undefined) updatable[field] = req.body[field];
    });
    if (req.body.tags) {
      updatable.tags = Array.isArray(req.body.tags) ? req.body.tags : req.body.tags.split(',');
    }
    if (req.body.toothMap !== undefined) {
      let toothMap = req.body.toothMap;
      if (typeof toothMap === 'string') {
        try {
          toothMap = JSON.parse(toothMap);
        } catch (_) {
          toothMap = [];
        }
      }
      updatable.toothMap = Array.isArray(toothMap) ? toothMap : [];
    }

    const updated = await MedicalRecord.findByIdAndUpdate(record._id, updatable, {
      new: true,
    });
    res.json(updated);
  } catch (error) {
    console.error('Ошибка обновления медицинской записи:', error);
    res.status(500).json({ message: 'Не удалось обновить медицинскую запись.' });
  }
});

module.exports = router;
