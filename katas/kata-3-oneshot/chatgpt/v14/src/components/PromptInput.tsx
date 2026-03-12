import { GoogleGenerativeAI } from "@google/generative-ai";
import { useState } from "react";

const genAI = new GoogleGenerativeAI(import.meta.env.VITE_GEMINI_API_KEY);

export function PromptInput({
  fileContext,
  onResponse,
}: {
  fileContext: string;
  onResponse: (res: string) => void;
}) {
  const [prompt, setPrompt] = useState("");

  const handleSubmit = async () => {
    const fullPrompt = `Given the following file content: ${fileContext} Answer this: ${prompt}`;
    const model = genAI.getGenerativeModel({ model: "gemini-pro" });
    const result = await model.generateContent(fullPrompt);
    const text = result.response.text();
    onResponse(text);
  };

  return (
    <div>
      <textarea
        className="w-full p-2 border rounded mb-2"
        rows={4}
        placeholder="Ask a question about the file..."
        value={prompt}
        onChange={(e) => setPrompt(e.target.value)}
      />
      <button
        className="bg-blue-600 text-white px-4 py-2 rounded"
        onClick={handleSubmit}
      >
        Send to Gemini
      </button>
    </div>
  );
}
