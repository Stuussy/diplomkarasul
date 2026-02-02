const express = require('express');
const { body, validationResult } = require('express-validator');
const User = require('../models/User');
const { signToken } = require('../utils/token');
const auth = require('../middleware/auth');

const router = express.Router();

const registerValidators = [
  body('firstName').notEmpty().withMessage('Имя обязательно.'),
  body('lastName').notEmpty().withMessage('Фамилия обязательна.'),
  body('email').isEmail().withMessage('Укажите корректный email.'),
  body('password').isLength({ min: 6 }).withMessage('Минимум 6 символов для пароля.'),
];

router.post('/register', registerValidators, async (req, res) => {
  const errors = validationResult(req);
  if (!errors.isEmpty()) {
    return res.status(400).json({ errors: errors.array() });
  }

  try {
    const { firstName, lastName, email, password, phone } = req.body;

    const existing = await User.findOne({ email });
    if (existing) {
      return res.status(400).json({ message: 'Пользователь с таким email уже существует.' });
    }

    const passwordHash = await User.hashPassword(password);
    const user = await User.create({
      firstName,
      lastName,
      email,
      phone,
      passwordHash,
      role: 'patient',
    });

    const token = signToken(user);
    res.status(201).json({ token, user });
  } catch (error) {
    console.error('Регистрация не удалась:', error);
    res.status(500).json({ message: 'Ошибка регистрации пользователя.' });
  }
});

router.post(
  '/login',
  [body('email').isEmail(), body('password').notEmpty()],
  async (req, res) => {
    const errors = validationResult(req);
    if (!errors.isEmpty()) {
      return res.status(400).json({ errors: errors.array() });
    }

    try {
      const { email, password } = req.body;
      const user = await User.findOne({ email, isActive: true });

      if (!user) {
        return res.status(401).json({ message: 'Неверный email или пароль.' });
      }

      const isValid = await user.comparePassword(password);
      if (!isValid) {
        return res.status(401).json({ message: 'Неверный email или пароль.' });
      }

      const token = signToken(user);
      res.json({ token, user });
    } catch (error) {
      console.error('Ошибка авторизации:', error);
      res.status(500).json({ message: 'Не удалось выполнить вход.' });
    }
  },
);

router.get('/me', auth(), async (req, res) => {
  const user = await User.findById(req.user.id).select('-passwordHash');
  res.json(user);
});

router.patch(
  '/me',
  auth(),
  [
    body('firstName').optional().isLength({ min: 1 }).withMessage('Имя не может быть пустым.'),
    body('lastName').optional().isLength({ min: 1 }).withMessage('Фамилия не может быть пустой.'),
    body('phone')
      .optional()
      .isLength({ min: 5 })
      .withMessage('Телефон должен содержать не менее 5 символов.'),
    body('experienceYears').optional().isInt({ min: 0, max: 60 }),
    body('services').optional().isArray(),
    body('bio').optional().isLength({ max: 2000 }),
    body('specialties').optional().isArray(),
  ],
  async (req, res) => {
    const errors = validationResult(req);
    if (!errors.isEmpty()) {
      return res.status(400).json({ errors: errors.array() });
    }

    try {
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

      const user = await User.findByIdAndUpdate(req.user.id, updates, {
        new: true,
      }).select('-passwordHash');
      if (!user) {
        return res.status(404).json({ message: 'Пользователь не найден.' });
      }
      res.json(user);
    } catch (error) {
      console.error('Ошибка обновления профиля:', error);
      res.status(500).json({ message: 'Не удалось обновить профиль.' });
    }
  },
);

router.post(
  '/change-password',
  auth(),
  [
    body('currentPassword').notEmpty().withMessage('Укажите текущий пароль.'),
    body('newPassword')
      .isLength({ min: 6 })
      .withMessage('Новый пароль должен содержать минимум 6 символов.'),
  ],
  async (req, res) => {
    const errors = validationResult(req);
    if (!errors.isEmpty()) {
      return res.status(400).json({ errors: errors.array() });
    }

    const { currentPassword, newPassword } = req.body;

    try {
      const user = await User.findById(req.user.id);
      if (!user) {
        return res.status(404).json({ message: 'Пользователь не найден.' });
      }

      const isValid = await user.comparePassword(currentPassword);
      if (!isValid) {
        return res.status(400).json({ message: 'Текущий пароль указан неверно.' });
      }

      user.passwordHash = await User.hashPassword(newPassword);
      await user.save();
      res.json({ success: true });
    } catch (error) {
      console.error('Ошибка смены пароля:', error);
      res.status(500).json({ message: 'Не удалось сменить пароль.' });
    }
  },
);

router.post('/bootstrap-director', registerValidators, async (req, res) => {
  const secret = process.env.BOOTSTRAP_SECRET;
  if (!secret) {
    return res.status(403).json({ message: 'Создание директора отключено.' });
  }
  if (req.body.bootstrapSecret !== secret) {
    return res.status(403).json({ message: 'Неверный секрет.' });
  }

  const directorExists = await User.findOne({ role: 'director' });
  if (directorExists) {
    return res.status(403).json({ message: 'Директор уже создан.' });
  }

  const errors = validationResult(req);
  if (!errors.isEmpty()) {
    return res.status(400).json({ errors: errors.array() });
  }

  try {
    const { firstName, lastName, email, password, phone } = req.body;
    const passwordHash = await User.hashPassword(password);
    const director = await User.create({
      firstName,
      lastName,
      email,
      phone,
      passwordHash,
      role: 'director',
    });

    const token = signToken(director);
    res.status(201).json({ token, user: director });
  } catch (error) {
    console.error('Ошибка создания директора:', error);
    res.status(500).json({ message: 'Не удалось создать директора.' });
  }
});

module.exports = router;
