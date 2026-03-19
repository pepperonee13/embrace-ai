const API_KEY = 'your_API_KEY';
const MODEL = 'gemini-1.5-flash'; // or 'gemini-pro-vision' if you want to support images

const promptInput = document.getElementById('prompt');
const fileInput = document.getElementById('fileInput');
const sendBtn = document.getElementById('sendBtn');
const responseBox = document.getElementById('response');

sendBtn.addEventListener('click', async () => {
  const prompt = promptInput.value.trim();
  const files = fileInput.files;

  if (!prompt && files.length === 0) {
    alert('Please enter a prompt or select a file.');
    return;
  }

  const endpoint = `https://generativelanguage.googleapis.com/v1beta/models/${MODEL}:generateContent?key=${API_KEY}`;

  const requestBody = {
    contents: [{
      parts: [
        { text: prompt }
      ]
    }]
  };

  if (files.length > 0) {
    const file = files[0];
    const base64 = await toBase64(file);
    requestBody.contents[0].parts.push({
      inlineData: {
        mimeType: file.type,
        data: base64.split(',')[1]
      }
    });
  }

  try {
    responseBox.textContent = 'Loading...';
    const res = await fetch(endpoint, {
      method: 'POST',
      headers: { 'Content-Type': 'application/json' },
      body: JSON.stringify(requestBody)
    });

    const data = await res.json();
    if (data.candidates) {
      responseBox.textContent = data.candidates[0].content.parts.map(p => p.text).join('');
    } else {
      responseBox.textContent = JSON.stringify(data, null, 2);
    }
  } catch (err) {
    responseBox.textContent = 'Error: ' + err.message;
  }
});

function toBase64(file) {
  return new Promise((resolve, reject) => {
    const reader = new FileReader();
    reader.onload = () => resolve(reader.result);
    reader.onerror = reject;
    reader.readAsDataURL(file);
  });
}
