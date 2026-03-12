import fs from 'fs';
import path from 'path';

export function getFileTree(basePath, relative = '') {
  const fullPath = path.join(basePath, relative);
  const entries = fs.readdirSync(fullPath, { withFileTypes: true });
  return entries.map(entry => {
    const relPath = path.join(relative, entry.name);
    if (entry.isDirectory()) {
      return {
        name: entry.name,
        type: 'directory',
        children: getFileTree(basePath, relPath)
      };
    } else {
      return {
        name: entry.name,
        type: 'file'
      };
    }
  });
}
