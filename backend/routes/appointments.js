const express = require('express');
const { body, validationResult } = require('express-validator');
const dayjs = require('dayjs');
const crypto = require('crypto');
const Appointment = require('../models/Appointment');
const ScheduleSlot = require('../models/ScheduleSlot');
const Fine = require('../models/Fine');
const Clinic = require('../models/Clinic');
const User = require('../models/User');
const auth = require('../middleware/auth');
const { buildAppointmentWindows } = require('../utils/time');
const { notifyMany } = require('../utils/notify');
const {
  buildEventPayload,
  safeCalendarCall,
} = require('../services/google_calendar');

async function getAdminClinicIds(userId) {
  const admin = await User.findById(userId).select('clinics');
  const clinicIds = new Set();
  (admin?.clinics || []).forEach((id) => clinicIds.add(id.toString()));
  const ownedClinics = await Clinic.find({ admin: userId }).select('_id');
  ownedClinics.forEach((clinic) => clinicIds.add(clinic._id.toString()));
  return Array.from(clinicIds);
}

function getAppointmentEndTime(appointment) {
  if (appointment.endTime) {
    return new Date(appointment.endTime);
  }
  return dayjs(appointment.startTime)
    .add(appointment.durationMinutes || 30, 'minute')
    .toDate();
}

async function ensureStaffAppointmentAccess(user, appointment) {
  const doctorId = appointment.doctor?._id || appointment.doctor;
  const clinicId = appointment.clinic?._id || appointment.clinic;

  if (user.role === 'superadmin') return null;

  if (user.role === 'doctor') {
    return doctorId?.toString() === user.id
      ? null
      : 'Можно изменять статус только своих приёмов.';
  }

  if (user.role === 'admin') {
    const clinicIds = await getAdminClinicIds(user.id);
    return clinicIds.includes(clinicId?.toString()) ? null : 'Нет доступа к клинике.';
  }

  return 'Недостаточно прав для изменения статуса.';
}

async function markAppointmentAttendance(req, res, nextStatus) {
  try {
    const appointment = await Appointment.findById(req.params.id)
      .populate('doctor', 'firstName lastName specialties')
      .populate('patient', 'firstName lastName phone')
      .populate('clinic')
      .populate('review', 'rating comment createdAt');

    if (!appointment) {
      return res.status(404).json({ message: 'Запись не найдена.' });
    }

    const accessError = await ensureStaffAppointmentAccess(req.user, appointment);
    if (accessError) {
      return res.status(403).json({ message: accessError });
    }

    if (!['scheduled', 'confirmed'].includes(appointment.status)) {
      return res.status(400).json({
        message:
          nextStatus === 'completed'
            ? 'Завершить можно только запланированный или подтверждённый приём.'
            : 'Отметить неявку можно только для запланированного или подтверждённого приёма.',
      });
    }

    if (new Date() < getAppointmentEndTime(appointment)) {
      return res.status(400).json({
        message:
          nextStatus === 'completed'
            ? 'Отметить завершение можно только после окончания приёма.'
            : 'Отметить неявку можно только после окончания времени приёма.',
      });
    }

    if (nextStatus === 'completed') {
      appointment.status = 'completed';
      appointment.completedAt = new Date();
      appointment.completedBy = req.user.id;
      appointment.noShowAt = null;
      appointment.noShowMarkedBy = null;
    } else {
      appointment.status = 'no_show';
      appointment.noShowAt = new Date();
      appointment.noShowMarkedBy = req.user.id;
      appointment.completedAt = null;
      appointment.completedBy = null;
    }

    await appointment.save();

    await notifyMany([appointment.doctor?._id, appointment.patient?._id], {
      title: nextStatus === 'completed' ? 'Приём завершён' : 'Приём отмечен как неявка',
      body:
        nextStatus === 'completed'
          ? `Визит ${dayjs(appointment.startTime).format('DD.MM HH:mm')} завершён`
          : `Визит ${dayjs(appointment.startTime).format('DD.MM HH:mm')} отмечен как неявка`,
      type: 'appointment',
      data: { appointmentId: appointment._id.toString() },
    });

    return res.json(appointment);
  } catch (error) {
    console.error('Ошибка изменения статуса приёма:', error);
    return res.status(500).json({ message: 'Не удалось изменить статус приёма.' });
  }
}

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

  let reservedSlotId = null;

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
      slot = await ScheduleSlot.findOneAndUpdate(
        { _id: slotId, status: 'available' },
        { $set: { status: 'booked' } },
        { new: true },
      );
      if (!slot) {
        return res.status(400).json({ message: 'Выбранный слот уже занят.' });
      }
      reservedSlotId = slot._id;
    }

    const clinicIdToCheck = slot ? slot.clinic : clinicId;
    const clinic = await Clinic.findById(clinicIdToCheck);
    if (!clinic || clinic.status !== 'active') {
      return res.status(400).json({ message: 'Клиника недоступна для записи.' });
    }

    const start = slot ? slot.startTime : new Date(startTime);
    const duration = slot
      ? dayjs(slot.endTime).diff(dayjs(slot.startTime), 'minute')
      : durationMinutes;
    const endTime = dayjs(start).add(duration, 'minute').toDate();

    if (!slotId) {
      const conflict = await Appointment.findOne({
        doctor: doctorId,
        status: { $in: ['scheduled', 'confirmed'] },
        $expr: {
          $and: [
            { $lt: ['$startTime', endTime] },
            {
              $gt: [
                { $add: ['$startTime', { $multiply: ['$durationMinutes', 60000] }] },
                start,
              ],
            },
          ],
        },
      });

      if (conflict) {
        return res.status(409).json({
          code: 'doctor_time_conflict',
          message: 'У врача уже есть запись на выбранное время.',
        });
      }
    }
    const { confirmWindow, cancelBefore } = buildAppointmentWindows(start, duration);

    const appointment = await Appointment.create({
      patient: patientId,
      doctor: slot ? slot.doctor : doctorId,
      clinic: slot ? slot.clinic : clinicId,
      service,
      startTime: start,
      durationMinutes: duration,
      endTime,
      confirmWindow,
      cancelBefore,
      slot: slot ? slot._id : undefined,
      notes,
      createdBy: patientId,
    });

    if (slot) {
      slot.appointment = appointment._id;
      await slot.save();
    }

    try {
      const [patient, doctor, clinic] = await Promise.all([
        User.findById(appointment.patient),
        User.findById(appointment.doctor),
        Clinic.findById(appointment.clinic),
      ]);
      const patientEvent = buildEventPayload({
        appointment,
        clinic,
        patient,
        doctor,
        roleLabel: 'Пациент',
      });
      const doctorEvent = buildEventPayload({
        appointment,
        clinic,
        patient,
        doctor,
        roleLabel: 'Врач',
      });

      const patientResult = await safeCalendarCall(patient, (calendar, calendarId) =>
        calendar.events.insert({ calendarId, requestBody: patientEvent }),
      );
      const doctorResult = await safeCalendarCall(doctor, (calendar, calendarId) =>
        calendar.events.insert({ calendarId, requestBody: doctorEvent }),
      );

      const errorMessages = [];
      if (patientResult.status === 'failed') errorMessages.push(`patient: ${patientResult.error}`);
      if (doctorResult.status === 'failed') errorMessages.push(`doctor: ${doctorResult.error}`);

      appointment.googleEventIdPatient =
        patientResult.status === 'ok' ? patientResult.result.data.id : appointment.googleEventIdPatient;
      appointment.googleEventIdDoctor =
        doctorResult.status === 'ok' ? doctorResult.result.data.id : appointment.googleEventIdDoctor;
      appointment.googleSyncLastAttempt = new Date();

      if (patientResult.status === 'failed' || doctorResult.status === 'failed') {
        appointment.googleSyncStatus = 'failed';
        appointment.googleSyncError = errorMessages.join('; ');
      } else if (patientResult.status === 'ok' && doctorResult.status === 'ok') {
        appointment.googleSyncStatus = 'synced';
        appointment.googleSyncError = null;
      } else if (patientResult.status === 'skipped' && doctorResult.status === 'skipped') {
        appointment.googleSyncStatus = 'skipped';
        appointment.googleSyncError = 'calendar_not_connected';
      } else {
        appointment.googleSyncStatus = 'partial';
        appointment.googleSyncError = 'partial_calendar_connection';
      }

      await appointment.save();
    } catch (error) {
      appointment.googleSyncStatus = 'failed';
      appointment.googleSyncError = 'google_calendar_error';
      appointment.googleSyncLastAttempt = new Date();
      await appointment.save();
    }

    res.status(201).json(appointment);
  } catch (error) {
    if (reservedSlotId) {
      await ScheduleSlot.findByIdAndUpdate(reservedSlotId, {
        status: 'available',
        appointment: null,
      });
    }
    console.error('Ошибка создания записи:', error);
    res.status(500).json({ message: 'Не удалось создать запись.' });
  }
});

router.get('/', auth(), async (req, res) => {
  const query = {};
  const { from, to, doctorId, patientId, clinicId, status } = req.query;

  if (from && to) {
    query.startTime = { $gte: new Date(from), $lte: new Date(to) };
  }
  if (doctorId) query.doctor = doctorId;
  if (patientId) query.patient = patientId;
  if (clinicId) query.clinic = clinicId;
  if (status) {
    const statuses = String(status).split(',').map((s) => s.trim()).filter(Boolean);
    if (statuses.length === 1) {
      query.status = statuses[0];
    } else if (statuses.length > 1) {
      query.status = { $in: statuses };
    }
  }

  if (req.user.role === 'patient') {
    query.patient = req.user.id;
  } else if (req.user.role === 'doctor') {
    query.doctor = req.user.id;
  } else if (req.user.role === 'admin') {
    const clinicIds = await getAdminClinicIds(req.user.id);
    if (clinicIds.length === 0) {
      return res.json([]);
    }
    query.clinic = { $in: clinicIds };
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
  if (appointment.status !== 'scheduled') {
    return res.status(400).json({ message: 'Подтвердить можно только ожидающую запись.' });
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

  await notifyMany([appointment.doctor?._id, appointment.patient?._id], {
    title: 'Запись подтверждена',
    body: `Приём подтверждён на ${dayjs(appointment.startTime).format('DD.MM HH:mm')}`,
    type: 'appointment',
    data: { appointmentId: appointment._id.toString() },
  });

  res.json(appointment);
});

router.post('/qr-confirm', auth(['patient']), async (req, res) => {
  const { payload } = req.body;
  if (!payload || typeof payload !== 'string') {
    return res.status(400).json({ message: 'payload обязателен.' });
  }

  const parts = payload.split(':');
  if (parts.length < 4 || parts[0] !== 'clinic') {
    return res.status(400).json({ message: 'Некорректный QR-код.' });
  }

  const clinicId = parts[1];
  const issuedAt = Number(parts[2]);
  const signature = parts[3];
  if (!clinicId || Number.isNaN(issuedAt)) {
    return res.status(400).json({ message: 'Некорректный QR-код.' });
  }

  const qrSecret = process.env.QR_SECRET;
  if (!qrSecret) {
    return res.status(500).json({ message: 'QR-секрет не настроен.' });
  }
  const basePayload = `clinic:${clinicId}:${issuedAt}`;
  const expected = crypto.createHmac('sha256', qrSecret).update(basePayload).digest('hex');
  if (signature !== expected) {
    return res.status(400).json({ message: 'Подпись QR-кода недействительна.' });
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

router.post('/:id/cancel', auth(['patient', 'admin', 'superadmin']), async (req, res) => {
  const appointment = await Appointment.findById(req.params.id);
  if (!appointment) {
    return res.status(404).json({ message: 'Запись не найдена.' });
  }
  if (!['scheduled', 'confirmed'].includes(appointment.status)) {
    return res.status(400).json({ message: 'Отменить можно только активную запись.' });
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

  await notifyMany([appointment.doctor, appointment.patient], {
    title: 'Запись отменена',
    body: `Приём на ${dayjs(appointment.startTime).format('DD.MM HH:mm')} отменён`,
    type: 'appointment',
    data: { appointmentId: appointment._id.toString() },
  });

  if (appointment.slot) {
    await ScheduleSlot.findByIdAndUpdate(appointment.slot, {
      status: 'available',
      appointment: null,
    });
  }

  try {
    const [patient, doctor] = await Promise.all([
      User.findById(appointment.patient),
      User.findById(appointment.doctor),
    ]);
    const deletePatient = appointment.googleEventIdPatient
      ? safeCalendarCall(patient, (calendar, calendarId) =>
          calendar.events.delete({
            calendarId,
            eventId: appointment.googleEventIdPatient,
          }),
        )
      : { status: 'skipped' };
    const deleteDoctor = appointment.googleEventIdDoctor
      ? safeCalendarCall(doctor, (calendar, calendarId) =>
          calendar.events.delete({
            calendarId,
            eventId: appointment.googleEventIdDoctor,
          }),
        )
      : { status: 'skipped' };

    const [patientResult, doctorResult] = await Promise.all([deletePatient, deleteDoctor]);
    appointment.googleSyncLastAttempt = new Date();
    if (patientResult.status === 'failed' || doctorResult.status === 'failed') {
      appointment.googleSyncStatus = 'failed';
      appointment.googleSyncError = [
        patientResult.status === 'failed' ? `patient: ${patientResult.error}` : null,
        doctorResult.status === 'failed' ? `doctor: ${doctorResult.error}` : null,
      ]
        .filter(Boolean)
        .join('; ');
    } else {
      appointment.googleSyncStatus = 'synced';
      appointment.googleSyncError = null;
    }
    await appointment.save();
  } catch (error) {
    appointment.googleSyncStatus = 'failed';
    appointment.googleSyncError = 'google_calendar_error';
    appointment.googleSyncLastAttempt = new Date();
    await appointment.save();
  }

  res.json(appointment);
});

router.post('/:id/complete', auth(['doctor', 'admin', 'superadmin']), async (req, res) => {
  return markAppointmentAttendance(req, res, 'completed');
});

router.post('/:id/no-show', auth(['doctor', 'admin', 'superadmin']), async (req, res) => {
  return markAppointmentAttendance(req, res, 'no_show');
});

router.patch(
  '/:id/reschedule',
  auth(['patient', 'doctor', 'admin', 'superadmin']),
  [body('startTime').isISO8601(), body('durationMinutes').optional().isInt({ min: 10 })],
  async (req, res) => {
    const errors = validationResult(req);
    if (!errors.isEmpty()) {
      return res.status(400).json({ errors: errors.array() });
    }

    const appointment = await Appointment.findById(req.params.id);
    if (!appointment) {
      return res.status(404).json({ message: 'Запись не найдена.' });
    }
    if (!['scheduled', 'confirmed'].includes(appointment.status)) {
      return res.status(400).json({ message: 'Перенести можно только активную запись.' });
    }

    if (req.user.role === 'patient' && appointment.patient.toString() !== req.user.id) {
      return res.status(403).json({ message: 'Можно переносить только свои записи.' });
    }
    if (req.user.role === 'doctor' && appointment.doctor.toString() !== req.user.id) {
      return res.status(403).json({ message: 'Можно переносить только свои записи.' });
    }
    if (req.user.role === 'admin') {
      const clinic = await Clinic.findById(appointment.clinic);
      const adminClinicIds = await getAdminClinicIds(req.user.id);
      const hasAccess =
        clinic &&
        (clinic.admin?.toString() === req.user.id ||
          adminClinicIds.includes(clinic._id.toString()));
      if (!hasAccess) {
        return res.status(403).json({ message: 'Нет доступа к клинике.' });
      }
    }

    const start = new Date(req.body.startTime);
    const duration = req.body.durationMinutes ?? appointment.durationMinutes;
    const endTime = dayjs(start).add(duration, 'minute').toDate();

    const conflict = await Appointment.findOne({
      _id: { $ne: appointment._id },
      doctor: appointment.doctor,
      status: { $in: ['scheduled', 'confirmed'] },
      $expr: {
        $and: [
          { $lt: ['$startTime', endTime] },
          {
            $gt: [
              { $add: ['$startTime', { $multiply: ['$durationMinutes', 60000] }] },
              start,
            ],
          },
        ],
      },
    });
    if (conflict) {
      return res.status(409).json({
        code: 'doctor_time_conflict',
        message: 'У врача уже есть запись на выбранное время.',
      });
    }

    const { confirmWindow, cancelBefore } = buildAppointmentWindows(start, duration);
    appointment.startTime = start;
    appointment.endTime = endTime;
    appointment.durationMinutes = duration;
    appointment.confirmWindow = confirmWindow;
    appointment.cancelBefore = cancelBefore;
    appointment.status = 'scheduled';
    appointment.confirmedAt = null;
    appointment.slot = undefined;
    await appointment.save();

    await notifyMany([appointment.doctor, appointment.patient], {
      title: 'Запись перенесена',
      body: `Новая дата: ${dayjs(appointment.startTime).format('DD.MM HH:mm')}`,
      type: 'appointment',
      data: { appointmentId: appointment._id.toString() },
    });

    try {
      const [patient, doctor, clinic] = await Promise.all([
        User.findById(appointment.patient),
        User.findById(appointment.doctor),
        Clinic.findById(appointment.clinic),
      ]);
      const patientEvent = buildEventPayload({
        appointment,
        clinic,
        patient,
        doctor,
        roleLabel: 'Пациент',
      });
      const doctorEvent = buildEventPayload({
        appointment,
        clinic,
        patient,
        doctor,
        roleLabel: 'Врач',
      });

      const patientResult = appointment.googleEventIdPatient
        ? await safeCalendarCall(patient, (calendar, calendarId) =>
            calendar.events.patch({
              calendarId,
              eventId: appointment.googleEventIdPatient,
              requestBody: patientEvent,
            }),
          )
        : await safeCalendarCall(patient, (calendar, calendarId) =>
            calendar.events.insert({ calendarId, requestBody: patientEvent }),
          );

      const doctorResult = appointment.googleEventIdDoctor
        ? await safeCalendarCall(doctor, (calendar, calendarId) =>
            calendar.events.patch({
              calendarId,
              eventId: appointment.googleEventIdDoctor,
              requestBody: doctorEvent,
            }),
          )
        : await safeCalendarCall(doctor, (calendar, calendarId) =>
            calendar.events.insert({ calendarId, requestBody: doctorEvent }),
          );

      appointment.googleEventIdPatient =
        patientResult.status === 'ok'
          ? patientResult.result.data.id || appointment.googleEventIdPatient
          : appointment.googleEventIdPatient;
      appointment.googleEventIdDoctor =
        doctorResult.status === 'ok'
          ? doctorResult.result.data.id || appointment.googleEventIdDoctor
          : appointment.googleEventIdDoctor;

      appointment.googleSyncLastAttempt = new Date();
      if (patientResult.status === 'failed' || doctorResult.status === 'failed') {
        appointment.googleSyncStatus = 'failed';
        appointment.googleSyncError = [
          patientResult.status === 'failed' ? `patient: ${patientResult.error}` : null,
          doctorResult.status === 'failed' ? `doctor: ${doctorResult.error}` : null,
        ]
          .filter(Boolean)
          .join('; ');
      } else if (patientResult.status === 'ok' && doctorResult.status === 'ok') {
        appointment.googleSyncStatus = 'synced';
        appointment.googleSyncError = null;
      } else if (patientResult.status === 'skipped' && doctorResult.status === 'skipped') {
        appointment.googleSyncStatus = 'skipped';
        appointment.googleSyncError = 'calendar_not_connected';
      } else {
        appointment.googleSyncStatus = 'partial';
        appointment.googleSyncError = 'partial_calendar_connection';
      }
      await appointment.save();
    } catch (error) {
      appointment.googleSyncStatus = 'failed';
      appointment.googleSyncError = 'google_calendar_error';
      appointment.googleSyncLastAttempt = new Date();
      await appointment.save();
    }

    res.json(appointment);
  },
);

router.post(
  '/slots',
  auth(['admin', 'superadmin']),
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

      if (req.user.role === 'admin') {
        const clinic = await Clinic.findById(clinicId);
        const adminClinicIds = await getAdminClinicIds(req.user.id);
        const hasAccess =
          clinic &&
          (clinic.admin?.toString() === req.user.id || adminClinicIds.includes(clinicId));
        if (!hasAccess) {
          return res.status(403).json({ message: 'Нет доступа к клинике.' });
        }
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
  if (req.user.role === 'admin') {
    const clinicIds = await getAdminClinicIds(req.user.id);
    if (clinicIds.length === 0) {
      return res.json([]);
    }
    filter.clinic = { $in: clinicIds };
  }

  const slots = await ScheduleSlot.find(filter).sort({ startTime: 1 });
  res.json(slots);
});

router.delete('/slots/:id', auth(['admin', 'superadmin']), async (req, res) => {
  const slot = await ScheduleSlot.findById(req.params.id);
  if (!slot) {
    return res.status(404).json({ message: 'Слот не найден.' });
  }
  if (req.user.role === 'admin') {
    const clinic = await Clinic.findById(slot.clinic);
    const adminClinicIds = await getAdminClinicIds(req.user.id);
    const hasAccess =
      clinic &&
      (clinic.admin?.toString() === req.user.id ||
        adminClinicIds.includes(clinic._id.toString()));
    if (!hasAccess) {
      return res.status(403).json({ message: 'Нет доступа к клинике.' });
    }
  }
  if (slot.status === 'booked') {
    return res.status(400).json({ message: 'Нельзя удалить занятой слот.' });
  }
  await slot.deleteOne();
  res.json({ success: true });
});

module.exports = router;
