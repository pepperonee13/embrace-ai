Please implement a WebUI tool that can send a request to OpenAI/Gemini/LLM of your choice, while appending contents of files into the prompt. You should be able to pick the files that you want to append.

## Requirements:

- Tool is passed a directory as argument on startup (e.g. `node server.js ../../projects/demo-project`)
- When loading, it will list all files (recursively) in the left pane
- When user clicks on the file - it is added to the right pane
- If user clicks on the file in the right pane - it is removed
- When user types a prompt and clicks on “Submit”, then text of these files is appended to the prompt and sent to LLM. 
- Response from LLM is streamed back.


## NOT Requirements:

- multi-turn chat conversations or follow-up questions.
- any persistence. Reloading the page can loose all information.

![example-ui](example-ui.png)