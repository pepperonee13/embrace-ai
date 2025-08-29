async function fetchFileTree() {
  const res = await fetch('/api/files');
  const tree = await res.json();
  const container = document.getElementById('fileTree');
  container.innerHTML = '';
  renderTree(tree, '', container);
}

function renderTree(node, path, container) {
  for (const item of node) {
    const li = document.createElement('li');
    if (item.type === 'file') {
      li.innerHTML = '<label><input type="checkbox" data-path="' + path + '/' + item.name + '"> ' + item.name + '</label>';
    } else {
      li.innerHTML = '<details><summary>' + item.name + '</summary></details>';
      renderTree(item.children, path + '/' + item.name, li.querySelector('details'));
    }
    container.appendChild(li);
  }
}

document.getElementById('sendBtn').onclick = async () => {
  const prompt = document.getElementById('prompt').value;
  const files = [...document.querySelectorAll('input[type=checkbox]:checked')].map(cb => cb.dataset.path.replace(/^\//, ''));
  const res = await fetch('/api/send', {
    method: 'POST',
    headers: {'Content-Type': 'application/json'},
    body: JSON.stringify({ prompt, selectedFiles: files })
  });
  const data = await res.json();
  document.getElementById('responseBox').textContent = data.result;
};

document.getElementById('zipBtn').onclick = async () => {
  const files = [...document.querySelectorAll('input[type=checkbox]:checked')].map(cb => cb.dataset.path.replace(/^\//, ''));
  const res = await fetch('/api/zip', {
    method: 'POST',
    headers: {'Content-Type': 'application/json'},
    body: JSON.stringify({ selectedFiles: files })
  });
  const data = await res.json();
  window.open(data.url, '_blank');
};

fetchFileTree();
