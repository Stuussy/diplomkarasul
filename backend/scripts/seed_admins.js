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

const directorData = {
  firstName: 'Главный',
  lastName: 'Врач',
  email: 'director@dental.local',
  password: 'ChangeMe123!',
  role: 'director',
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
  address: 'г. Астана, ул. Абая 15',
  supportEmail: 'support@dental.local',
  supportPhone: '+7 700 000 11 22',
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

async function createClinic() {
  const existing = await Clinic.findOne({ name: clinicData.name });
  if (existing) {
    console.log('Клиника уже существует:', existing.name);
    return existing;
  }
  const clinic = await Clinic.create(clinicData);
  console.log('Создана клиника:', clinic.name);
  return clinic;
}

async function createUserIfMissing(userData, clinicId) {
  const existing = await User.findOne({ email: userData.email });
  if (existing) {
    console.log(`Пользователь ${userData.email} уже существует.`);
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
  });
  console.log(`Создан пользователь ${userData.role}: ${user.email}`);
  return user;
}

async function seed() {
  try {
    await connect();
    const clinic = await createClinic();

    await createUserIfMissing(directorData, clinic._id);
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
