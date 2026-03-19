export interface Todo {
  id: number;
  text: string;
  done: boolean;
}

export type TodoList = Todo[];

export function addTodo(list: TodoList, text: string): TodoList {
  const id = list.length === 0 ? 1 : Math.max(...list.map((t) => t.id)) + 1;
  return [...list, { id, text, done: false }];
}

export function removeTodo(list: TodoList, id: number): TodoList {
  return list.filter((t) => t.id !== id);
}

export function completeTodo(list: TodoList, id: number): TodoList {
  return list.map((t) => (t.id === id ? { ...t, done: true } : t));
}

export function listTodos(list: TodoList): string {
  if (list.length === 0) return "No todos.";
  return list
    .map((t) => `[${t.done ? "x" : " "}] ${t.id}. ${t.text}`)
    .join("\n");
}

// CLI entry point
import * as readline from "readline";

const rl = readline.createInterface({ input: process.stdin, output: process.stdout });
let todos: TodoList = [];

function prompt(): void {
  rl.question("> ", (line) => {
    const [command, ...args] = line.trim().split(" ");
    if (command === "exit") {
      rl.close();
      return;
    } else if (command === "add") {
      todos = addTodo(todos, args.join(" "));
    } else if (command === "remove") {
      todos = removeTodo(todos, Number(args[0]));
    } else if (command === "complete") {
      todos = completeTodo(todos, Number(args[0]));
    } else if (command === "list" || command === "") {
      // just print below
    } else {
      console.log("Commands: add <text> | remove <id> | complete <id> | list | exit");
      return prompt();
    }
    console.log(listTodos(todos));
    prompt();
  });
}

console.log("Todo CLI — type 'exit' to quit");
prompt();
