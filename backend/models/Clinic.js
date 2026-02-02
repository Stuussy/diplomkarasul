const mongoose = require('mongoose');

const clinicSchema = new mongoose.Schema(
  {
    name: { type: String, required: true },
    description: String,
    city: String,
    address: String,
    contacts: {
      phone: String,
      email: String,
    },
    workingHours: [
      {
        day: { type: Number, min: 0, max: 6 },
        open: String,
        close: String,
        isClosed: { type: Boolean, default: false },
      },
    ],
    status: {
      type: String,
      enum: ['draft', 'inactive', 'active', 'blocked'],
      default: 'draft',
    },
    admin: { type: mongoose.Schema.Types.ObjectId, ref: 'User', required: true },
    taxiDeepLink: String,
    companyDetails: {
      bin: String,
      directorName: String,
      requisites: String,
    },
    services: [
      {
        name: { type: String, required: true },
        price: { type: Number, default: 0 },
        durationMinutes: { type: Number, default: 30 },
        description: String,
        isActive: { type: Boolean, default: true },
      },
    ],
    doctors: [{ type: mongoose.Schema.Types.ObjectId, ref: 'User' }],
    location: {
      type: {
        type: String,
        enum: ['Point'],
        default: 'Point',
      },
      coordinates: {
        type: [Number],
        default: [0, 0],
      },
    },
    qr: {
      payload: String,
      updatedBy: { type: mongoose.Schema.Types.ObjectId, ref: 'User' },
      updatedAt: Date,
    },
  },
  { timestamps: true },
);

clinicSchema.index({ location: '2dsphere' });

module.exports = mongoose.model('Clinic', clinicSchema);
