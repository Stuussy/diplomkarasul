/* eslint-disable no-console */
const mongoose = require('mongoose');
const dotenv = require('dotenv');
const Clinic = require('../models/Clinic');
const User = require('../models/User');

dotenv.config();

const MONGO_URI = process.env.MONGO_URI;

if (!MONGO_URI) {
  console.error('MONGO_URI не задан в .env');
  process.exit(1);
}

const DEFAULT_WORKING_HOURS = [
  { day: 1, open: '09:00', close: '18:00', isClosed: false },
  { day: 2, open: '09:00', close: '18:00', isClosed: false },
  { day: 3, open: '09:00', close: '18:00', isClosed: false },
  { day: 4, open: '09:00', close: '18:00', isClosed: false },
  { day: 5, open: '09:00', close: '18:00', isClosed: false },
  { day: 6, open: '10:00', close: '16:00', isClosed: true },
  { day: 0, open: '10:00', close: '16:00', isClosed: true },
];

function normalizeWorkingHours(value) {
  if (!Array.isArray(value) || value.length === 0) return DEFAULT_WORKING_HOURS;
  const byDay = new Map();
  value.forEach((slot) => {
    if (slot && slot.day !== undefined) byDay.set(slot.day, slot);
  });
  return DEFAULT_WORKING_HOURS.map((slot) => ({
    day: slot.day,
    open: byDay.get(slot.day)?.open || slot.open,
    close: byDay.get(slot.day)?.close || slot.close,
    isClosed: byDay.get(slot.day)?.isClosed ?? slot.isClosed,
  }));
}

function computeStatus(clinic) {
  if (clinic.status) return clinic.status;
  const hasName = Boolean(clinic.name);
  const hasDescription = Boolean(clinic.description);
  const hasCity = Boolean(clinic.city);
  const hasAddress = Boolean(clinic.address);
  const hasContacts = Boolean(clinic.contacts?.phone) && Boolean(clinic.contacts?.email);
  const hasWorkingHours = Array.isArray(clinic.workingHours) && clinic.workingHours.length > 0;
  return hasName && hasDescription && hasCity && hasAddress && hasContacts && hasWorkingHours
    ? 'active'
    : 'draft';
}

async function migrateClinics() {
  const clinics = await Clinic.find();
  console.log(`Найдено клиник: ${clinics.length}`);

  for (const clinic of clinics) {
    const updates = {};

    if (!clinic.city) {
      updates.city = clinic.address ? clinic.address.split(',')[0]?.trim() : 'Не указан';
    }

    if (!clinic.contacts) {
      updates.contacts = {
        phone: clinic.supportPhone || '',
        email: clinic.supportEmail || '',
      };
    }

    if (!clinic.workingHours || clinic.workingHours.length === 0) {
      updates.workingHours = normalizeWorkingHours(clinic.workingHours);
    } else {
      updates.workingHours = normalizeWorkingHours(clinic.workingHours);
    }

    if (!clinic.status) {
      updates.status = computeStatus({ ...clinic.toObject(), ...updates });
    }

    if (!clinic.admin) {
      const adminUser = await User.findOne({ role: 'admin', clinics: clinic._id });
      if (adminUser) {
        updates.admin = adminUser._id;
      } else {
        const superAdmin = await User.findOne({ role: 'superadmin' });
        if (superAdmin) updates.admin = superAdmin._id;
      }
    }

    if (!clinic.services) updates.services = [];
    if (!clinic.doctors) updates.doctors = [];

    if (Object.keys(updates).length > 0) {
      await Clinic.findByIdAndUpdate(clinic._id, updates, { new: true });
      console.log(`Обновлена клиника: ${clinic.name}`);
    }
  }
}

async function migrateUsers() {
  const users = await User.find();
  console.log(`Найдено пользователей: ${users.length}`);

  for (const user of users) {
    const updates = {};

    if (user.role === 'director') {
      updates.role = 'superadmin';
    }

    if (!Array.isArray(user.clinics)) {
      updates.clinics = [];
    }

    if (Object.keys(updates).length > 0) {
      await User.findByIdAndUpdate(user._id, updates, { new: true });
      console.log(`Обновлен пользователь: ${user.email}`);
    }
  }
}

async function ensureAdminClinicLinks() {
  const clinics = await Clinic.find({ admin: { $exists: true, $ne: null } });
  for (const clinic of clinics) {
    await User.findByIdAndUpdate(clinic.admin, { $addToSet: { clinics: clinic._id } });
  }
}

async function run() {
  try {
    await mongoose.connect(MONGO_URI);
    console.log('Подключено к MongoDB');

    await migrateUsers();
    await migrateClinics();
    await ensureAdminClinicLinks();

    console.log('Миграция завершена');
  } catch (error) {
    console.error('Ошибка миграции:', error);
  } finally {
    await mongoose.disconnect();
    process.exit();
  }
}

run();
