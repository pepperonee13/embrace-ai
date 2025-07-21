const fs = require('fs');
const { parse } = require('./documentai.js');

function runTestFile(filename) {
  const testData = JSON.parse(fs.readFileSync(`../test-data/${filename}`, 'utf8'));
  
  console.log(`\n=== ${testData.category} ===`);
  
  for (const testCase of testData.testCases) {
    try {
      const result = parse(testCase.input);
      const expected = testCase.expected;
      
      if (JSON.stringify(result) === JSON.stringify(expected)) {
        console.log(`✓ ${testCase.name}`);
      } else {
        console.log(`✗ ${testCase.name}`);
        console.log(`  Expected: ${JSON.stringify(expected)}`);
        console.log(`  Got:      ${JSON.stringify(result)}`);
      }
    } catch (error) {
      console.log(`✗ ${testCase.name}: ${error.message}`);
    }
  }
}

console.log('Running DocumentAI Tests against test data...');
runTestFile('basic-blocks.json');
runTestFile('dictionaries.json');
runTestFile('lists.json');
runTestFile('complex-scenarios.json');