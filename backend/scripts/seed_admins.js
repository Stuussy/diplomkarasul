/* eslint-disable no-console */
const mongoose = require('mongoose');
const dotenv = require('dotenv');
const User = require('../models/User');
const Clinic = require('../models/Clinic');

dotenv.config();

const MONGO_URI = process.env.MONGO_URI;

if (!MONGO_URI) {
  console.error('MONGO_URI не задан в .env');
  process.exit(1);
}

const superAdminData = {
  firstName: 'Главный',
  lastName: 'Администратор',
  email: 'superadmin@dental.local',
  password: 'ChangeMe123!',
  role: 'superadmin',
};

const adminData = {
  firstName: 'Админ',
  lastName: 'Клиники',
  email: 'admin@dental.local',
  password: 'ChangeMe123!',
  role: 'admin',
};

const clinicData = {
  name: 'Dental AI Clinic',
  description: 'Центральная клиника Dental AI',
  city: 'Астана',
  address: 'г. Астана, ул. Абая 15',
  contacts: { email: 'support@dental.local', phone: '+7 700 000 11 22' },
  workingHours: [
    { day: 1, open: '09:00', close: '18:00' },
    { day: 2, open: '09:00', close: '18:00' },
    { day: 3, open: '09:00', close: '18:00' },
    { day: 4, open: '09:00', close: '18:00' },
    { day: 5, open: '09:00', close: '18:00' },
  ],
  status: 'active',
  taxiDeepLink: 'yandexnavi://build_route_on_map?lat=51.1694&lon=71.4491',
  location: {
    type: 'Point',
    coordinates: [71.4491, 51.1694],
  },
};

const doctorSeeds = [
  {
    firstName: 'Ануар',
    lastName: 'Султанов',
    email: 'doctor.anuar@dental.local',
    password: 'ChangeMe123!',
    role: 'doctor',
    specialties: ['Терапевт', 'Гигиенист'],
    phone: '+7 701 111 22 33',
  },
  {
    firstName: 'Жанна',
    lastName: 'Омарова',
    email: 'doctor.janna@dental.local',
    password: 'ChangeMe123!',
    role: 'doctor',
    specialties: ['Ортодонт'],
    phone: '+7 777 444 55 66',
  },
];

async function connect() {
  await mongoose.connect(MONGO_URI);
  console.log('Соединение с MongoDB установлено');
}

async function createUserIfMissing(userData, clinicId) {
  const existing = await User.findOne({ email: userData.email });
  if (existing) {
    let changed = false;
    if (!existing.isActive) {
      existing.isActive = true;
      changed = true;
    }
    if (clinicId && !existing.clinics.some((c) => c.toString() === clinicId.toString())) {
      existing.clinics.push(clinicId);
      changed = true;
    }
    if (changed) {
      await existing.save();
      console.log(`Обновлён пользователь ${userData.email} (clinics/isActive).`);
    } else {
      console.log(`Пользователь ${userData.email} уже существует.`);
    }
    return existing;
  }

  const passwordHash = await User.hashPassword(userData.password);
  const user = await User.create({
    firstName: userData.firstName,
    lastName: userData.lastName,
    email: userData.email,
    role: userData.role,
    passwordHash,
    clinics: clinicId ? [clinicId] : [],
    phone: userData.phone,
    specialties: userData.specialties ?? [],
    isActive: true,
  });
  console.log(`Создан пользователь ${userData.role}: ${user.email}`);
  return user;
}

async function createClinic(adminId) {
  if (!adminId) {
    throw new Error('createClinic: adminId is required but was empty');
  }
  const existing = await Clinic.findOne({ name: clinicData.name });
  if (existing) {
    if (!existing.admin) {
      existing.admin = adminId;
      await existing.save();
      console.log('Клиника обновлена (назначен admin):', existing.name);
    } else {
      console.log('Клиника уже существует:', existing.name);
    }
    return existing;
  }
  const clinic = await Clinic.create({ ...clinicData, admin: adminId });
  console.log('Создана клиника:', clinic.name);
  return clinic;
}

async function seed() {
  try {
    await connect();

    const superAdmin = await createUserIfMissing(superAdminData, null);
    if (!superAdmin || !superAdmin._id) {
      throw new Error('Не удалось создать или найти суперадмина');
    }
    const clinic = await createClinic(superAdmin._id);

    await createUserIfMissing(adminData, clinic._id);
    for (const doctor of doctorSeeds) {
      await createUserIfMissing(doctor, clinic._id);
    }

    console.log('Базовые пользователи и клиника готовы.');
  } catch (error) {
    console.error('Ошибка сидирования:', error);
  } finally {
    await mongoose.disconnect();
    process.exit();
  }
}

seed();
