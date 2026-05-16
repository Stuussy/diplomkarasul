/* eslint-disable no-console */
// Seed schedule slots for the next 14 days for all active doctors in the first clinic.
// Run once after seeding admins:
//   node scripts/seed_slots.js

const mongoose = require('mongoose');
const dotenv = require('dotenv');
const User = require('../models/User');
const Clinic = require('../models/Clinic');
const ScheduleSlot = require('../models/ScheduleSlot');

dotenv.config();

const MONGO_URI = process.env.MONGO_URI;
if (!MONGO_URI) {
  console.error('MONGO_URI не задан в .env');
  process.exit(1);
}

// Working day hours: 09:00, 10:00, 11:00, 14:00, 15:00, 16:00, 17:00
const SLOT_HOURS = [9, 10, 11, 14, 15, 16, 17];
const SLOT_DURATION_MINUTES = 45;
const DAYS_AHEAD = 14;

function addMinutes(date, minutes) {
  return new Date(date.getTime() + minutes * 60 * 1000);
}

async function run() {
  await mongoose.connect(MONGO_URI);
  console.log('Соединение с MongoDB установлено');

  const clinic = await Clinic.findOne({ status: 'active' });
  if (!clinic) {
    console.error('Нет активной клиники. Запустите npm run seed и убедитесь что клиника active.');
    process.exit(1);
  }
  console.log(`Клиника: ${clinic.name}`);

  const doctors = await User.find({ role: 'doctor', isActive: true });
  if (doctors.length === 0) {
    console.log('Нет активных врачей. Запустите npm run seed сначала.');
    process.exit(0);
  }
  console.log(`Врачей: ${doctors.length}`);

  const now = new Date();
  const today = new Date(now.getFullYear(), now.getMonth(), now.getDate());
  let created = 0;
  let skipped = 0;

  for (const doctor of doctors) {
    console.log(`\nСоздаю слоты для: ${doctor.firstName} ${doctor.lastName}`);
    for (let day = 1; day <= DAYS_AHEAD; day++) {
      const date = new Date(today);
      date.setDate(today.getDate() + day);
      const dayOfWeek = date.getDay(); // 0=Sun, 6=Sat
      if (dayOfWeek === 0 || dayOfWeek === 6) continue; // Skip weekends

      for (const hour of SLOT_HOURS) {
        const startTime = new Date(date);
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
            skipped++; // Duplicate, already exists
          } else {
            console.error(`Ошибка создания слота: ${err.message}`);
          }
        }
      }
    }
    console.log(`  ✓ ${doctor.firstName} ${doctor.lastName}`);
  }

  console.log(`\nГотово. Создано: ${created} слотов. Пропущено (уже существуют): ${skipped}.`);
  await mongoose.disconnect();
  process.exit(0);
}

run().catch((err) => {
  console.error('Ошибка:', err);
  process.exit(1);
});
