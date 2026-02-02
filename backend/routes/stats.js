const express = require('express');
const auth = require('../middleware/auth');
const User = require('../models/User');
const Appointment = require('../models/Appointment');
const Clinic = require('../models/Clinic');

const router = express.Router();

router.get('/overview', auth(['admin', 'superadmin']), async (req, res) => {
  try {
    if (req.user.role === 'admin') {
      const clinicIds = req.user.clinics || [];
      const [doctors, patients, appointments, clinics] = await Promise.all([
        User.countDocuments({ role: 'doctor', clinics: { $in: clinicIds } }),
        Appointment.distinct('patient', { clinic: { $in: clinicIds } }),
        Appointment.countDocuments({ clinic: { $in: clinicIds } }),
        Clinic.find({ _id: { $in: clinicIds } }),
      ]);

      return res.json({
        doctors,
        patients: patients.length,
        appointments,
        clinics,
      });
    }

    const [doctors, patients, appointments, clinics] = await Promise.all([
      User.countDocuments({ role: 'doctor' }),
      User.countDocuments({ role: 'patient' }),
      Appointment.countDocuments({}),
      Clinic.find(),
    ]);

    res.json({
      doctors,
      patients,
      appointments,
      clinics,
    });
  } catch (error) {
    console.error('Ошибка получения статистики:', error);
    res.status(500).json({ message: 'Не удалось загрузить статистику.' });
  }
});

module.exports = router;
