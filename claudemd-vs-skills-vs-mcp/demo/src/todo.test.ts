import { describe, it, expect } from "vitest";
import { addTodo, removeTodo, completeTodo, listTodos } from "./todo";

describe("addTodo", () => {
  it("adds a todo to an empty list", () => {
    const result = addTodo([], "Buy milk");
    expect(result).toHaveLength(1);
    expect(result[0]).toEqual({ id: 1, text: "Buy milk", done: false });
  });

  it("assigns incrementing ids", () => {
    const list = addTodo(addTodo([], "First"), "Second");
    expect(list[1].id).toBe(2);
  });
});

describe("removeTodo", () => {
  it("removes a todo by id", () => {
    const list = addTodo(addTodo([], "Keep"), "Remove me");
    const result = removeTodo(list, 2);
    expect(result).toHaveLength(1);
    expect(result[0].text).toBe("Keep");
  });

  it("returns list unchanged for unknown id", () => {
    const list = addTodo([], "Stays");
    expect(removeTodo(list, 99)).toHaveLength(1);
  });
});

describe("completeTodo", () => {
  it("marks a todo as done", () => {
    const list = addTodo([], "Do the thing");
    const result = completeTodo(list, 1);
    expect(result[0].done).toBe(true);
  });
});

describe("listTodos", () => {
  it("returns placeholder for empty list", () => {
    expect(listTodos([])).toBe("No todos.");
  });

  it("formats todos with status", () => {
    const list = completeTodo(addTodo(addTodo([], "Done"), "Pending"), 1);
    const output = listTodos(list);
    expect(output).toContain("[x] 1. Done");
    expect(output).toContain("[ ] 2. Pending");
  });
});
