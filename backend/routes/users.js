const express = require('express');
const { body, validationResult } = require('express-validator');
const User = require('../models/User');
const auth = require('../middleware/auth');

const router = express.Router();

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
      const user = await User.create({
        firstName,
        lastName,
        email,
        phone,
        role,
        clinics: req.user.role === 'admin' ? req.user.clinics || [] : clinics,
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
    filter.role = 'doctor';
    filter.clinics = { $in: req.user.clinics || [] };
  }
  const users = await User.find(filter).select('-passwordHash');
  res.json(users);
});

router.get('/doctors', auth(), async (req, res) => {
  try {
    const filter = { role: 'doctor', isActive: true };
    if (req.user.role === 'admin') {
      filter.clinics = { $in: req.user.clinics || [] };
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
  },
);

module.exports = router;
