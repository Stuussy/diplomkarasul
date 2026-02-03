const Notification = require('../models/Notification');

async function createNotification(userId, payload) {
  if (!userId) return null;
  const { title, body, type = 'system', data } = payload;
  return Notification.create({
    user: userId,
    title,
    body,
    type,
    data,
  });
}

async function notifyMany(userIds, payload) {
  const unique = Array.from(new Set((userIds || []).filter(Boolean).map((id) => id.toString())));
  if (unique.length === 0) return [];
  const docs = unique.map((user) => ({
    user,
    title: payload.title,
    body: payload.body,
    type: payload.type ?? 'system',
    data: payload.data,
  }));
  return Notification.insertMany(docs);
}

module.exports = { createNotification, notifyMany };
