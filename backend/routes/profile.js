const express = require('express');
const dayjs = require('dayjs');
const auth = require('../middleware/auth');
const Appointment = require('../models/Appointment');
const ScheduleSlot = require('../models/ScheduleSlot');
const Message = require('../models/Message');
const User = require('../models/User');
const Clinic = require('../models/Clinic');

const router = express.Router();

router.get('/overview', auth(['doctor', 'admin', 'support_manager', 'superadmin']), async (req, res) => {
  try {
    const user = await User.findById(req.user.id)
      .select('-passwordHash')
      .populate('clinics', 'name address')
      .lean();

    if (!user) {
      return res.status(404).json({ message: 'Пользователь не найден.' });
    }

    const baseCards = buildBaseCards(user);
    let metrics = [];
    let highlight = null;
    let timeline = [];
    let extraCards = [];

    switch (user.role) {
      case 'doctor': {
        const doctorSummary = await buildDoctorSummary(user);
        metrics = doctorSummary.metrics;
        highlight = doctorSummary.highlight;
        timeline = doctorSummary.timeline;
        extraCards = doctorSummary.cards;
        break;
      }
      case 'admin': {
        const adminSummary = await buildAdminSummary(user);
        metrics = adminSummary.metrics;
        highlight = adminSummary.highlight;
        timeline = adminSummary.timeline;
        extraCards = adminSummary.cards;
        break;
      }
      case 'support_manager': {
        const supportSummary = await buildSupportSummary(user);
        metrics = supportSummary.metrics;
        highlight = supportSummary.highlight;
        timeline = supportSummary.timeline;
        extraCards = supportSummary.cards;
        break;
      }
      case 'superadmin': {
        const directorSummary = await buildDirectorSummary(user);
        metrics = directorSummary.metrics;
        highlight = directorSummary.highlight;
        timeline = directorSummary.timeline;
        extraCards = directorSummary.cards;
        break;
      }
      default:
        break;
    }

    res.json({
      user,
      metrics,
      highlight,
      timeline,
      infoCards: [...baseCards, ...extraCards],
    });
  } catch (error) {
    console.error('Ошибка профиля роли:', error);
    res.status(500).json({ message: 'Не удалось загрузить профиль роли.' });
  }
});

function buildBaseCards(user) {
  const cards = [];

  cards.push({
    title: 'Контакты',
    rows: [
      { label: 'Email', value: user.email },
      { label: 'Телефон', value: user.phone || 'Не указан' },
    ],
  });

  if (Array.isArray(user.clinics) && user.clinics.length > 0) {
    cards.push({
      title: 'Рабочие клиники',
      rows: user.clinics
        .map((clinic) => {
          if (clinic && typeof clinic === 'object') {
            return {
              label: clinic.name || clinic._id?.toString() || '',
              value: clinic.address || '—',
            };
          }
          return {
            label: clinic ? clinic.toString() : '',
            value: '',
          };
        })
        .filter((row) => Boolean(row.label)),
    });
  }

  return cards;
}

async function buildDoctorSummary(user) {
  const now = new Date();
  const monthAhead = dayjs().add(30, 'day').toDate();

  const [totalAppointments, upcomingAppointments, patients, availableSlots] = await Promise.all([
    Appointment.countDocuments({ doctor: user._id }),
    Appointment.countDocuments({
      doctor: user._id,
      startTime: { $gte: now, $lte: monthAhead },
      status: { $ne: 'cancelled' },
    }),
    Appointment.distinct('patient', { doctor: user._id }),
    ScheduleSlot.countDocuments({
      doctor: user._id,
      status: 'available',
      startTime: { $gte: now },
    }),
  ]);

  const nextAppointment = await Appointment.findOne({
    doctor: user._id,
    startTime: { $gte: now },
  })
    .sort('startTime')
    .populate('patient', 'firstName lastName phone')
    .populate('clinic', 'name address');

  const recentAppointments = await Appointment.find({ doctor: user._id })
    .sort({ startTime: -1 })
    .limit(5)
    .populate('patient', 'firstName lastName')
    .populate('clinic', 'name');

  const metrics = [
    {
      label: 'Всего приемов',
      value: totalAppointments,
      caption: 'общее количество за все время',
    },
    {
      label: 'Ближайший месяц',
      value: upcomingAppointments,
      caption: 'записей впереди',
    },
    {
      label: 'Пациентов',
      value: patients.length,
      caption: 'активная база',
    },
    {
      label: 'Свободных слотов',
      value: availableSlots,
      caption: 'можно принять',
    },
  ];

  const highlight = nextAppointment
    ? {
        title: nextAppointment.patient
          ? `${nextAppointment.patient.firstName} ${nextAppointment.patient.lastName}`.trim()
          : 'Пациент',
        subtitle: `${formatDate(nextAppointment.startTime)} · ${formatTime(nextAppointment.startTime)}`,
        meta: `${nextAppointment.service} • ${nextAppointment.clinic?.name || 'Клиника'}`,
        badge: nextAppointment.status,
      }
    : null;

  const timeline = recentAppointments.map((appointment) => ({
    title: appointment.patient
      ? `${appointment.patient.firstName} ${appointment.patient.lastName}`.trim()
      : 'Пациент',
    subtitle: `${appointment.service} · ${appointment.clinic?.name || 'Клиника'}`,
    timestamp: `${formatDate(appointment.startTime)} · ${formatTime(appointment.startTime)}`,
    status: appointment.status,
  }));

  const cards = [];
  if (Array.isArray(user.specialties) && user.specialties.length > 0) {
    cards.push({
      title: 'Специализации',
      rows: user.specialties.map((spec, index) => ({
        label: `#${index + 1}`,
        value: spec,
      })),
    });
  }

  return { metrics, highlight, timeline, cards };
}

async function buildAdminSummary(user) {
  const clinicIds = user.clinics || [];
  const now = new Date();
  const monthAhead = dayjs().add(30, 'day').toDate();

  const [clinicCount, doctors, upcomingAppointments, activeClinics] = await Promise.all([
    Clinic.countDocuments({ _id: { $in: clinicIds } }),
    User.countDocuments({ role: 'doctor', clinics: { $in: clinicIds } }),
    Appointment.countDocuments({
      clinic: { $in: clinicIds },
      startTime: { $gte: now, $lte: monthAhead },
      status: { $ne: 'cancelled' },
    }),
    Clinic.countDocuments({ _id: { $in: clinicIds }, status: 'active' }),
  ]);

  const latestAppointment = await Appointment.findOne({
    clinic: { $in: clinicIds },
    startTime: { $gte: now },
  })
    .sort('startTime')
    .populate('patient', 'firstName lastName phone')
    .populate('clinic', 'name address');

  const recentAppointments = await Appointment.find({ clinic: { $in: clinicIds } })
    .sort({ startTime: -1 })
    .limit(5)
    .populate('patient', 'firstName lastName')
    .populate('clinic', 'name');

  const metrics = [
    { label: 'Клиник', value: clinicCount, caption: 'в управлении' },
    { label: 'Активные', value: activeClinics, caption: 'видимы пациентам' },
    { label: 'Врачей', value: doctors, caption: 'в команде' },
    { label: 'Записей (30д)', value: upcomingAppointments, caption: 'ожидается' },
  ];

  const highlight = latestAppointment
    ? {
        title: latestAppointment.patient
          ? `${latestAppointment.patient.firstName} ${latestAppointment.patient.lastName}`.trim()
          : 'Пациент',
        subtitle: `${formatDate(latestAppointment.startTime)} · ${formatTime(latestAppointment.startTime)}`,
        meta: `${latestAppointment.service} • ${latestAppointment.clinic?.name || 'Клиника'}`,
        badge: latestAppointment.status,
      }
    : null;

  const timeline = recentAppointments.map((appointment) => ({
    title: appointment.patient
      ? `${appointment.patient.firstName} ${appointment.patient.lastName}`.trim()
      : 'Пациент',
    subtitle: `${appointment.service} · ${appointment.clinic?.name || 'Клиника'}`,
    timestamp: `${formatDate(appointment.startTime)} · ${formatTime(appointment.startTime)}`,
    status: appointment.status,
  }));

  const cards = [
    {
      title: 'Клиники',
      rows: clinicIds.map((id, index) => ({
        label: `#${index + 1}`,
        value: id.toString(),
      })),
    },
  ];

  return { metrics, highlight, timeline, cards };
}

async function buildSupportSummary(user) {
  const now = dayjs();
  const yesterday = now.subtract(1, 'day').toDate();
  const [openTickets, inProgressTickets, resolvedLastDay, assignedTickets] = await Promise.all([
    Message.countDocuments({ status: 'open' }),
    Message.countDocuments({ status: 'in_progress' }),
    Message.countDocuments({ status: 'resolved', updatedAt: { $gte: yesterday } }),
    Message.countDocuments({
      assignedTo: user._id,
      status: { $in: ['open', 'in_progress'] },
    }),
  ]);

  const focusTicket = await Message.findOne({
    status: { $in: ['open', 'in_progress'] },
  })
    .sort({ updatedAt: -1 })
    .populate('patient', 'firstName lastName phone');

  const recentTickets = await Message.find()
    .sort({ updatedAt: -1 })
    .limit(5)
    .populate('patient', 'firstName lastName');

  const metrics = [
    { label: 'Открыто', value: openTickets, caption: 'ожидают обработки' },
    { label: 'В работе', value: inProgressTickets, caption: 'на контроле' },
    { label: 'Решено (24ч)', value: resolvedLastDay, caption: 'закрыто за сутки' },
    { label: 'Назначено вам', value: assignedTickets, caption: 'в работе' },
  ];

  const highlight = focusTicket
    ? {
        title: focusTicket.patient
          ? `${focusTicket.patient.firstName} ${focusTicket.patient.lastName}`.trim()
          : 'Пациент',
        subtitle: focusTicket.content.slice(0, 96),
        meta: `Статус: ${focusTicket.status}`,
        badge: assignedTickets > 0 ? `На вас: ${assignedTickets}` : 'Поддержка',
      }
    : null;

  const timeline = recentTickets.map((ticket) => ({
    title: ticket.patient
      ? `${ticket.patient.firstName} ${ticket.patient.lastName}`.trim()
      : 'Пациент',
    subtitle: ticket.content.slice(0, 48),
    timestamp: formatDate(ticket.updatedAt),
    status: ticket.status,
  }));

  const cards = [
    {
      title: 'Поддержка',
      rows: [
        { label: 'Открытые', value: openTickets.toString() },
        { label: 'В работе', value: inProgressTickets.toString() },
      ],
    },
  ];

  return { metrics, highlight, timeline, cards };
}

async function buildDirectorSummary() {
  const weekAgo = dayjs().subtract(7, 'day').toDate();
  const [doctorCount, adminCount, patientCount, clinicList, totalAppointments, recentHires] =
    await Promise.all([
      User.countDocuments({ role: 'doctor' }),
      User.countDocuments({ role: 'admin' }),
      User.countDocuments({ role: 'patient' }),
      Clinic.find().sort({ createdAt: 1 }),
      Appointment.countDocuments({ startTime: { $gte: weekAgo } }),
      User.find({ role: { $in: ['doctor', 'admin', 'support_manager'] } })
        .sort({ createdAt: -1 })
        .limit(5),
    ]);

  const metrics = [
    { label: 'Врачи', value: doctorCount, caption: 'в активной работе' },
    { label: 'Администраторы', value: adminCount, caption: 'координируют процессы' },
    { label: 'Пациенты', value: patientCount, caption: 'в базе' },
    { label: 'Клиники', value: clinicList.length, caption: 'под управлением' },
  ];

  const primaryClinic = clinicList[0];
  const highlight = primaryClinic
    ? {
        title: primaryClinic.name,
        subtitle: primaryClinic.address || '—',
        meta: `Статус: ${primaryClinic.status}`,
        badge: 'Главная клиника',
      }
    : null;

  const timeline = recentHires.map((hire) => ({
    title: `${hire.firstName} ${hire.lastName}`.trim(),
    subtitle: hire.role,
    timestamp: formatDate(hire.createdAt),
    status: 'new_hire',
  }));

  const cards = [];
  if (primaryClinic) {
    cards.push({
      title: 'Детали клиники',
      rows: [
        { label: 'Адрес', value: primaryClinic.address || '—' },
        { label: 'Email', value: primaryClinic.contacts?.email || '—' },
        { label: 'Телефон', value: primaryClinic.contacts?.phone || '—' },
      ],
    });
  }

  cards.push({
    title: 'Операционная динамика',
    rows: [{ label: 'Записей за 7 дней', value: totalAppointments.toString() }],
  });

  return { metrics, highlight, timeline, cards };
}

function formatDate(value) {
  if (!value) return '';
  return dayjs(value).format('DD.MM.YYYY');
}

function formatTime(value) {
  if (!value) return '';
  return dayjs(value).format('HH:mm');
}

module.exports = router;
