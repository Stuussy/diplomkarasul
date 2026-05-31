const mongoose = require('mongoose');

// История сообщений ИИ-консультации. Каждое сообщение (вопрос пользователя
// или ответ ассистента) хранится отдельной записью и привязано к пользователю.
const aiMessageSchema = new mongoose.Schema(
  {
    user: {
      type: mongoose.Schema.Types.ObjectId,
      ref: 'User',
      required: true,
      index: true,
    },
    role: {
      type: String,
      enum: ['user', 'assistant'],
      required: true,
    },
    content: { type: String, required: true },
  },
  { timestamps: true },
);

aiMessageSchema.index({ user: 1, createdAt: 1 });

module.exports = mongoose.model('AiMessage', aiMessageSchema);
