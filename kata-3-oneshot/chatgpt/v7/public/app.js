async function loadTree() {
  const res = await fetch('/api/tree');
  const tree = await res.json();
  const container = document.getElementById('fileTree');
  container.appendChild(renderTree(tree));
}

function renderTree(nodes) {
  const ul = document.createElement('ul');
  for (const node of nodes) {
    const li = document.createElement('li');
    const label = document.createElement('label');
    if (!node.isDir) {
      const checkbox = document.createElement('input');
      checkbox.type = 'checkbox';
      checkbox.value = node.path;
      label.appendChild(checkbox);
    }
    label.appendChild(document.createTextNode(' ' + node.name));
    li.appendChild(label);
    if (node.children) li.appendChild(renderTree(node.children));
    ul.appendChild(li);
  }
  return ul;
}

async function sendPrompt() {
  const prompt = document.getElementById('prompt').value;
  const checked = [...document.querySelectorAll('input[type=checkbox]:checked')];
  const selectedFiles = checked.map(c => c.value);

  const res = await fetch('/api/send', {
    method: 'POST',
    headers: { 'Content-Type': 'application/json' },
    body: JSON.stringify({ prompt, selectedFiles })
  });
  const result = await res.json();
  document.getElementById('result').innerText = result.response || JSON.stringify(result);
}

loadTree();
