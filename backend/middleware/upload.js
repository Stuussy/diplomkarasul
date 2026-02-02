const multer = require('multer');
const cloudinaryStorage = require('multer-storage-cloudinary');
const cloudinary = require('../config/cloudinary');

const storage = cloudinaryStorage({
  cloudinary,
  params: (req, file, cb) => {
    const safeName = `${Date.now()}-${file.originalname}`.replace(/\s+/g, '_');
    cb(null, {
      folder: 'rasul_dent_records',
      resource_type: 'auto',
      public_id: safeName,
    });
  },
});

module.exports = multer({ storage });
