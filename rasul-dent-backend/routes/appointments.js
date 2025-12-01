const express = require('express');
const { body, validationResult } = require('express-validator');
const dayjs = require('dayjs');
const Appointment = require('../models/Appointment');
const ScheduleSlot = require('../models/ScheduleSlot');
const Fine = require('../models/Fine');
const Clinic = require('../models/Clinic');
const auth = require('../middleware/auth');
const { buildAppointmentWindows } = require('../utils/time');

const router = express.Router();

const createValidators = [
  body('doctorId').optional().notEmpty(),
  body('clinicId').optional().notEmpty(),
  body('service').notEmpty(),
  body('startTime').optional().isISO8601(),
  body('slotId').optional().isString(),
];

router.post('/', auth(['patient']), createValidators, async (req, res) => {
  const errors = validationResult(req);
  if (!errors.isEmpty()) {
    return res.status(400).json({ errors: errors.array() });
  }

  try {
    const { doctorId, clinicId, service, startTime, durationMinutes = 30, slotId, notes } = req.body;
    const patientId = req.user.id;

    if (!slotId && (!doctorId || !clinicId || !startTime)) {
      return res
        .status(400)
        .json({ message: 'Для ручного бронирования нужны doctorId, clinicId и startTime.' });
    }

    const existingActive = await Appointment.findOne({
      patient: patientId,
      status: { $in: ['scheduled', 'confirmed'] },
    });
    if (existingActive) {
      return res.status(409).json({
        code: 'already_booked',
        message: 'Вы уже записаны на приём. Отмените текущую запись перед новой.',
      });
    }

    let slot;
    if (slotId) {
      slot = await ScheduleSlot.findById(slotId);
      if (!slot || slot.status !== 'available') {
        return res.status(400).json({ message: 'Выбранный слот уже занят.' });
      }
    }

    const start = slot ? slot.startTime : new Date(startTime);
    const duration = slot ? dayjs(slot.endTime).diff(dayjs(slot.startTime), 'minute') : durationMinutes;
    const { confirmWindow, cancelBefore } = buildAppointmentWindows(start, duration);

    const appointment = await Appointment.create({
      patient: patientId,
      doctor: slot ? slot.doctor : doctorId,
      clinic: slot ? slot.clinic : clinicId,
      service,
      startTime: start,
      durationMinutes: duration,
      confirmWindow,
      cancelBefore,
      slot: slot ? slot._id : undefined,
      notes,
      createdBy: patientId,
    });

    if (slot) {
      slot.status = 'booked';
      slot.appointment = appointment._id;
      await slot.save();
    }

    res.status(201).json(appointment);
  } catch (error) {
    console.error('Ошибка создания записи:', error);
    res.status(500).json({ message: 'Не удалось создать запись.' });
  }
});

router.get('/', auth(), async (req, res) => {
  const query = {};
  const { from, to, doctorId, patientId, clinicId } = req.query;

  if (from && to) {
    query.startTime = { $gte: new Date(from), $lte: new Date(to) };
  }
  if (doctorId) query.doctor = doctorId;
  if (patientId) query.patient = patientId;
  if (clinicId) query.clinic = clinicId;

  if (req.user.role === 'patient') {
    query.patient = req.user.id;
  } else if (req.user.role === 'doctor') {
    query.doctor = req.user.id;
  }

  const appointments = await Appointment.find(query)
    .populate('doctor', 'firstName lastName specialties')
    .populate('patient', 'firstName lastName phone')
    .populate('clinic')
    .populate('review', 'rating comment createdAt');
  res.json(appointments);
});

router.post('/:id/confirm', auth(['patient']), async (req, res) => {
  const appointment = await Appointment.findById(req.params.id)
    .populate('doctor', 'firstName lastName specialties')
    .populate('patient', 'firstName lastName phone')
    .populate('clinic');
  if (!appointment || appointment.patient.toString() !== req.user.id) {
    return res.status(404).json({ message: 'Запись не найдена.' });
  }

  const now = new Date();
  if (
    !appointment.confirmWindow ||
    now < appointment.confirmWindow.start ||
    now > appointment.confirmWindow.end
  ) {
    return res.status(400).json({ message: 'Подтверждение доступно за 30 минут до и 15 мин после начала.' });
  }

  appointment.status = 'confirmed';
  appointment.confirmedAt = now;
  await appointment.save();

  res.json(appointment);
});

router.post('/qr-confirm', auth(['patient']), async (req, res) => {
  const { payload } = req.body;
  if (!payload || typeof payload !== 'string') {
    return res.status(400).json({ message: 'payload обязателен.' });
  }

  const parts = payload.split(':');
  if (parts.length < 3 || parts[0] !== 'clinic') {
    return res.status(400).json({ message: 'Некорректный QR-код.' });
  }

  const clinicId = parts[1];
  const issuedAt = Number(parts[2]);
  if (!clinicId || Number.isNaN(issuedAt)) {
    return res.status(400).json({ message: 'Некорректный QR-код.' });
  }

  const now = Date.now();
  if (now - issuedAt > 1000 * 60 * 60 * 24) {
    return res.status(400).json({ message: 'QR-код устарел. Попросите новый.' });
  }

  const clinic = await Clinic.findById(clinicId);
  if (!clinic) {
    return res.status(404).json({ message: 'Клиника не найдена.' });
  }

  const windowStart = dayjs().subtract(4, 'hour').toDate();
  const windowEnd = dayjs().add(1, 'day').toDate();

  const appointment = await Appointment.findOne({
    patient: req.user.id,
    clinic: clinicId,
    status: 'scheduled',
    startTime: { $gte: windowStart, $lte: windowEnd },
  })
    .sort({ startTime: 1 })
    .populate('doctor', 'firstName lastName specialties')
    .populate('patient', 'firstName lastName phone')
    .populate('clinic');

  if (!appointment) {
    return res.status(404).json({ message: 'Нет подходящих записей для подтверждения.' });
  }

  appointment.status = 'confirmed';
  appointment.confirmedAt = new Date();
  await appointment.save();

  res.json(appointment);
});

router.post('/:id/cancel', auth(['patient', 'admin', 'director']), async (req, res) => {
  const appointment = await Appointment.findById(req.params.id);
  if (!appointment) {
    return res.status(404).json({ message: 'Запись не найдена.' });
  }

  if (req.user.role === 'patient' && appointment.patient.toString() !== req.user.id) {
    return res.status(403).json({ message: 'Можно отменять только свои записи.' });
  }

  const now = new Date();
  if (req.user.role === 'patient' && appointment.cancelBefore && now > appointment.cancelBefore) {
    if (!appointment.fineIssued) {
      await Fine.create({
        patient: appointment.patient,
        appointment: appointment._id,
        amount: 3000,
        reason: 'Отмена позднее чем за 2 часа',
        issuedBy: req.user.id,
      });
      appointment.fineIssued = true;
      await appointment.save();
    }
    return res
      .status(403)
      .json({ message: 'Отмена менее чем за 2 часа недоступна. Начислен штраф 3000 тг.' });
  }

  appointment.status = 'cancelled';
  appointment.cancelledAt = now;
  appointment.cancelledBy = req.user.id;
  await appointment.save();

  if (appointment.slot) {
    await ScheduleSlot.findByIdAndUpdate(appointment.slot, {
      status: 'available',
      appointment: null,
    });
  }

  res.json(appointment);
});

router.post(
  '/slots',
  auth(['admin', 'director']),
  [
    body('doctorId').notEmpty(),
    body('clinicId').notEmpty(),
    body('startTime').isISO8601(),
    body('endTime').isISO8601(),
  ],
  async (req, res) => {
    const errors = validationResult(req);
    if (!errors.isEmpty()) {
      return res.status(400).json({ errors: errors.array() });
    }

    try {
      const { doctorId, clinicId, startTime, endTime } = req.body;
      if (new Date(endTime) <= new Date(startTime)) {
        return res.status(400).json({ message: 'Время окончания должно быть позже начала.' });
      }

      const slot = await ScheduleSlot.create({
        doctor: doctorId,
        clinic: clinicId,
        startTime,
        endTime,
        createdBy: req.user.id,
      });
      res.status(201).json(slot);
    } catch (error) {
      console.error('Ошибка создания слота:', error);
      res.status(500).json({ message: 'Не удалось создать слот.' });
    }
  },
);

router.get('/slots', auth(), async (req, res) => {
  const filter = {};
  const { doctorId, clinicId, status } = req.query;
  if (doctorId) filter.doctor = doctorId;
  if (clinicId) filter.clinic = clinicId;
  if (status) filter.status = status;
  if (req.user.role === 'patient') {
    filter.status = 'available';
  }
  if (req.user.role === 'doctor') filter.doctor = req.user.id;

  const slots = await ScheduleSlot.find(filter).sort({ startTime: 1 });
  res.json(slots);
});

router.delete('/slots/:id', auth(['admin', 'director']), async (req, res) => {
  const slot = await ScheduleSlot.findById(req.params.id);
  if (!slot) {
    return res.status(404).json({ message: 'Слот не найден.' });
  }
  if (slot.status === 'booked') {
    return res.status(400).json({ message: 'Нельзя удалить занятой слот.' });
  }
  await slot.deleteOne();
  res.json({ success: true });
});

module.exports = router;
