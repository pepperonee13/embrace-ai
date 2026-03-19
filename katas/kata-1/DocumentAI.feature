Feature: TimeToAct DocumentAI Parser
  As a developer
  I want to parse structured business documents into JSON
  So that AI systems can process them effectively

  Background:
    Given a DocumentAI parser is available

  Scenario: Parse empty document
    When I parse an empty document
    Then I should get a block with kind "block"
    And the block should have no head
    And the block should have no number
    And the block should have an empty body

  Scenario: Parse document with only whitespace
    When I parse a document containing only whitespace
    Then I should get a block with kind "block"
    And the block should have an empty body

  Scenario: Parse plain text document
    Given a document with content:
      """
      First paragraph.
      Second paragraph.
      """
    When I parse the document
    Then I should get a block with kind "block"
    And the block body should contain 2 text items
    And the first text item should be "First paragraph."
    And the second text item should be "Second paragraph."

  Scenario: Parse document with head
    Given a document with content:
      """
      <head>Contract Title</head>
      This is the contract content.
      """
    When I parse the document
    Then I should get a block with kind "block"
    And the block head should be "Contract Title"
    And the block body should contain 1 text item
    And the first text item should be "This is the contract content."

  Scenario: Parse nested block structure
    Given a document with content:
      """
      <head>Master Agreement</head>
      Introduction text
      <block>
      <head>Terms and Conditions</head>
      Detailed terms here
      </block>
      """
    When I parse the document
    Then I should get a block with head "Master Agreement"
    And the block body should contain 2 items
    And the first item should be text "Introduction text"
    And the second item should be a block with head "Terms and Conditions"
    And the nested block body should contain 1 text item "Detailed terms here"

  Scenario Outline: Parse dictionary with different separators
    Given a document with content:
      """
      <dict sep="<separator>">
      <key><separator><value>
      </dict>
      """
    When I parse the document
    Then I should get a dictionary with 1 item
    And the dictionary should have key "<key>" with value "<value>"

    Examples:
      | separator | key     | value             |
      | :         | Party A | Acme Corporation  |
      | -         | Party A | Acme Corporation  |
      | =         | Party A | Acme Corporation  |
      | \|        | Party A | Acme Corporation  |
      | ->        | Party A | Acme Corporation  |

  Scenario: Parse dictionary with multiple items
    Given a document with content:
      """
      <dict sep=":">
      Party A: Acme Corporation
      Party B: Beta Industries
      Effective Date: 2024-01-01
      </dict>
      """
    When I parse the document
    Then I should get a dictionary with 3 items
    And the dictionary should have key "Party A" with value "Acme Corporation"
    And the dictionary should have key "Party B" with value "Beta Industries"
    And the dictionary should have key "Effective Date" with value "2024-01-01"

  Scenario: Parse dictionary with empty values
    Given a document with content:
      """
      <dict sep=":">
      Key1: Value1
      Key2: 
      EmptyKey:
      </dict>
      """
    When I parse the document
    Then I should get a dictionary with 3 items
    And the dictionary should have key "Key1" with value "Value1"
    And the dictionary should have key "Key2" with value ""
    And the dictionary should have key "EmptyKey" with value ""

  Scenario Outline: Parse ordered list with different number formats
    Given a document with content:
      """
      <list kind=".">
      <number> Test Item
      </list>
      """
    When I parse the document
    Then I should get a list with 1 item
    And the list item should have number "<number>"
    And the list item should contain text "Test Item"

    Examples:
      | number |
      | 1.     |
      | 2.1.   |
      | 10.    |
      | 1.2.3. |
      | 100.1. |

  Scenario: Parse ordered list with multiple items
    Given a document with content:
      """
      <list kind=".">
      1. Payment Terms
      2. Delivery Schedule
      2.1. Initial Delivery
      2.2. Final Delivery
      3. Warranties
      </list>
      """
    When I parse the document
    Then I should get a list with 5 items
    And the first item should have number "1." and text "Payment Terms"
    And the second item should have number "2." and text "Delivery Schedule"
    And the third item should have number "2.1." and text "Initial Delivery"
    And the fourth item should have number "2.2." and text "Final Delivery"
    And the fifth item should have number "3." and text "Warranties"

  Scenario Outline: Parse unordered list with different bullet types
    Given a document with content:
      """
      <list kind="*">
      <bullet> <item_text>
      </list>
      """
    When I parse the document
    Then I should get a list with 1 item
    And the list item should have no number
    And the list item should contain text "<item_text>"

    Examples:
      | bullet | item_text    |
      | •      | Bullet item  |
      | *      | Asterisk item|
      | -      | Dash item    |

  Scenario: Parse unordered list with multiple items
    Given a document with content:
      """
      <list kind="*">
      • Confidentiality Agreement
      • Non-Compete Clause
      • Intellectual Property Rights
      </list>
      """
    When I parse the document
    Then I should get a list with 3 items
    And all list items should have no number
    And the first item should contain text "Confidentiality Agreement"
    And the second item should contain text "Non-Compete Clause"
    And the third item should contain text "Intellectual Property Rights"

  Scenario: Parse list with nested dictionary
    Given a document with content:
      """
      <list kind=".">
      1. First item
      Some description text.
      <dict sep=":">
      Subelement: Value
      Another: Data
      </dict>
      2. Second item
      More text here.
      </list>
      """
    When I parse the document
    Then I should get a list with 2 items
    And the first item should have number "1."
    And the first item should contain a dictionary with 2 items
    And the dictionary should have key "Subelement" with value "Value"
    And the dictionary should have key "Another" with value "Data"
    And the second item should have number "2."
    And the second item should contain text "More text here."

  Scenario: Parse complex nested document structure
    Given a document with content:
      """
      <head>Complex Document</head>
      Introduction paragraph.
      
      <block>
      <head>Section 1</head>
      Section content with nested elements.
      <dict sep=":">
      Key1: Value1
      Key2: Value2
      </dict>
      </block>
      
      <list kind=".">
      1. First item
      2. Second item
      </list>
      
      Conclusion paragraph.
      """
    When I parse the document
    Then I should get a block with head "Complex Document"
    And the block body should contain 4 items
    And the first item should be text "Introduction paragraph."
    And the second item should be a block with head "Section 1"
    And the nested block should contain a dictionary with 2 items
    And the third item should be a list with 2 items
    And the fourth item should be text "Conclusion paragraph."

  Scenario Outline: Parse dictionary with multi-character separators
    Given a document with content:
      """
      <dict sep="<separator>">
      Key <separator> Value
      </dict>
      """
    When I parse the document
    Then I should get a dictionary with 1 item
    And the dictionary should have key "Key" with value "Value"

    Examples:
      | separator |
      | ::        |
      | -->       |
      | \|\|\|    |
      | ##        |

  Scenario: JSON serialization preserves structure
    Given a document with content:
      """
      <head>Test Document</head>
      Some text
      <dict sep=":">
      Key1: Value1
      Key2: Value2
      </dict>
      """
    When I parse the document
    And I serialize it to JSON
    Then the JSON should contain "\"head\": \"Test Document\""
    And the JSON should contain "\"kind\": \"block\""
    And the JSON should contain "\"kind\": \"dict\""
    And the JSON should contain "Some text"

  Scenario: Round-trip parsing preserves data
    Given a document with content:
      """
      <head>Software License Agreement</head>
      This agreement is entered into on the date last signed below.
      
      <dict sep=":">
      Licensor: TechCorp Inc.
      Licensee: ClientCo Ltd.
      </dict>
      """
    When I parse the document
    And I serialize it to JSON
    And I deserialize it from JSON
    Then the deserialized document should equal the original parsed document
    And the head should be "Software License Agreement"
    And the body should contain the same number of items
    And the dictionary should contain the same key-value pairs

  Scenario: Handle malformed input gracefully
    Given a document with content:
      """
      <head>Incomplete head tag
      Some text with <unclosed tag
      Normal text continues here.
      """
    When I parse the document
    Then I should get a valid block structure
    And malformed tags should be treated as text content

  Scenario: Parse contract document example
    Given a contract document with:
      """
      <head>Software License Agreement</head>
      This agreement is entered into on the date last signed below.
      
      <dict sep=":">
      Licensor: TechCorp Inc.
      Licensee: ClientCo Ltd.
      Effective Date: January 1, 2024
      License Type: Enterprise
      </dict>
      
      <block>
      <head>Grant of License</head>
      Subject to the terms and conditions of this Agreement.
      </block>
      
      <list kind=".">
      1. Permitted Uses
      Licensee may use the software for internal business purposes only.
      2. Restrictions
      Licensee shall not:
      <list kind="*">
      • Reverse engineer the software
      • Sublicense to third parties
      • Modify or create derivative works
      </list>
      3. Support and Maintenance
      Licensor will provide standard support during business hours.
      </list>
      """
    When I parse the document
    Then I should get a well-structured contract document
    And the contract should have head "Software License Agreement"
    And the contract should contain a dictionary with license details
    And the contract should contain a grant of license block
    And the contract should contain a list with permitted uses and restrictions
    And the restrictions should include a nested unordered list

  Scenario: Parse procedure document example
    Given a procedure document with:
      """
      <head>Employee Onboarding Procedure</head>
      This procedure outlines the steps for onboarding new employees.
      
      <dict sep="-">
      Document ID - HR-PROC-001
      Version - 2.1
      Last Updated - 2024-01-15
      Owner - Human Resources
      </dict>
      
      <list kind=".">
      1. Pre-boarding Phase
      <dict sep=":">
      Duration: 1 week before start date
      Responsible: HR Manager
      </dict>
      
      2. Day One Activities
      Complete the following on the employee's first day:
      <list kind="*">
      • ID badge creation
      • System access provisioning
      • Benefits enrollment
      • Safety training completion
      </list>
      
      3. First Week Tasks
      Monitor progress and provide support during the first week.
      </list>
      """
    When I parse the document
    Then I should get a well-structured procedure document
    And the procedure should have head "Employee Onboarding Procedure"
    And the procedure should contain metadata dictionary with dash separator
    And the procedure should contain a list with onboarding phases
    And the phases should include nested dictionaries and lists
    And the day one activities should contain an unordered list