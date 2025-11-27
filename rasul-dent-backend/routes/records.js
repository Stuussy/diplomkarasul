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

router.get('/:patientId', auth(), async (req, res) => {
  const { patientId } = req.params;

  if (req.user.role === 'patient' && req.user.id !== patientId) {
    return res.status(403).json({ message: 'Нет доступа к чужой карте.' });
  }

  const filter = { patient: patientId };
  if (req.user.role === 'doctor') {
    filter.doctor = req.user.id;
  }

  const records = await MedicalRecord.find(filter)
    .populate('doctor', 'firstName lastName')
    .sort({ createdAt: -1 });
  res.json(records);
});

module.exports = router;
