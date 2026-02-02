const express = require('express');
const auth = require('../middleware/auth');
const User = require('../models/User');
const Appointment = require('../models/Appointment');
const Clinic = require('../models/Clinic');

const router = express.Router();

router.get('/overview', auth(['admin', 'director']), async (req, res) => {
  try {
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
