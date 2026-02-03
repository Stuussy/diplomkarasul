const express = require('express');

const router = express.Router();

router.use('/auth', require('./auth'));
router.use('/users', require('./users'));
router.use('/clinics', require('./clinics'));
router.use('/appointments', require('./appointments'));
router.use('/records', require('./records'));
router.use('/support', require('./support'));
router.use('/fines', require('./fines'));
router.use('/notifications', require('./notifications'));
router.use('/stats', require('./stats'));
router.use('/profile', require('./profile'));
router.use('/reviews', require('./reviews'));
router.use('/', require('./integrations'));
router.use('/', require('./health'));

module.exports = router;
