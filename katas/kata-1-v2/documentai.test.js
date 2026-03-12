const { parse } = require('./documentai.js');

function test(name, testFn) {
  try {
    testFn();
    console.log(`✓ ${name}`);
  } catch (error) {
    console.log(`✗ ${name}: ${error.message}`);
  }
}

function assertEqual(actual, expected) {
  if (JSON.stringify(actual) !== JSON.stringify(expected)) {
    throw new Error(`Expected ${JSON.stringify(expected)} but got ${JSON.stringify(actual)}`);
  }
}

// Test: Empty text results in empty document block
test("Empty text results in empty document block", () => {
  const result = parse("");
  assertEqual(result, { kind: "block" });
});

// Test: Plain text single paragraph
test("Plain text single paragraph", () => {
  const result = parse("First paragraph.");
  assertEqual(result, { 
    kind: "block", 
    body: ["First paragraph."] 
  });
});

// Test: Plain text multiple paragraphs
test("Plain text multiple paragraphs", () => {
  const result = parse("First paragraph.\nSecond paragraph.");
  assertEqual(result, { 
    kind: "block", 
    body: ["First paragraph.", "Second paragraph."] 
  });
});

// Test: Simple headed block
test("Simple headed block", () => {
  const result = parse("<head>Test Document</head>\nContent");
  assertEqual(result, {
    kind: "block",
    head: "Test Document",
    body: ["Content"]
  });
});

// Test: Simple dictionary
test("Simple dictionary", () => {
  const result = parse('<dict sep=":">\nKey One: Value One\nKey Two: Value Two\n</dict>');
  assertEqual(result, {
    kind: "block",
    body: [{
      kind: "dict",
      items: {
        "Key One": "Value One",
        "Key Two": "Value Two"
      }
    }]
  });
});

// Test: Simple ordered list
test("Simple ordered list", () => {
  const result = parse('<list kind=".">\n1. First\n2. Second\n</list>');
  assertEqual(result, {
    kind: "block",
    body: [{
      kind: "list",
      items: [
        { kind: "block", number: "1.", head: "First" },
        { kind: "block", number: "2.", head: "Second" }
      ]
    }]
  });
});

// Test: Simple bullet list
test("Simple bullet list", () => {
  const result = parse('<list kind="*">\n• First\n• Second\n• Third\n</list>');
  assertEqual(result, {
    kind: "block",
    body: [{
      kind: "list",
      items: [
        { kind: "block", number: "•", head: "First" },
        { kind: "block", number: "•", head: "Second" },
        { kind: "block", number: "•", head: "Third" }
      ]
    }]
  });
});

// Test: Nested block
test("Nested block", () => {
  const result = parse('<head>AI Coding Kata</head>\nLet\'s get started with the kata\n<block>\n<head>Preface</head>\nHere is a little story\n</block>');
  assertEqual(result, {
    kind: "block",
    head: "AI Coding Kata",
    body: [
      "Let's get started with the kata",
      {
        kind: "block",
        head: "Preface",
        body: [
          "Here is a little story"
        ]
      }
    ]
  });
});

console.log("Running DocumentAI Tests...");