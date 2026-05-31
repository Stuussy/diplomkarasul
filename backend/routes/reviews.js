const express = require('express');
const { body, validationResult } = require('express-validator');
const Review = require('../models/Review');
const Appointment = require('../models/Appointment');
const auth = require('../middleware/auth');

const router = express.Router();

router.post(
  '/',
  auth(['patient']),
  [
    body('appointmentId').notEmpty(),
    body('rating').isInt({ min: 1, max: 5 }),
    body('comment').optional().isLength({ max: 1000 }),
  ],
  async (req, res) => {
    const errors = validationResult(req);
    if (!errors.isEmpty()) {
      return res.status(400).json({ errors: errors.array() });
    }

    try {
      const { appointmentId, rating, comment } = req.body;
      const appointment = await Appointment.findById(appointmentId);

      if (!appointment || appointment.patient.toString() !== req.user.id) {
        return res.status(404).json({ message: 'Запись не найдена.' });
      }
      if (appointment.status !== 'completed') {
        return res.status(400).json({ message: 'Оставить отзыв можно после завершения приёма.' });
      }
      const existingReview =
        appointment.review || (await Review.findOne({ appointment: appointment._id }).select('_id'));
      if (existingReview) {
        if (!appointment.review) {
          appointment.review = existingReview._id || existingReview;
          await appointment.save();
        }
        return res.status(409).json({ message: 'Отзыв уже оставлен.' });
      }

      const review = await Review.create({
        appointment: appointment._id,
        doctor: appointment.doctor,
        patient: appointment.patient,
        rating,
        comment,
      });

      appointment.review = review._id;
      await appointment.save();

      const doctor = await Review.model('User').findById(appointment.doctor);
      if (doctor) {
        const currentSum = doctor.rating * doctor.reviews;
        const newReviews = (doctor.reviews || 0) + 1;
        const newRating = (currentSum + rating) / newReviews;
        doctor.rating = Number(newRating.toFixed(1));
        doctor.reviews = newReviews;
        await doctor.save();
      }

      res.status(201).json(review);
    } catch (error) {
      console.error('Ошибка отзыва:', error);
      res.status(500).json({ message: 'Не удалось сохранить отзыв.' });
    }
  },
);

router.get('/doctor/:doctorId', auth(), async (req, res) => {
  const reviews = await Review.find({ doctor: req.params.doctorId })
    .populate('patient', 'firstName lastName')
    .sort({ createdAt: -1 });
  res.json(reviews);
});

// GET /reviews/clinic — последние отзывы по всем врачам клиники + сводка.
// Используется на странице «Клиника» у пациента как отзывы о клинике в целом.
router.get('/clinic', auth(), async (req, res) => {
  try {
    const limit = Math.min(parseInt(req.query.limit, 10) || 10, 50);
    const [reviews, stats] = await Promise.all([
      Review.find()
        .populate('patient', 'firstName lastName')
        .populate('doctor', 'firstName lastName')
        .sort({ createdAt: -1 })
        .limit(limit),
      Review.aggregate([
        {
          $group: {
            _id: null,
            average: { $avg: '$rating' },
            count: { $sum: 1 },
          },
        },
      ]),
    ]);
    const summary = stats[0] || { average: 0, count: 0 };
    res.json({
      average: Number((summary.average || 0).toFixed(1)),
      count: summary.count || 0,
      reviews,
    });
  } catch (error) {
    console.error('Ошибка отзывов клиники:', error);
    res.status(500).json({ message: 'Не удалось загрузить отзывы.' });
  }
});

module.exports = router;
