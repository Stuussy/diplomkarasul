/* eslint-disable no-console */
// Migration: lowercase all user emails and ensure isActive=true.
// Run once after pulling fix. Safe to re-run.
//
//   node scripts/normalize_users.js

const mongoose = require('mongoose');
const dotenv = require('dotenv');
const User = require('../models/User');

dotenv.config();

const MONGO_URI = process.env.MONGO_URI;
if (!MONGO_URI) {
  console.error('MONGO_URI не задан в .env');
  process.exit(1);
}

async function run() {
  await mongoose.connect(MONGO_URI);
  console.log('Соединение с MongoDB установлено');

  const users = await User.find({});
  let updated = 0;
  let activated = 0;

  for (const user of users) {
    let changed = false;
    const normalized = String(user.email || '').trim().toLowerCase();
    if (user.email !== normalized) {
      user.email = normalized;
      changed = true;
      updated += 1;
    }
    if (user.isActive !== true) {
      user.isActive = true;
      changed = true;
      activated += 1;
    }
    if (changed) {
      try {
        await user.save();
        console.log(`✓ ${normalized}`);
      } catch (err) {
        console.error(`✗ ${user._id}: ${err.message}`);
      }
    }
  }

  console.log(`\nГотово. Email нормализован: ${updated}. Активировано: ${activated}.`);
  console.log(`Всего пользователей: ${users.length}.`);
  await mongoose.disconnect();
  process.exit(0);
}

run().catch((err) => {
  console.error('Ошибка миграции:', err);
  process.exit(1);
});
