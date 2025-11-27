const express = require('express');
const { body, validationResult } = require('express-validator');
const User = require('../models/User');
const auth = require('../middleware/auth');

const router = express.Router();

router.post(
  '/',
  auth(['admin', 'director']),
  [
    body('firstName').notEmpty(),
    body('lastName').notEmpty(),
    body('email').isEmail(),
    body('role').isIn(['patient', 'doctor', 'admin']),
    body('password').isLength({ min: 6 }),
  ],
  async (req, res) => {
    const errors = validationResult(req);
    if (!errors.isEmpty()) {
      return res.status(400).json({ errors: errors.array() });
    }

    try {
      const { firstName, lastName, email, role, password, phone, clinics, specialties } = req.body;
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
        clinics,
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

router.get('/', auth(['admin', 'director']), async (req, res) => {
  const { role } = req.query;
  const filter = {};
  if (role) filter.role = role;
  const users = await User.find(filter).select('-passwordHash');
  res.json(users);
});

router.get('/doctors', auth(), async (req, res) => {
  try {
    const doctors = await User.find({ role: 'doctor', isActive: true })
      .select('firstName lastName email phone specialties clinics');
    res.json(doctors);
  } catch (error) {
    console.error('Ошибка получения списка врачей:', error);
    res.status(500).json({ message: 'Не удалось загрузить врачей.' });
  }
});

router.patch(
  '/:id/role',
  auth(['director']),
  [body('role').isIn(['patient', 'doctor', 'admin', 'director'])],
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

router.patch('/:id/status', auth(['admin', 'director']), async (req, res) => {
  const { isActive } = req.body;
  const user = await User.findByIdAndUpdate(req.params.id, { isActive }, { new: true });
  if (!user) {
    return res.status(404).json({ message: 'Пользователь не найден.' });
  }
  res.json(user);
});

module.exports = router;
