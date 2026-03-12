import { useState } from "react";
import { FileTree } from "./components/FileTree";
import { PromptInput } from "./components/PromptInput";

function App() {
  const [selectedFileContent, setSelectedFileContent] = useState("");
  const [response, setResponse] = useState("");

  return (
    <div className="flex h-screen">
      <FileTree onSelect={setSelectedFileContent} />
      <div className="flex flex-col flex-1 p-4">
        <PromptInput
          fileContext={selectedFileContent}
          onResponse={(r) => setResponse(r)}
        />
        <div className="mt-4 border p-2 rounded bg-gray-50 whitespace-pre-wrap">
          {response}
        </div>
      </div>
    </div>
  );
}

export default App;
