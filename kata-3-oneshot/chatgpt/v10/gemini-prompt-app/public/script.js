document.querySelectorAll('.folder').forEach(folder => {
    folder.addEventListener('click', () => {
        const ul = folder.nextElementSibling;
        if (ul && ul.style) {
            ul.style.display = ul.style.display === 'none' ? 'block' : 'none';
        }
    });
});

document.getElementById('promptForm').addEventListener('submit', async e => {
    e.preventDefault();
    const prompt = document.getElementById('prompt').value;
    const selectedFiles = Array.from(document.querySelectorAll('input[name="files"]:checked')).map(f => f.value);

    const res = await fetch('/send', {
        method: 'POST',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify({ prompt, selectedFiles })
    });

    const data = await res.json();
    if (data.result) {
        document.getElementById('result').textContent = data.result;
    } else {
        document.getElementById('result').textContent = 'Error: ' + data.error;
    }
});