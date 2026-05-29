const express = require('express');
const User = require('../models/User');
const Clinic = require('../models/Clinic');
const ScheduleSlot = require('../models/ScheduleSlot');
const auth = require('../middleware/auth');

const router = express.Router();

const SLOT_HOURS = [9, 10, 11, 14, 15, 16, 17];
const SLOT_DURATION_MINUTES = 45;

function addMinutes(date, minutes) {
  return new Date(date.getTime() + minutes * 60 * 1000);
}

// Superadmin: seed slots for all doctors up to a given date
// POST /api/admin/seed-slots  { untilDate: "2026-06-10" }
router.post('/seed-slots', auth(['superadmin', 'admin']), async (req, res) => {
  try {
    const untilDate = req.body.untilDate
      ? new Date(req.body.untilDate)
      : (() => { const d = new Date(); d.setDate(d.getDate() + 14); return d; })();

    const clinic = await Clinic.findOne({ status: 'active' });
    if (!clinic) {
      return res.status(400).json({ message: 'Нет активной клиники.' });
    }

    const doctors = await User.find({ role: 'doctor', isActive: true });
    if (doctors.length === 0) {
      return res.status(400).json({ message: 'Нет активных врачей.' });
    }

    const now = new Date();
    const today = new Date(now.getFullYear(), now.getMonth(), now.getDate());
    let created = 0;
    let skipped = 0;

    for (const doctor of doctors) {
      const current = new Date(today);
      current.setDate(current.getDate() + 1);
      while (current <= untilDate) {
        const dayOfWeek = current.getDay();
        if (dayOfWeek !== 0 && dayOfWeek !== 6) {
          for (const hour of SLOT_HOURS) {
            const startTime = new Date(current);
            startTime.setHours(hour, 0, 0, 0);
            const endTime = addMinutes(startTime, SLOT_DURATION_MINUTES);
            try {
              await ScheduleSlot.create({
                doctor: doctor._id,
                clinic: clinic._id,
                startTime,
                endTime,
                status: 'available',
                createdBy: doctor._id,
              });
              created++;
            } catch (err) {
              if (err.code === 11000) {
                skipped++;
              } else {
                console.error('Ошибка создания слота:', err.message);
              }
            }
          }
        }
        current.setDate(current.getDate() + 1);
      }
    }

    res.json({
      message: `Готово. Создано: ${created}, пропущено (уже были): ${skipped}`,
      created,
      skipped,
      doctors: doctors.length,
      clinic: clinic.name,
      until: untilDate.toISOString().split('T')[0],
    });
  } catch (err) {
    console.error('Ошибка seed-slots:', err);
    res.status(500).json({ message: err.message });
  }
});

module.exports = router;
