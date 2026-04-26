const crypto = require('crypto');
const multer = require('multer');
const cloudinaryStorage = require('multer-storage-cloudinary');
const path = require('path');
const cloudinary = require('../config/cloudinary');

const MAX_FILE_SIZE_BYTES = 10 * 1024 * 1024;
const ALLOWED_MIME_TYPES = new Set([
  'image/jpeg',
  'image/png',
  'image/webp',
  'image/heic',
  'image/heif',
  'application/pdf',
]);

class UploadValidationError extends Error {
  constructor(message, code = 'UPLOAD_VALIDATION_ERROR', statusCode = 400) {
    super(message);
    this.name = 'UploadValidationError';
    this.code = code;
    this.statusCode = statusCode;
  }
}

function buildSafePublicId(file) {
  const originalName = typeof file.originalname === 'string' ? file.originalname : 'file';
  const baseName = path.parse(path.basename(originalName)).name;
  const safeBaseName =
    baseName
      .normalize('NFKC')
      .replace(/[^a-zA-Z0-9_-]+/g, '_')
      .replace(/^_+|_+$/g, '')
      .slice(0, 32) || 'file';

  return `${Date.now()}-${crypto.randomBytes(8).toString('hex')}-${safeBaseName}`;
}

function buildUploadErrorResponse(error, maxCount) {
  if (error instanceof multer.MulterError) {
    switch (error.code) {
      case 'LIMIT_FILE_SIZE':
        return {
          status: 400,
          body: { message: 'Размер каждого файла не должен превышать 10 МБ.' },
        };
      case 'LIMIT_FILE_COUNT':
      case 'LIMIT_UNEXPECTED_FILE':
        return {
          status: 400,
          body: { message: `Можно загрузить не более ${maxCount} файлов.` },
        };
      case 'LIMIT_PART_COUNT':
      case 'LIMIT_FIELD_COUNT':
        return {
          status: 400,
          body: { message: 'Слишком много частей в multipart-запросе.' },
        };
      default:
        return {
          status: 400,
          body: { message: 'Некорректные данные загрузки файлов.' },
        };
    }
  }

  if (error instanceof UploadValidationError) {
    return {
      status: error.statusCode || 400,
      body: { message: error.message, code: error.code },
    };
  }

  return {
    status: 500,
    body: { message: 'Не удалось загрузить файлы.' },
  };
}

const storage = cloudinaryStorage({
  cloudinary,
  params: (req, file, cb) => {
    cb(null, {
      folder: 'rasul_dent_records',
      resource_type: 'auto',
      public_id: buildSafePublicId(file),
    });
  },
});

const upload = multer({
  storage,
  limits: {
    fileSize: MAX_FILE_SIZE_BYTES,
  },
  fileFilter: (req, file, cb) => {
    if (!ALLOWED_MIME_TYPES.has(file.mimetype)) {
      return cb(
        new UploadValidationError(
          'Поддерживаются только JPG, PNG, WEBP, HEIC, HEIF и PDF.',
          'UNSUPPORTED_FILE_TYPE',
        ),
      );
    }

    return cb(null, true);
  },
});

module.exports = {
  array(fieldName, maxCount) {
    const middleware = upload.array(fieldName, maxCount);

    return (req, res, next) => {
      middleware(req, res, (error) => {
        if (!error) {
          return next();
        }

        const { status, body } = buildUploadErrorResponse(error, maxCount);
        if (status >= 500) {
          console.error('Ошибка загрузки файлов:', error);
        }
        return res.status(status).json(body);
      });
    };
  },
};
