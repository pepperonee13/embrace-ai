
const fs = require('fs');
const path = require('path');

function exploreDirectory(dir) {
  const stats = fs.statSync(dir);
  if (!stats.isDirectory()) throw new Error('Not a directory');

  const result = {
    name: path.basename(dir),
    path: '',
    type: 'folder',
    children: [],
  };

  function walk(currentPath, relPath) {
    const entries = fs.readdirSync(currentPath);
    const children = [];

    for (const entry of entries) {
      const fullPath = path.join(currentPath, entry);
      const relativePath = path.join(relPath, entry);
      const stat = fs.statSync(fullPath);

      if (stat.isDirectory()) {
        children.push({
          name: entry,
          path: relativePath,
          type: 'folder',
          children: walk(fullPath, relativePath),
        });
      } else {
        children.push({
          name: entry,
          path: relativePath,
          type: 'file',
        });
      }
    }
    return children;
  }

  result.children = walk(dir, '');
  return result;
}

module.exports = { exploreDirectory };
