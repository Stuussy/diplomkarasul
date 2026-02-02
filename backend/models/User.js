const mongoose = require('mongoose');
const bcrypt = require('bcryptjs');

const roles = ['patient', 'doctor', 'admin', 'support_manager', 'superadmin'];

const userSchema = new mongoose.Schema(
  {
    firstName: { type: String, required: true },
    lastName: { type: String, required: true },
    email: { type: String, required: true, unique: true, lowercase: true },
    phone: { type: String },
    role: { type: String, enum: roles, default: 'patient' },
    passwordHash: { type: String, required: true },
    clinics: [{ type: mongoose.Schema.Types.ObjectId, ref: 'Clinic' }],
    specialties: [{ type: String }],
    services: [{ type: String }],
    experienceYears: { type: Number, default: 0 },
    bio: { type: String },
    rating: { type: Number, default: 4.8 },
    reviews: { type: Number, default: 0 },
    isActive: { type: Boolean, default: true },
    createdBy: { type: mongoose.Schema.Types.ObjectId, ref: 'User' },
    resetPasswordCodeHash: { type: String },
    resetPasswordExpires: { type: Date },
  },
  { timestamps: true },
);

userSchema.methods.comparePassword = function comparePassword(password) {
  return bcrypt.compare(password, this.passwordHash);
};

userSchema.statics.hashPassword = function hashPassword(password) {
  return bcrypt.hash(password, 10);
};

userSchema.methods.toJSON = function toJSON() {
  const obj = this.toObject();
  delete obj.passwordHash;
  return obj;
};

module.exports = mongoose.model('User', userSchema);
