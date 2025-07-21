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

// Run tests
console.log("Running DocumentAI Tests...");