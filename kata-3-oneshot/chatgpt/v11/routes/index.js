
const express = require('express');
const router = express.Router();
const axios = require('axios');
const multer = require('multer');
const fs = require('fs');
const path = require('path');

const upload = multer({ dest: 'uploads/' });

router.get('/', (req, res) => {
  res.render('index', { response: null });
});

router.post('/send', upload.array('files'), async (req, res) => {
  const prompt = req.body.prompt;
  const apiKey = process.env.GEMINI_API_KEY;
  const files = req.files.map(file => ({
    path: file.path,
    originalname: file.originalname
  }));

  try {
    const response = await axios.post('https://generativelanguage.googleapis.com/v1beta/models/gemini-1.5-flash:generateContent', {
      contents: [{ parts: [{ text: prompt }] }]
    }, {
      headers: {
        'Content-Type': 'application/json',
        'Authorization': `Bearer ${apiKey}`
      }
    });

    // Clean up files
    files.forEach(file => fs.unlinkSync(file.path));
    res.render('index', { response: JSON.stringify(response.data, null, 2) });
  } catch (error) {
    console.error(error);
    res.render('index', { response: 'Error: ' + error.message });
  }
});

module.exports = router;
