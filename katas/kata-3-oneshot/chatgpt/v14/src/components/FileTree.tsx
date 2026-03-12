import { useState } from "react";

const sampleFiles = {
  "main.py": "print('Hello from main.py')",
  "utils/helpers.py": "def greet(name): return f'Hello {name}'",
};

export function FileTree({ onSelect }: { onSelect: (content: string) => void }) {
  const [selected, setSelected] = useState<string | null>(null);

  return (
    <div className="w-64 border-r p-2 overflow-y-auto">
      <h2 className="font-bold mb-2">File Tree</h2>
      <ul>
        {Object.entries(sampleFiles).map(([path, content]) => (
          <li
            key={path}
            onClick={() => {
              setSelected(path);
              onSelect(content);
            }}
            className={`cursor-pointer p-1 rounded ${selected === path ? "bg-blue-100" : ""}`}
          >
            {path}
          </li>
        ))}
      </ul>
    </div>
  );
}
