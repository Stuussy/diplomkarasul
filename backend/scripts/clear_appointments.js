/* eslint-disable no-console */
const mongoose = require('mongoose');
const dotenv = require('dotenv');
const Appointment = require('../models/Appointment');
const ScheduleSlot = require('../models/ScheduleSlot');

dotenv.config();

const { MONGO_URI } = process.env;

if (!MONGO_URI) {
  console.error('MONGO_URI не задан в .env');
  process.exit(1);
}

async function clearAppointmentsAndSlots() {
  try {
    await mongoose.connect(MONGO_URI);
    console.log('Подключились к MongoDB');

    const [appointmentsResult, slotsResult] = await Promise.all([
      Appointment.deleteMany({}),
      ScheduleSlot.deleteMany({}),
    ]);

    console.log(`Удалено записей: ${appointmentsResult.deletedCount}`);
    console.log(`Удалено слотов: ${slotsResult.deletedCount}`);
    console.log('Готово.');
  } catch (error) {
    console.error('Ошибка очистки:', error);
  } finally {
    await mongoose.disconnect();
    process.exit();
  }
}

clearAppointmentsAndSlots();
