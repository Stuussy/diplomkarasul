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
    toothMap: [
      {
        arch: { type: String, enum: ['upper', 'lower'], required: true },
        index: { type: Number, min: 1, max: 14, required: true },
        status: {
          type: String,
          enum: ['healthy', 'treated', 'missing', 'issue'],
          required: true,
        },
        note: String,
      },
    ],
    createdBy: { type: mongoose.Schema.Types.ObjectId, ref: 'User' },
  },
  { timestamps: true },
);

module.exports = mongoose.model('MedicalRecord', medicalRecordSchema);
