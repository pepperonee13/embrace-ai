const fs = require('fs');
const path = require('path');
const { parse } = require('./documentai.js');

function runTestSuite(testFilePath) {
  console.log(`\nRunning tests from: ${testFilePath}`);
  
  try {
    const testFile = JSON.parse(fs.readFileSync(testFilePath, 'utf8'));
    const testData = testFile.testCases || testFile;
    let passed = 0;
    let failed = 0;
    
    for (const test of testData) {
      try {
        const result = parse(test.input);
        
        if (JSON.stringify(result) === JSON.stringify(test.expected)) {
          console.log(`✓ ${test.name}`);
          passed++;
        } else {
          console.log(`✗ ${test.name}`);
          console.log(`  Expected: ${JSON.stringify(test.expected)}`);
          console.log(`  Got:      ${JSON.stringify(result)}`);
          failed++;
        }
      } catch (error) {
        console.log(`✗ ${test.name}: ${error.message}`);
        failed++;
      }
    }
    
    console.log(`\nResults: ${passed} passed, ${failed} failed`);
    return { passed, failed };
  } catch (error) {
    console.log(`Error reading test file: ${error.message}`);
    return { passed: 0, failed: 1 };
  }
}

// Run all test suites
const testDataDir = path.join('..', 'kata-1', 'test-data');
const testFiles = [
  'basic-blocks.json',
  'dictionaries.json', 
  'lists.json',
  'complex-scenarios.json'
];

let totalPassed = 0;
let totalFailed = 0;

console.log('Running comprehensive test suite against official test data...');

for (const testFile of testFiles) {
  const testPath = path.join(testDataDir, testFile);
  if (fs.existsSync(testPath)) {
    const results = runTestSuite(testPath);
    totalPassed += results.passed;
    totalFailed += results.failed;
  } else {
    console.log(`\nTest file not found: ${testPath}`);
  }
}

console.log(`\n=== FINAL RESULTS ===`);
console.log(`Total: ${totalPassed} passed, ${totalFailed} failed`);

if (totalFailed === 0) {
  console.log('🎉 All tests passed!');
} else {
  console.log('❌ Some tests failed');
}