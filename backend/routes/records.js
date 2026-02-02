const express = require('express');
const MedicalRecord = require('../models/MedicalRecord');
const auth = require('../middleware/auth');
const upload = require('../middleware/upload');

const router = express.Router();

router.post(
  '/',
  auth(['doctor', 'admin', 'director']),
  upload.array('files', 5),
  async (req, res) => {
    try {
      const { patientId, appointmentId, title, description, tags } = req.body;
      const attachments = (req.files || []).map((file) => ({
        url: file.path,
        cloudinaryId: file.filename,
        format: file.mimetype,
      }));

      const record = await MedicalRecord.create({
        patient: patientId,
        doctor: req.user.id,
        appointment: appointmentId,
        title,
        description,
        attachments,
        tags: tags ? tags.split(',').map((tag) => tag.trim()) : [],
        createdBy: req.user.id,
      });

      res.status(201).json(record);
    } catch (error) {
      console.error('Ошибка сохранения записи:', error);
      res.status(500).json({ message: 'Не удалось сохранить медицинскую запись.' });
    }
  },
);

router.get('/mine', auth(['patient']), async (req, res) => {
  const records = await MedicalRecord.find({ patient: req.user.id })
    .populate('doctor', 'firstName lastName specialties')
    .sort({ createdAt: -1 });
  res.json(records);
});

router.get('/:patientId', auth(['doctor', 'admin', 'director']), async (req, res) => {
  const { patientId } = req.params;
  const filter = { patient: patientId };
  if (req.user.role === 'doctor') {
    filter.doctor = req.user.id;
  }

  const records = await MedicalRecord.find(filter)
    .populate('doctor', 'firstName lastName specialties')
    .sort({ createdAt: -1 });
  res.json(records);
});

router.patch('/:id', auth(['doctor', 'admin', 'director']), async (req, res) => {
  const record = await MedicalRecord.findById(req.params.id);
  if (!record) {
    return res.status(404).json({ message: 'Запись не найдена.' });
  }
  if (req.user.role === 'doctor' && record.doctor.toString() !== req.user.id) {
    return res.status(403).json({ message: 'Можно редактировать только свои записи.' });
  }

  const updatable = {};
  ['title', 'description'].forEach((field) => {
    if (req.body[field] !== undefined) updatable[field] = req.body[field];
  });
  if (req.body.tags) {
    updatable.tags = Array.isArray(req.body.tags) ? req.body.tags : req.body.tags.split(',');
  }

  const updated = await MedicalRecord.findByIdAndUpdate(record._id, updatable, {
    new: true,
  });
  res.json(updated);
});

module.exports = router;
