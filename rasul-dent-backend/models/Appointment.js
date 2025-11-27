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
    status: {
      type: String,
      enum: ['scheduled', 'confirmed', 'completed', 'cancelled', 'no_show'],
      default: 'scheduled',
    },
    confirmedAt: Date,
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
  },
  { timestamps: true },
);

// Экспортируем модель. 'Appointment' - это название модели, 
// Mongoose автоматически создаст коллекцию 'appointments' (во мн. числе)
module.exports = mongoose.model('Appointment', appointmentSchema);
