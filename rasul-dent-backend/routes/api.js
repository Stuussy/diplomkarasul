const express = require('express');

const router = express.Router();

router.use('/auth', require('./auth'));
router.use('/users', require('./users'));
router.use('/clinics', require('./clinics'));
router.use('/appointments', require('./appointments'));
router.use('/records', require('./records'));
router.use('/support', require('./support'));
router.use('/fines', require('./fines'));
router.use('/', require('./integrations'));

module.exports = router;
