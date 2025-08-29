
import React, { useState } from 'react';

export default function FileTree({ node, selected, onToggle }) {
  const [expanded, setExpanded] = useState(false);

  const toggle = () => setExpanded(!expanded);

  if (node.type === 'folder') {
    return (
      <div style={{ marginLeft: 10 }}>
        <div onClick={toggle} style={{ cursor: 'pointer' }}>
          {expanded ? '📂' : '📁'} {node.name}
        </div>
        {expanded &&
          node.children &&
          node.children.map((child) => (
            <FileTree
              key={child.path}
              node={child}
              selected={selected}
              onToggle={onToggle}
            />
          ))}
      </div>
    );
  } else {
    return (
      <div style={{ marginLeft: 20 }}>
        <label>
          <input
            type="checkbox"
            checked={selected.includes(node.path)}
            onChange={() => onToggle(node.path)}
          />
          📄 {node.name}
        </label>
      </div>
    );
  }
}
