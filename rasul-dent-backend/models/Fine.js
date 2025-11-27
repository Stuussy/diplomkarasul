const mongoose = require('mongoose');

const fineSchema = new mongoose.Schema(
  {
    patient: { type: mongoose.Schema.Types.ObjectId, ref: 'User', required: true },
    appointment: { type: mongoose.Schema.Types.ObjectId, ref: 'Appointment', required: true },
    amount: { type: Number, default: 3000 },
    reason: { type: String, default: 'Late cancellation' },
    issuedBy: { type: mongoose.Schema.Types.ObjectId, ref: 'User' },
    isPaid: { type: Boolean, default: false },
    paidAt: Date,
  },
  { timestamps: true },
);

module.exports = mongoose.model('Fine', fineSchema);
