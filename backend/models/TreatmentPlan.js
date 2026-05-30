const mongoose = require('mongoose');

// Этап плана лечения
const treatmentStepSchema = new mongoose.Schema(
  {
    order: { type: Number, required: true },
    procedure: { type: String, required: true },
    description: { type: String, default: '' },
    durationDays: { type: Number, default: 7, min: 0 }, // сколько дней займёт/ждать до этапа
    price: { type: Number, default: 0, min: 0 },
    status: {
      type: String,
      enum: ['pending', 'in_progress', 'done'],
      default: 'pending',
    },
    completedAt: { type: Date },
  },
  { _id: true },
);

const treatmentPlanSchema = new mongoose.Schema(
  {
    patient: { type: mongoose.Schema.Types.ObjectId, ref: 'User', required: true },
    doctor: { type: mongoose.Schema.Types.ObjectId, ref: 'User', required: true },
    clinic: { type: mongoose.Schema.Types.ObjectId, ref: 'Clinic' },
    title: { type: String, required: true },
    diagnosis: { type: String, default: '' },
    summary: { type: String, default: '' }, // краткое резюме / рекомендации
    steps: [treatmentStepSchema],
    status: {
      type: String,
      enum: ['draft', 'active', 'completed', 'cancelled'],
      default: 'active',
    },
    aiGenerated: { type: Boolean, default: false },
    createdBy: { type: mongoose.Schema.Types.ObjectId, ref: 'User' },
  },
  { timestamps: true },
);

// Виртуальные поля: суммарная стоимость и оценочный срок (в днях)
treatmentPlanSchema.virtual('totalCost').get(function totalCost() {
  return (this.steps || []).reduce((sum, step) => sum + (step.price || 0), 0);
});

treatmentPlanSchema.virtual('totalDurationDays').get(function totalDurationDays() {
  return (this.steps || []).reduce((sum, step) => sum + (step.durationDays || 0), 0);
});

treatmentPlanSchema.virtual('progress').get(function progress() {
  const steps = this.steps || [];
  if (steps.length === 0) return 0;
  const done = steps.filter((step) => step.status === 'done').length;
  return Math.round((done / steps.length) * 100);
});

treatmentPlanSchema.set('toJSON', { virtuals: true });
treatmentPlanSchema.set('toObject', { virtuals: true });

module.exports = mongoose.model('TreatmentPlan', treatmentPlanSchema);
