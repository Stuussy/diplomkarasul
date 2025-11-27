const dayjs = require('dayjs');

function buildAppointmentWindows(startTime, durationMinutes = 30) {
  const start = dayjs(startTime);
  return {
    confirmWindow: {
      start: start.subtract(30, 'minute').toDate(),
      end: start.add(15, 'minute').toDate(),
    },
    cancelBefore: start.subtract(2, 'hour').toDate(),
    endTime: start.add(durationMinutes, 'minute').toDate(),
  };
}

module.exports = { buildAppointmentWindows };
