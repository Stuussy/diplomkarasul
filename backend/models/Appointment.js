const mongoose = require('mongoose');

// Определяем схему (структуру) для документа "Запись на прием" в MongoDB
const appointmentSchema = new mongoose.Schema(
  {
    patient: { type: mongoose.Schema.Types.ObjectId, ref: 'User', required: true },
    doctor: { type: mongoose.Schema.Types.ObjectId, ref: 'User', required: true },
    clinic: { type: mongoose.Schema.Types.ObjectId, ref: 'Clinic', required: true },
    service: { type: String, required: true },
    startTime: { type: Date, required: true },
    durationMinutes: { type: Number, default: 30 },
    endTime: { type: Date },
    status: {
      type: String,
      enum: ['scheduled', 'confirmed', 'completed', 'cancelled', 'no_show'],
      default: 'scheduled',
    },
    confirmedAt: Date,
    completedAt: Date,
    completedBy: { type: mongoose.Schema.Types.ObjectId, ref: 'User' },
    noShowAt: Date,
    noShowMarkedBy: { type: mongoose.Schema.Types.ObjectId, ref: 'User' },
    notes: String,
    slot: { type: mongoose.Schema.Types.ObjectId, ref: 'ScheduleSlot' },
    confirmWindow: {
      start: Date,
      end: Date,
    },
    cancelBefore: Date,
    cancelledAt: Date,
    cancelledBy: { type: mongoose.Schema.Types.ObjectId, ref: 'User' },
    fineIssued: { type: Boolean, default: false },
    createdBy: { type: mongoose.Schema.Types.ObjectId, ref: 'User' },
    review: { type: mongoose.Schema.Types.ObjectId, ref: 'Review' },
    googleEventIdPatient: { type: String },
    googleEventIdDoctor: { type: String },
    googleSyncStatus: {
      type: String,
      enum: ['synced', 'partial', 'failed', 'skipped'],
      default: 'skipped',
    },
    googleSyncError: { type: String },
    googleSyncLastAttempt: { type: Date },
  },
  { timestamps: true },
);

// Экспортируем модель. 'Appointment' - это название модели, 
// Mongoose автоматически создаст коллекцию 'appointments' (во мн. числе)
module.exports = mongoose.model('Appointment', appointmentSchema);
