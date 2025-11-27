const express = require('express');
const Fine = require('../models/Fine');
const auth = require('../middleware/auth');

const router = express.Router();

router.get('/', auth(), async (req, res) => {
  const filter = {};
  if (req.user.role === 'patient') {
    filter.patient = req.user.id;
  } else if (req.query.patientId) {
    filter.patient = req.query.patientId;
  }

  const fines = await Fine.find(filter).populate('appointment');
  res.json(fines);
});

module.exports = router;
