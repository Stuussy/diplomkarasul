const express = require('express');
const { body, validationResult } = require('express-validator');
const Clinic = require('../models/Clinic');
const User = require('../models/User');
const auth = require('../middleware/auth');

const router = express.Router();

async function getAdminClinicIds(userId) {
  const admin = await User.findById(userId).select('clinics');
  const clinicIds = new Set();
  (admin?.clinics || []).forEach((id) => clinicIds.add(id.toString()));
  const ownedClinics = await Clinic.find({ admin: userId }).select('_id');
  ownedClinics.forEach((clinic) => clinicIds.add(clinic._id.toString()));
  return Array.from(clinicIds);
}

router.post(
  '/',
  auth(['admin', 'superadmin']),
  [
    body('firstName').notEmpty(),
    body('lastName').notEmpty(),
    body('email').isEmail(),
    body('role').isIn(['patient', 'doctor', 'admin', 'support_manager']),
    body('password').isLength({ min: 6 }),
  ],
  async (req, res) => {
    const errors = validationResult(req);
    if (!errors.isEmpty()) {
      return res.status(400).json({ errors: errors.array() });
    }

    try {
      const { firstName, lastName, email, role, password, phone, clinics, specialties } = req.body;
      if (req.user.role === 'admin' && role !== 'doctor') {
        return res.status(403).json({ message: 'Админ может создавать только врачей.' });
      }

      const existing = await User.findOne({ email });
      if (existing) {
        return res.status(400).json({ message: 'Email уже используется.' });
      }

      const passwordHash = await User.hashPassword(password);
      let adminClinics = [];
      if (req.user.role === 'admin') {
        const admin = await User.findById(req.user.id).select('clinics');
        adminClinics = admin?.clinics || [];
      }

      const user = await User.create({
        firstName,
        lastName,
        email,
        phone,
        role,
        clinics: req.user.role === 'admin' ? adminClinics : clinics,
        specialties,
        passwordHash,
        createdBy: req.user.id,
      });

      res.status(201).json(user);
    } catch (error) {
      console.error('Ошибка создания пользователя:', error);
      res.status(500).json({ message: 'Не удалось создать пользователя.' });
    }
  },
);

router.get('/', auth(['superadmin', 'admin']), async (req, res) => {
  const { role } = req.query;
  const filter = {};
  if (role) filter.role = role;
  if (req.user.role === 'admin') {
    const admin = await User.findById(req.user.id).select('clinics');
    const clinicIds = admin?.clinics || [];
    filter.role = 'doctor';
    filter.clinics = { $in: clinicIds };
  }
  const users = await User.find(filter).select('-passwordHash');
  res.json(users);
});

router.get('/doctors', auth(), async (req, res) => {
  try {
    const filter = { role: 'doctor', isActive: true };
    if (req.user.role === 'admin') {
      const admin = await User.findById(req.user.id).select('clinics');
      filter.clinics = { $in: admin?.clinics || [] };
    }
    const doctors = await User.find(filter)
      .select('firstName lastName email phone specialties clinics')
      .populate('clinics', 'name address contacts');
    res.json(doctors);
  } catch (error) {
    console.error('Ошибка получения списка врачей:', error);
    res.status(500).json({ message: 'Не удалось загрузить врачей.' });
  }
});

router.patch(
  '/:id/role',
  auth(['superadmin']),
  [body('role').isIn(['patient', 'doctor', 'admin', 'support_manager', 'superadmin'])],
  async (req, res) => {
    const errors = validationResult(req);
    if (!errors.isEmpty()) {
      return res.status(400).json({ errors: errors.array() });
    }

    const { role } = req.body;
    const user = await User.findByIdAndUpdate(req.params.id, { role }, { new: true });
    if (!user) {
      return res.status(404).json({ message: 'Пользователь не найден.' });
    }
    res.json(user);
  },
);

router.patch('/:id/status', auth(['superadmin']), async (req, res) => {
  const { isActive } = req.body;
  const user = await User.findByIdAndUpdate(req.params.id, { isActive }, { new: true });
  if (!user) {
    return res.status(404).json({ message: 'Пользователь не найден.' });
  }
  res.json(user);
});

router.patch('/:id/reset-password', auth(['superadmin']), async (req, res) => {
  const { newPassword } = req.body;
  if (!newPassword || newPassword.length < 6) {
    return res.status(400).json({ message: 'Пароль должен быть минимум 6 символов.' });
  }
  const user = await User.findById(req.params.id);
  if (!user) {
    return res.status(404).json({ message: 'Пользователь не найден.' });
  }
  user.passwordHash = await User.hashPassword(newPassword);
  await user.save();
  res.json({ success: true });
});

router.patch(
  '/:id',
  auth(['admin', 'superadmin']),
  [
    body('firstName').optional().isLength({ min: 1 }),
    body('lastName').optional().isLength({ min: 1 }),
    body('phone').optional().isLength({ min: 5 }),
    body('experienceYears').optional().isInt({ min: 0, max: 60 }),
    body('services').optional().isArray(),
    body('specialties').optional().isArray(),
    body('bio').optional().isLength({ max: 2000 }),
  ],
  async (req, res) => {
    const errors = validationResult(req);
    if (!errors.isEmpty()) {
      return res.status(400).json({ errors: errors.array() });
    }

    try {
      const targetUser = await User.findById(req.params.id).select('role clinics');
      if (!targetUser) {
        return res.status(404).json({ message: 'Пользователь не найден.' });
      }

      if (req.user.role === 'admin') {
        const adminClinicIds = await getAdminClinicIds(req.user.id);
        const hasClinicAccess = (targetUser.clinics || []).some((clinicId) =>
          adminClinicIds.includes(clinicId.toString()),
        );
        if (targetUser.role !== 'doctor' || !hasClinicAccess) {
          return res
            .status(403)
            .json({ message: 'Админ может редактировать только врачей своих клиник.' });
        }
      }

      const updates = {};
      ['firstName', 'lastName', 'phone', 'bio'].forEach((field) => {
        if (req.body[field] !== undefined) updates[field] = req.body[field];
      });
      if (req.body.experienceYears !== undefined) {
        updates.experienceYears = req.body.experienceYears;
      }
      if (Array.isArray(req.body.services)) {
        updates.services = req.body.services;
      }
      if (Array.isArray(req.body.specialties)) {
        updates.specialties = req.body.specialties;
      }

      const user = await User.findByIdAndUpdate(req.params.id, updates, { new: true }).select(
        '-passwordHash',
      );
      if (!user) {
        return res.status(404).json({ message: 'Пользователь не найден.' });
      }
      res.json(user);
    } catch (error) {
      console.error('Ошибка обновления пользователя:', error);
      res.status(500).json({ message: 'Не удалось обновить пользователя.' });
    }
  },
);

module.exports = router;
