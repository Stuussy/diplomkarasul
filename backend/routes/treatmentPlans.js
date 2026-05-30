/* eslint-disable no-console */
const express = require('express');
const TreatmentPlan = require('../models/TreatmentPlan');
const Appointment = require('../models/Appointment');
const User = require('../models/User');
const Clinic = require('../models/Clinic');
const auth = require('../middleware/auth');
const { groqChat, parseJsonFromText, hasGroqKey } = require('../services/groq');

const router = express.Router();

function idsEqual(left, right) {
  if (!left || !right) return false;
  return left.toString() === right.toString();
}

async function getAdminClinicIds(userId) {
  const admin = await User.findById(userId).select('clinics');
  const clinicIds = new Set();
  (admin?.clinics || []).forEach((id) => clinicIds.add(id.toString()));
  const ownedClinics = await Clinic.find({ admin: userId }).select('_id');
  ownedClinics.forEach((clinic) => clinicIds.add(clinic._id.toString()));
  return Array.from(clinicIds);
}

const populateFields = [
  { path: 'doctor', select: 'firstName lastName specialties' },
  { path: 'patient', select: 'firstName lastName phone email' },
  { path: 'clinic', select: 'name address' },
];

const PLAN_SYSTEM_PROMPT = `Ты — опытный врач-стоматолог, который составляет планы лечения.
По описанию жалоб/диагноза пациента составь структурированный план лечения по этапам.
Отвечай СТРОГО в формате JSON, без markdown и пояснений, по схеме:
{
  "title": "краткое название плана",
  "diagnosis": "предполагаемый диагноз одной фразой",
  "summary": "краткие рекомендации пациенту (1-2 предложения)",
  "steps": [
    { "procedure": "название процедуры", "description": "что делается на этапе", "durationDays": число_дней_до_следующего_этапа, "price": цена_в_тенге_число }
  ]
}
Правила: 3-6 этапов, реалистичные сроки (durationDays) и цены в тенге (KZT) для Казахстана.
Этапы по порядку выполнения. Пиши на русском. Только JSON.`;

// POST /api/treatment-plans/ai-generate — сгенерировать черновик плана (НЕ сохраняет)
router.post('/ai-generate', auth(['doctor', 'admin', 'superadmin']), async (req, res) => {
  const { complaint, patientId } = req.body;
  if (!complaint || String(complaint).trim().length < 5) {
    return res.status(400).json({ message: 'Опишите жалобы или диагноз (минимум 5 символов).' });
  }
  if (!hasGroqKey()) {
    return res.status(503).json({ message: 'ИИ-генерация плана временно недоступна.' });
  }

  const trimmed = String(complaint).trim().slice(0, 1000);

  try {
    const raw = await groqChat(
      [
        { role: 'system', content: PLAN_SYSTEM_PROMPT },
        { role: 'user', content: `Жалобы/диагноз пациента: ${trimmed}` },
      ],
      { temperature: 0.4, maxTokens: 1200, jsonMode: true },
    );

    const parsed = parseJsonFromText(raw);
    const steps = Array.isArray(parsed.steps) ? parsed.steps : [];
    const normalizedSteps = steps.slice(0, 8).map((step, index) => ({
      order: index + 1,
      procedure: String(step.procedure || `Этап ${index + 1}`).slice(0, 200),
      description: String(step.description || '').slice(0, 600),
      durationDays: Number.isFinite(Number(step.durationDays)) ? Math.max(0, Math.round(Number(step.durationDays))) : 7,
      price: Number.isFinite(Number(step.price)) ? Math.max(0, Math.round(Number(step.price))) : 0,
      status: 'pending',
    }));

    if (normalizedSteps.length === 0) {
      return res.status(502).json({ message: 'ИИ не смог составить план. Попробуйте уточнить описание.' });
    }

    return res.json({
      title: String(parsed.title || 'План лечения').slice(0, 200),
      diagnosis: String(parsed.diagnosis || '').slice(0, 400),
      summary: String(parsed.summary || '').slice(0, 600),
      steps: normalizedSteps,
      aiGenerated: true,
      patientId: patientId || null,
    });
  } catch (error) {
    console.error('AI treatment plan generation failed:', error.message);
    return res.status(502).json({ message: 'Не удалось сгенерировать план. Попробуйте позже.' });
  }
});

// POST /api/treatment-plans — сохранить план
router.post('/', auth(['doctor', 'admin', 'superadmin']), async (req, res) => {
  try {
    const { patientId, title, diagnosis, summary, steps, aiGenerated, status } = req.body;
    if (!patientId) {
      return res.status(400).json({ message: 'Не указан пациент.' });
    }
    if (!title || String(title).trim().length === 0) {
      return res.status(400).json({ message: 'Укажите название плана.' });
    }
    if (!Array.isArray(steps) || steps.length === 0) {
      return res.status(400).json({ message: 'План должен содержать хотя бы один этап.' });
    }

    // Врач: должен иметь приём с этим пациентом
    let doctorId = req.user.id;
    let clinicId;
    if (req.user.role === 'doctor') {
      const appt = await Appointment.findOne({ patient: patientId, doctor: req.user.id })
        .sort({ startTime: -1 })
        .select('clinic');
      if (!appt) {
        return res.status(403).json({ message: 'Можно создавать планы только для своих пациентов.' });
      }
      clinicId = appt.clinic;
    } else {
      // admin/superadmin: берём последний приём пациента для привязки врача/клиники
      const appt = await Appointment.findOne({ patient: patientId })
        .sort({ startTime: -1 })
        .select('doctor clinic');
      if (appt) {
        doctorId = appt.doctor;
        clinicId = appt.clinic;
      }
    }

    const normalizedSteps = steps.slice(0, 12).map((step, index) => ({
      order: index + 1,
      procedure: String(step.procedure || `Этап ${index + 1}`).slice(0, 200),
      description: String(step.description || '').slice(0, 600),
      durationDays: Number.isFinite(Number(step.durationDays)) ? Math.max(0, Math.round(Number(step.durationDays))) : 7,
      price: Number.isFinite(Number(step.price)) ? Math.max(0, Math.round(Number(step.price))) : 0,
      status: ['pending', 'in_progress', 'done'].includes(step.status) ? step.status : 'pending',
    }));

    const plan = await TreatmentPlan.create({
      patient: patientId,
      doctor: doctorId,
      clinic: clinicId,
      title: String(title).trim().slice(0, 200),
      diagnosis: String(diagnosis || '').slice(0, 400),
      summary: String(summary || '').slice(0, 600),
      steps: normalizedSteps,
      status: ['draft', 'active', 'completed', 'cancelled'].includes(status) ? status : 'active',
      aiGenerated: Boolean(aiGenerated),
      createdBy: req.user.id,
    });

    const populated = await TreatmentPlan.findById(plan._id).populate(populateFields);
    res.status(201).json(populated);
  } catch (error) {
    console.error('Ошибка создания плана лечения:', error);
    res.status(500).json({ message: 'Не удалось сохранить план лечения.' });
  }
});

// GET /api/treatment-plans/mine — планы пациента
router.get('/mine', auth(['patient']), async (req, res) => {
  const plans = await TreatmentPlan.find({ patient: req.user.id })
    .populate(populateFields)
    .sort({ createdAt: -1 });
  res.json(plans);
});

// GET /api/treatment-plans/patient/:patientId — планы конкретного пациента (для персонала)
router.get('/patient/:patientId', auth(['doctor', 'admin', 'superadmin']), async (req, res) => {
  try {
    const filter = { patient: req.params.patientId };
    if (req.user.role === 'doctor') {
      filter.doctor = req.user.id;
    } else if (req.user.role === 'admin') {
      const adminClinicIds = await getAdminClinicIds(req.user.id);
      if (adminClinicIds.length === 0) return res.json([]);
      filter.$or = [
        { clinic: { $in: adminClinicIds } },
        { createdBy: req.user.id },
      ];
    }
    const plans = await TreatmentPlan.find(filter)
      .populate(populateFields)
      .sort({ createdAt: -1 });
    res.json(plans);
  } catch (error) {
    console.error('Ошибка загрузки планов лечения:', error);
    res.status(500).json({ message: 'Не удалось загрузить планы лечения.' });
  }
});

async function loadEditablePlan(req, res) {
  const plan = await TreatmentPlan.findById(req.params.id);
  if (!plan) {
    res.status(404).json({ message: 'План не найден.' });
    return null;
  }
  if (req.user.role === 'doctor' && !idsEqual(plan.doctor, req.user.id)) {
    res.status(403).json({ message: 'Можно изменять только свои планы.' });
    return null;
  }
  if (req.user.role === 'admin') {
    const adminClinicIds = await getAdminClinicIds(req.user.id);
    const allowed =
      (plan.clinic && adminClinicIds.includes(plan.clinic.toString())) ||
      idsEqual(plan.createdBy, req.user.id);
    if (!allowed) {
      res.status(403).json({ message: 'Нет доступа к этому плану.' });
      return null;
    }
  }
  return plan;
}

// PATCH /api/treatment-plans/:id — обновить план (название, статус, этапы)
router.patch('/:id', auth(['doctor', 'admin', 'superadmin']), async (req, res) => {
  try {
    const plan = await loadEditablePlan(req, res);
    if (!plan) return undefined;

    if (req.body.title !== undefined) plan.title = String(req.body.title).slice(0, 200);
    if (req.body.diagnosis !== undefined) plan.diagnosis = String(req.body.diagnosis).slice(0, 400);
    if (req.body.summary !== undefined) plan.summary = String(req.body.summary).slice(0, 600);
    if (['draft', 'active', 'completed', 'cancelled'].includes(req.body.status)) {
      plan.status = req.body.status;
    }
    if (Array.isArray(req.body.steps)) {
      plan.steps = req.body.steps.slice(0, 12).map((step, index) => ({
        order: index + 1,
        procedure: String(step.procedure || `Этап ${index + 1}`).slice(0, 200),
        description: String(step.description || '').slice(0, 600),
        durationDays: Number.isFinite(Number(step.durationDays)) ? Math.max(0, Math.round(Number(step.durationDays))) : 7,
        price: Number.isFinite(Number(step.price)) ? Math.max(0, Math.round(Number(step.price))) : 0,
        status: ['pending', 'in_progress', 'done'].includes(step.status) ? step.status : 'pending',
      }));
    }

    await plan.save();
    const populated = await TreatmentPlan.findById(plan._id).populate(populateFields);
    return res.json(populated);
  } catch (error) {
    console.error('Ошибка обновления плана лечения:', error);
    return res.status(500).json({ message: 'Не удалось обновить план лечения.' });
  }
});

// PATCH /api/treatment-plans/:id/steps/:stepId — обновить статус одного этапа
router.patch('/:id/steps/:stepId', auth(['doctor', 'admin', 'superadmin']), async (req, res) => {
  try {
    const plan = await loadEditablePlan(req, res);
    if (!plan) return undefined;

    const step = plan.steps.id(req.params.stepId);
    if (!step) {
      return res.status(404).json({ message: 'Этап не найден.' });
    }
    if (['pending', 'in_progress', 'done'].includes(req.body.status)) {
      step.status = req.body.status;
      step.completedAt = req.body.status === 'done' ? new Date() : undefined;
    }

    // Автозавершение плана, когда все этапы выполнены
    const allDone = plan.steps.length > 0 && plan.steps.every((s) => s.status === 'done');
    if (allDone && plan.status === 'active') {
      plan.status = 'completed';
    }

    await plan.save();
    const populated = await TreatmentPlan.findById(plan._id).populate(populateFields);
    return res.json(populated);
  } catch (error) {
    console.error('Ошибка обновления этапа:', error);
    return res.status(500).json({ message: 'Не удалось обновить этап.' });
  }
});

// DELETE /api/treatment-plans/:id
router.delete('/:id', auth(['doctor', 'admin', 'superadmin']), async (req, res) => {
  try {
    const plan = await loadEditablePlan(req, res);
    if (!plan) return undefined;
    await plan.deleteOne();
    return res.json({ success: true });
  } catch (error) {
    console.error('Ошибка удаления плана лечения:', error);
    return res.status(500).json({ message: 'Не удалось удалить план лечения.' });
  }
});

module.exports = router;
