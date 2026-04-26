const express = require('express');
const Fine = require('../models/Fine');
const Appointment = require('../models/Appointment');
const Clinic = require('../models/Clinic');
const User = require('../models/User');
const auth = require('../middleware/auth');

const router = express.Router();

async function getAdminClinicIds(userId) {
  const admin = await User.findById(userId).select('clinics');
  const clinicIds = new Set();
  (admin?.clinics || []).forEach((id) => clinicIds.add(id.toString()));
  const ownedClinics = await Clinic.find({ admin: userId }).select('_id');
  ownedClinics.forEach((clinic) => clinicIds.add(clinic._id.toString()));
  return Array.from(clinicIds);
}

router.get('/', auth(['patient', 'admin', 'superadmin']), async (req, res) => {
  try {
    const filter = {};
    if (req.user.role === 'patient') {
      filter.patient = req.user.id;
    } else if (req.query.patientId) {
      filter.patient = req.query.patientId;
    }

    if (req.user.role === 'admin') {
      const clinicIds = await getAdminClinicIds(req.user.id);
      if (clinicIds.length === 0) {
        return res.json([]);
      }

      const appointmentFilter = { clinic: { $in: clinicIds } };
      if (req.query.patientId) {
        appointmentFilter.patient = req.query.patientId;
      }

      const appointments = await Appointment.find(appointmentFilter).select('_id patient');
      if (appointments.length === 0) {
        return res.json([]);
      }

      filter.appointment = { $in: appointments.map((appointment) => appointment._id) };
      if (!req.query.patientId) {
        filter.patient = {
          $in: [...new Set(appointments.map((appointment) => appointment.patient.toString()))],
        };
      }
    }

    const fines = await Fine.find(filter).populate('appointment');
    res.json(fines);
  } catch (error) {
    console.error('Ошибка получения штрафов:', error);
    res.status(500).json({ message: 'Не удалось загрузить штрафы.' });
  }
});

module.exports = router;
