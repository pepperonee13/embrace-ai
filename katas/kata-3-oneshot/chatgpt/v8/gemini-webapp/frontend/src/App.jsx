
import React, { useState, useEffect } from 'react';
import axios from 'axios';
import FileTree from './FileTree';

export default function App() {
  const [fileTree, setFileTree] = useState(null);
  const [selected, setSelected] = useState([]);
  const [prompt, setPrompt] = useState('');
  const [response, setResponse] = useState('');

  useEffect(() => {
    axios.get('http://localhost:4000/api/files').then((res) => {
      setFileTree(res.data);
    });
  }, []);

  const toggleFile = (path) => {
    setSelected((prev) =>
      prev.includes(path) ? prev.filter((p) => p !== path) : [...prev, path]
    );
  };

  const sendPrompt = async () => {
    const res = await axios.post('http://localhost:4000/api/send', {
      prompt,
      selectedFiles: selected,
    });
    setResponse(res.data.response);
  };

  return (
    <div style={{ display: 'flex', padding: '20px', fontFamily: 'Arial' }}>
      <div style={{ flex: 1 }}>
        <h3>📁 File Browser</h3>
        {fileTree && (
          <FileTree node={fileTree} selected={selected} onToggle={toggleFile} />
        )}
      </div>
      <div style={{ flex: 2, marginLeft: '40px' }}>
        <h3>📝 Prompt</h3>
        <textarea
          rows={8}
          style={{ width: '100%' }}
          value={prompt}
          onChange={(e) => setPrompt(e.target.value)}
        />
        <button onClick={sendPrompt}>🚀 Send to Gemini</button>
        <h4>📨 Response</h4>
        <pre style={{ whiteSpace: 'pre-wrap' }}>{response}</pre>
      </div>
    </div>
  );
}
