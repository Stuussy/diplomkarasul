const mongoose = require('mongoose');

const scheduleSlotSchema = new mongoose.Schema(
  {
    doctor: { type: mongoose.Schema.Types.ObjectId, ref: 'User', required: true },
    clinic: { type: mongoose.Schema.Types.ObjectId, ref: 'Clinic', required: true },
    startTime: { type: Date, required: true },
    endTime: { type: Date, required: true },
    appointment: { type: mongoose.Schema.Types.ObjectId, ref: 'Appointment' },
    status: {
      type: String,
      enum: ['available', 'booked', 'blocked'],
      default: 'available',
    },
    createdBy: { type: mongoose.Schema.Types.ObjectId, ref: 'User' },
  },
  { timestamps: true },
);

scheduleSlotSchema.index({ doctor: 1, startTime: 1 }, { unique: true });

module.exports = mongoose.model('ScheduleSlot', scheduleSlotSchema);
