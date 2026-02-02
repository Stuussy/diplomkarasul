const mongoose = require('mongoose');

const messageSchema = new mongoose.Schema(
  {
    patient: { type: mongoose.Schema.Types.ObjectId, ref: 'User', required: true },
    sender: { type: mongoose.Schema.Types.ObjectId, ref: 'User', required: true },
    assignedTo: { type: mongoose.Schema.Types.ObjectId, ref: 'User' },
    channel: {
      type: String,
      enum: ['support', 'notification'],
      default: 'support',
    },
    content: { type: String, required: true },
    attachments: [
      {
        url: String,
        cloudinaryId: String,
        format: String,
      },
    ],
    status: {
      type: String,
      enum: ['open', 'in_progress', 'resolved'],
      default: 'open',
    },
    history: [
      {
        sender: { type: mongoose.Schema.Types.ObjectId, ref: 'User' },
        content: String,
        createdAt: { type: Date, default: Date.now },
      },
    ],
    lastMessageAt: { type: Date, default: Date.now },
  },
  { timestamps: true },
);

module.exports = mongoose.model('Message', messageSchema);
