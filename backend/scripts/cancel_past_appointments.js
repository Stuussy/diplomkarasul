/* eslint-disable no-console */
const mongoose = require('mongoose');
const dotenv = require('dotenv');
const Appointment = require('../models/Appointment');
const User = require('../models/User');

dotenv.config();

const { MONGO_URI } = process.env;
if (!MONGO_URI) {
  console.error('MONGO_URI не задан в .env');
  process.exit(1);
}

async function run() {
  await mongoose.connect(MONGO_URI);
  console.log('Подключились к MongoDB');

  const cutoff = new Date('2026-05-29T00:00:00.000Z');

  // Find user by email
  const user = await User.findOne({ email: 'sksktgv@gmail.com' }).select('_id');
  if (!user) {
    console.log('Пользователь sksktgv@gmail.com не найден');
  } else {
    // Cancel all active appointments for this user
    const userResult = await Appointment.updateMany(
      {
        patient: user._id,
        status: { $in: ['scheduled', 'confirmed'] },
      },
      { $set: { status: 'cancelled' } },
    );
    console.log(`Отменено активных записей для sksktgv@gmail.com: ${userResult.modifiedCount}`);
  }

  // Cancel all appointments before May 29, 2026 with scheduled/confirmed status
  const pastResult = await Appointment.updateMany(
    {
      startTime: { $lt: cutoff },
      status: { $in: ['scheduled', 'confirmed'] },
    },
    { $set: { status: 'cancelled' } },
  );
  console.log(`Отменено просроченных записей до 29 мая 2026: ${pastResult.modifiedCount}`);

  await mongoose.disconnect();
  console.log('Готово.');
}

run().catch((err) => {
  console.error(err);
  process.exit(1);
});
