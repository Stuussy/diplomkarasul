const express = require('express');
const { body, validationResult } = require('express-validator');
const crypto = require('crypto');
const Clinic = require('../models/Clinic');
const User = require('../models/User');
const auth = require('../middleware/auth');

const router = express.Router();

const clinicValidators = [
  body('name').notEmpty(),
];

function isClinicComplete(clinic) {
  const hasName = Boolean(clinic.name && clinic.name.trim());
  const hasDescription = Boolean(clinic.description && clinic.description.trim());
  const hasCity = Boolean(clinic.city && clinic.city.trim());
  const hasAddress = Boolean(clinic.address && clinic.address.trim());
  const hasContacts =
    Boolean(clinic.contacts && clinic.contacts.phone && clinic.contacts.phone.trim()) &&
    Boolean(clinic.contacts && clinic.contacts.email && clinic.contacts.email.trim());
  const hasWorkingHours =
    Array.isArray(clinic.workingHours) &&
    clinic.workingHours.length > 0 &&
    clinic.workingHours.some((slot) => slot && slot.day !== undefined && !slot.isClosed);
  return hasName && hasDescription && hasCity && hasAddress && hasContacts && hasWorkingHours;
}

async function getAdminClinicIds(userId) {
  const admin = await User.findById(userId).select('clinics');
  const clinicIds = new Set();
  (admin?.clinics || []).forEach((id) => clinicIds.add(id.toString()));
  const ownedClinics = await Clinic.find({ admin: userId }).select('_id');
  ownedClinics.forEach((clinic) => clinicIds.add(clinic._id.toString()));
  return Array.from(clinicIds);
}

async function adminHasClinicAccess(userId, clinic) {
  if (!clinic) return false;
  if (clinic.admin?.toString() === userId) return true;
  const clinicIds = await getAdminClinicIds(userId);
  return clinicIds.includes(clinic._id.toString());
}

router.post('/', auth(['admin', 'superadmin']), clinicValidators, async (req, res) => {
  const errors = validationResult(req);
  if (!errors.isEmpty()) {
    return res.status(400).json({ errors: errors.array() });
  }

  try {
    const adminId = req.user.role === 'superadmin' ? req.body.adminId || req.user.id : req.user.id;
    const clinic = await Clinic.create({
      ...req.body,
      status: 'draft',
      admin: adminId,
    });
    await Clinic.model('User').findByIdAndUpdate(adminId, { $addToSet: { clinics: clinic._id } });
    res.status(201).json(clinic);
  } catch (error) {
    console.error('Не удалось создать клинику:', error);
    res.status(500).json({ message: 'Ошибка создания клиники.' });
  }
});

router.get('/', auth(), async (req, res) => {
  const { lat, lon, radius = 5000, status } = req.query;
  if (lat && lon) {
    const clinics = await Clinic.find({
      status: 'active',
      location: {
        $nearSphere: {
          $geometry: { type: 'Point', coordinates: [parseFloat(lon), parseFloat(lat)] },
          $maxDistance: parseInt(radius, 10),
        },
      },
    });
    return res.json(clinics);
  }

  let filter = {};
  if (req.user.role === 'patient' || req.user.role === 'doctor') {
    filter = { status: 'active' };
  } else if (req.user.role === 'admin') {
    const clinicIds = await getAdminClinicIds(req.user.id);
    if (clinicIds.length === 0) {
      return res.json([]);
    }
    filter = { _id: { $in: clinicIds } };
  } else if (req.user.role === 'support_manager') {
    return res.status(403).json({ message: 'Доступ к клиникам запрещен.' });
  } else if (req.user.role === 'superadmin' && status) {
    filter = { status };
  }

  const clinics = await Clinic.find(filter);
  res.json(clinics);
});

router.patch('/:id', auth(['admin', 'superadmin']), async (req, res) => {
  const clinic = await Clinic.findById(req.params.id);
  if (!clinic) {
    return res.status(404).json({ message: 'Клиника не найдена.' });
  }

  if (req.user.role === 'admin') {
    const hasAccess = await adminHasClinicAccess(req.user.id, clinic);
    if (!hasAccess) {
      return res.status(403).json({ message: 'Нет доступа к этой клинике.' });
    }
  }
  if (clinic.status === 'blocked' && req.user.role !== 'superadmin') {
    return res.status(403).json({ message: 'Клиника заблокирована.' });
  }

  const nextStatus = req.body.status;
  if (nextStatus === 'blocked' && req.user.role !== 'superadmin') {
    return res.status(403).json({ message: 'Только superadmin может блокировать клинику.' });
  }

  const updated = await Clinic.findByIdAndUpdate(clinic._id, req.body, { new: true });
  if (!updated) {
    return res.status(404).json({ message: 'Клиника не найдена.' });
  }

  if (nextStatus === 'active' && !isClinicComplete(updated)) {
    await Clinic.findByIdAndUpdate(updated._id, { status: 'draft' });
    return res
      .status(400)
      .json({ message: 'Заполните данные клиники перед активацией.' });
  }

  res.json(updated);
});

router.post('/:id/qr', auth(['doctor', 'admin', 'superadmin']), async (req, res) => {
  const clinic = await Clinic.findById(req.params.id);
  if (!clinic) {
    return res.status(404).json({ message: 'Клиника не найдена.' });
  }
  if (req.user.role === 'admin') {
    const hasAccess = await adminHasClinicAccess(req.user.id, clinic);
    if (!hasAccess) {
      return res.status(403).json({ message: 'Нет доступа к клинике.' });
    }
  }

  const qrSecret = process.env.QR_SECRET;
  if (!qrSecret) {
    return res.status(500).json({ message: 'QR-секрет не настроен.' });
  }
  const issuedAt = Date.now();
  const basePayload = `clinic:${clinic._id}:${issuedAt}`;
  const signature = crypto.createHmac('sha256', qrSecret).update(basePayload).digest('hex');
  const payload = `${basePayload}:${signature}`;
  clinic.qr = {
    payload,
    updatedBy: req.user.id,
    updatedAt: new Date(),
  };
  await clinic.save();
  res.json(clinic.qr);
});

router.post('/:id/services', auth(['admin', 'superadmin']), async (req, res) => {
  const { name, price, durationMinutes, description, isActive } = req.body;
  if (!name || !name.trim()) {
    return res.status(400).json({ message: 'Название услуги обязательно.' });
  }
  const clinic = await Clinic.findById(req.params.id);
  if (!clinic) {
    return res.status(404).json({ message: 'Клиника не найдена.' });
  }
  if (req.user.role === 'admin') {
    const hasAccess = await adminHasClinicAccess(req.user.id, clinic);
    if (!hasAccess) {
      return res.status(403).json({ message: 'Нет доступа к клинике.' });
    }
  }
  clinic.services.push({
    name,
    price,
    durationMinutes,
    description,
    isActive: isActive ?? true,
  });
  await clinic.save();
  res.status(201).json(clinic);
});

router.patch('/:id/services/:serviceId', auth(['admin', 'superadmin']), async (req, res) => {
  const clinic = await Clinic.findById(req.params.id);
  if (!clinic) {
    return res.status(404).json({ message: 'Клиника не найдена.' });
  }
  if (req.user.role === 'admin') {
    const hasAccess = await adminHasClinicAccess(req.user.id, clinic);
    if (!hasAccess) {
      return res.status(403).json({ message: 'Нет доступа к клинике.' });
    }
  }
  const service = clinic.services.id(req.params.serviceId);
  if (!service) {
    return res.status(404).json({ message: 'Услуга не найдена.' });
  }
  Object.assign(service, req.body);
  await clinic.save();
  res.json(clinic);
});

router.delete('/:id/services/:serviceId', auth(['admin', 'superadmin']), async (req, res) => {
  const clinic = await Clinic.findById(req.params.id);
  if (!clinic) {
    return res.status(404).json({ message: 'Клиника не найдена.' });
  }
  if (req.user.role === 'admin') {
    const hasAccess = await adminHasClinicAccess(req.user.id, clinic);
    if (!hasAccess) {
      return res.status(403).json({ message: 'Нет доступа к клинике.' });
    }
  }
  const service = clinic.services.id(req.params.serviceId);
  if (!service) {
    return res.status(404).json({ message: 'Услуга не найдена.' });
  }
  service.deleteOne();
  await clinic.save();
  res.json(clinic);
});

router.post('/:id/doctors', auth(['admin', 'superadmin']), async (req, res) => {
  const { doctorId } = req.body;
  if (!doctorId) {
    return res.status(400).json({ message: 'doctorId обязателен.' });
  }
  const clinic = await Clinic.findById(req.params.id);
  if (!clinic) {
    return res.status(404).json({ message: 'Клиника не найдена.' });
  }
  if (req.user.role === 'admin') {
    const hasAccess = await adminHasClinicAccess(req.user.id, clinic);
    if (!hasAccess) {
      return res.status(403).json({ message: 'Нет доступа к клинике.' });
    }
  }
  if (!clinic.doctors.map((id) => id.toString()).includes(doctorId)) {
    clinic.doctors.push(doctorId);
  }
  await clinic.save();
  await Clinic.model('User').findByIdAndUpdate(doctorId, { $addToSet: { clinics: clinic._id } });
  res.json(clinic);
});

router.delete('/:id/doctors/:doctorId', auth(['admin', 'superadmin']), async (req, res) => {
  const clinic = await Clinic.findById(req.params.id);
  if (!clinic) {
    return res.status(404).json({ message: 'Клиника не найдена.' });
  }
  if (req.user.role === 'admin') {
    const hasAccess = await adminHasClinicAccess(req.user.id, clinic);
    if (!hasAccess) {
      return res.status(403).json({ message: 'Нет доступа к клинике.' });
    }
  }
  clinic.doctors = clinic.doctors.filter(
    (doctor) => doctor.toString() !== req.params.doctorId,
  );
  await clinic.save();
  await Clinic.model('User').findByIdAndUpdate(req.params.doctorId, { $pull: { clinics: clinic._id } });
  res.json(clinic);
});

module.exports = router;
