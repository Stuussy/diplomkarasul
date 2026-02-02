const express = require('express');
const { body, validationResult } = require('express-validator');
const crypto = require('crypto');
const Clinic = require('../models/Clinic');
const auth = require('../middleware/auth');

const router = express.Router();

const clinicValidators = [
  body('name').notEmpty(),
  body('address').notEmpty(),
  body('location.coordinates').isArray().withMessage('Координаты обязательны.'),
];

router.post('/', auth(['admin', 'director']), clinicValidators, async (req, res) => {
  const errors = validationResult(req);
  if (!errors.isEmpty()) {
    return res.status(400).json({ errors: errors.array() });
  }

  try {
    const clinic = await Clinic.create(req.body);
    res.status(201).json(clinic);
  } catch (error) {
    console.error('Не удалось создать клинику:', error);
    res.status(500).json({ message: 'Ошибка создания клиники.' });
  }
});

router.get('/', auth(), async (req, res) => {
  const { lat, lon, radius = 5000 } = req.query;
  if (lat && lon) {
    const clinics = await Clinic.find({
      location: {
        $nearSphere: {
          $geometry: { type: 'Point', coordinates: [parseFloat(lon), parseFloat(lat)] },
          $maxDistance: parseInt(radius, 10),
        },
      },
    });
    return res.json(clinics);
  }

  const clinics = await Clinic.find();
  res.json(clinics);
});

router.patch('/:id', auth(['admin', 'director']), async (req, res) => {
  const clinic = await Clinic.findByIdAndUpdate(req.params.id, req.body, { new: true });
  if (!clinic) {
    return res.status(404).json({ message: 'Клиника не найдена.' });
  }
  res.json(clinic);
});

router.post('/:id/qr', auth(['doctor', 'admin', 'director']), async (req, res) => {
  const clinic = await Clinic.findById(req.params.id);
  if (!clinic) {
    return res.status(404).json({ message: 'Клиника не найдена.' });
  }

  const qrSecret = process.env.QR_SECRET;
  if (!qrSecret) {
    return res.status(500).json({ message: 'QR-секрет не настроен.' });
  }
  const issuedAt = Date.now();
  const basePayload = `clinic:${clinic._id}:${issuedAt}`;
  const signature = crypto.createHmac('sha256', qrSecret).update(basePayload).digest('hex');
  const payload = `${basePayload}:${signature}`;
  clinic.qr = {
    payload,
    updatedBy: req.user.id,
    updatedAt: new Date(),
  };
  await clinic.save();
  res.json(clinic.qr);
});

module.exports = router;
