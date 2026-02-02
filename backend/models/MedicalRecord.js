const mongoose = require('mongoose');

const medicalRecordSchema = new mongoose.Schema(
  {
    patient: { type: mongoose.Schema.Types.ObjectId, ref: 'User', required: true },
    doctor: { type: mongoose.Schema.Types.ObjectId, ref: 'User', required: true },
    appointment: { type: mongoose.Schema.Types.ObjectId, ref: 'Appointment' },
    title: { type: String, required: true },
    description: String,
    attachments: [
      {
        url: String,
        cloudinaryId: String,
        format: String,
      },
    ],
    tags: [{ type: String }],
    createdBy: { type: mongoose.Schema.Types.ObjectId, ref: 'User' },
  },
  { timestamps: true },
);

module.exports = mongoose.model('MedicalRecord', medicalRecordSchema);
