Feature: DocumentAI Step Definitions
  # This file contains step definitions for the DocumentAI.feature file
  # It serves as a reference for implementing the actual step definitions in any language

  Background:
    Given a DocumentAI parser is available
    # Implementation: Initialize the DocumentAI parser/service

  # Document Input Steps
  Given a document with content:
    """
    <content>
    """
    # Implementation: Store the document content for parsing
    # Parameters: content (string)

  Given a contract document with:
    """
    <content>
    """
    # Implementation: Store contract document content
    # Parameters: content (string)

  Given a procedure document with:
    """
    <content>
    """
    # Implementation: Store procedure document content
    # Parameters: content (string)

  # Parsing Actions
  When I parse an empty document
    # Implementation: Call parser with empty string ""

  When I parse a document containing only whitespace
    # Implementation: Call parser with whitespace-only string (spaces, tabs, newlines)

  When I parse the document
    # Implementation: Call parser with the stored document content

  When I serialize it to JSON
    # Implementation: Convert the parsed document to JSON string

  When I deserialize it from JSON
    # Implementation: Parse the JSON string back to document object

  # Basic Structure Assertions
  Then I should get a block with kind "block"
    # Implementation: Assert result.Kind == "block"

  Then I should get a block with head "<head_text>"
    # Implementation: Assert result.Head == head_text
    # Parameters: head_text (string)

  Then I should get a block with kind "<kind>"
    # Implementation: Assert result.Kind == kind
    # Parameters: kind (string)

  Then the block should have no head
    # Implementation: Assert result.Head == null or result.Head == ""

  Then the block should have no number
    # Implementation: Assert result.Number == null or result.Number == ""

  Then the block should have an empty body
    # Implementation: Assert result.Body.Count == 0 or result.Body.Length == 0

  Then the block head should be "<head_text>"
    # Implementation: Assert result.Head == head_text
    # Parameters: head_text (string)

  # Body Content Assertions
  Then the block body should contain <count> text items
    # Implementation: Assert result.Body.Count == count && all items are text
    # Parameters: count (integer)

  Then the block body should contain <count> items
    # Implementation: Assert result.Body.Count == count
    # Parameters: count (integer)

  Then the first text item should be "<text>"
    # Implementation: Assert result.Body[0] is text with value == text
    # Parameters: text (string)

  Then the second text item should be "<text>"
    # Implementation: Assert result.Body[1] is text with value == text
    # Parameters: text (string)

  Then the first item should be text "<text>"
    # Implementation: Assert result.Body[0] is text with value == text
    # Parameters: text (string)

  Then the second item should be a block with head "<head_text>"
    # Implementation: Assert result.Body[1] is block with Head == head_text
    # Parameters: head_text (string)

  # Nested Structure Assertions
  Then the nested block body should contain <count> text item "<text>"
    # Implementation: Assert nested block has count items and first is text
    # Parameters: count (integer), text (string)

  Then the nested block should contain a dictionary with <count> items
    # Implementation: Assert nested block contains dictionary with count items
    # Parameters: count (integer)

  # Dictionary Assertions
  Then I should get a dictionary with <count> item
    # Implementation: Assert result contains dictionary with count items
    # Parameters: count (integer)

  Then I should get a dictionary with <count> items
    # Implementation: Assert result contains dictionary with count items
    # Parameters: count (integer)

  Then the dictionary should have key "<key>" with value "<value>"
    # Implementation: Assert dictionary.Items[key] == value
    # Parameters: key (string), value (string)

  # List Assertions
  Then I should get a list with <count> item
    # Implementation: Assert result contains list with count items
    # Parameters: count (integer)

  Then I should get a list with <count> items
    # Implementation: Assert result contains list with count items
    # Parameters: count (integer)

  Then the list item should have number "<number>"
    # Implementation: Assert list.Items[0].Number == number
    # Parameters: number (string)

  Then the list item should have no number
    # Implementation: Assert list.Items[0].Number == null

  Then the list item should contain text "<text>"
    # Implementation: Assert list.Items[0].Body contains text
    # Parameters: text (string)

  Then all list items should have no number
    # Implementation: Assert all items in list have Number == null

  Then the first item should have number "<number>" and text "<text>"
    # Implementation: Assert list.Items[0].Number == number && body contains text
    # Parameters: number (string), text (string)

  Then the second item should have number "<number>" and text "<text>"
    # Implementation: Assert list.Items[1].Number == number && body contains text
    # Parameters: number (string), text (string)

  Then the third item should have number "<number>" and text "<text>"
    # Implementation: Assert list.Items[2].Number == number && body contains text
    # Parameters: number (string), text (string)

  Then the fourth item should have number "<number>" and text "<text>"
    # Implementation: Assert list.Items[3].Number == number && body contains text
    # Parameters: number (string), text (string)

  Then the fifth item should have number "<number>" and text "<text>"
    # Implementation: Assert list.Items[4].Number == number && body contains text
    # Parameters: number (string), text (string)

  Then the first item should contain text "<text>"
    # Implementation: Assert list.Items[0].Body contains text
    # Parameters: text (string)

  Then the second item should contain text "<text>"
    # Implementation: Assert list.Items[1].Body contains text
    # Parameters: text (string)

  Then the third item should contain text "<text>"
    # Implementation: Assert list.Items[2].Body contains text
    # Parameters: text (string)

  # Nested List/Dictionary Assertions
  Then the first item should have number "<number>"
    # Implementation: Assert list.Items[0].Number == number
    # Parameters: number (string)

  Then the first item should contain a dictionary with <count> items
    # Implementation: Assert list.Items[0].Body contains dictionary with count items
    # Parameters: count (integer)

  Then the second item should have number "<number>"
    # Implementation: Assert list.Items[1].Number == number
    # Parameters: number (string)

  Then the second item should contain text "<text>"
    # Implementation: Assert list.Items[1].Body contains text
    # Parameters: text (string)

  Then the third item should be a list with <count> items
    # Implementation: Assert result.Body[2] is list with count items
    # Parameters: count (integer)

  Then the fourth item should be text "<text>"
    # Implementation: Assert result.Body[3] is text with value == text
    # Parameters: text (string)

  # JSON Serialization Assertions
  Then the JSON should contain "<json_fragment>"
    # Implementation: Assert JSON string contains the fragment
    # Parameters: json_fragment (string)

  # Round-trip Assertions
  Then the deserialized document should equal the original parsed document
    # Implementation: Assert deserialized object equals original object

  Then the head should be "<head_text>"
    # Implementation: Assert deserialized.Head == head_text
    # Parameters: head_text (string)

  Then the body should contain the same number of items
    # Implementation: Assert deserialized.Body.Count == original.Body.Count

  Then the dictionary should contain the same key-value pairs
    # Implementation: Assert all dictionary items are preserved

  # Error Handling Assertions
  Then I should get a valid block structure
    # Implementation: Assert result is valid block object

  Then malformed tags should be treated as text content
    # Implementation: Assert malformed markup becomes text content

  # Complex Document Assertions
  Then I should get a well-structured contract document
    # Implementation: Assert document has expected contract structure

  Then the contract should have head "<head_text>"
    # Implementation: Assert contract.Head == head_text
    # Parameters: head_text (string)

  Then the contract should contain a dictionary with license details
    # Implementation: Assert document contains dictionary with license info

  Then the contract should contain a grant of license block
    # Implementation: Assert document contains block with grant details

  Then the contract should contain a list with permitted uses and restrictions
    # Implementation: Assert document contains list with usage rules

  Then the restrictions should include a nested unordered list
    # Implementation: Assert restrictions contain nested bullet list

  Then I should get a well-structured procedure document
    # Implementation: Assert document has expected procedure structure

  Then the procedure should have head "<head_text>"
    # Implementation: Assert procedure.Head == head_text
    # Parameters: head_text (string)

  Then the procedure should contain metadata dictionary with dash separator
    # Implementation: Assert document contains dictionary with "-" separator

  Then the procedure should contain a list with onboarding phases
    # Implementation: Assert document contains list with phases

  Then the phases should include nested dictionaries and lists
    # Implementation: Assert phases contain nested structures

  Then the day one activities should contain an unordered list
    # Implementation: Assert day one section contains bullet list

  # Helper Methods for Implementation
  # These are utility methods that implementations might need:

  # ParseDocument(content: string) -> Block
  # ToJson(block: Block) -> string
  # FromJson(json: string) -> Block
  # AssertTextContent(node: ContentNode, expectedText: string)
  # AssertBlockContent(node: ContentNode, expectedHead: string)
  # AssertDictionaryContent(node: ContentNode, expectedItems: map)
  # AssertListContent(node: ContentNode, expectedItemCount: int)
  # FindDictionaryInBody(body: ContentNode[]) -> Dictionary
  # FindListInBody(body: ContentNode[]) -> ListBlock
  # FindBlockInBody(body: ContentNode[]) -> Block