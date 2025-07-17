using TimeToActDocumentAI;

namespace TimeToActDocumentAI.Example;

class Program
{
    static void Main(string[] args)
    {
        Console.WriteLine("TimeToAct DocumentAI Example");
        Console.WriteLine("============================");
        
        // Example 1: Simple contract with head and dictionary
        var contractExample = """
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
            Subject to the terms and conditions of this Agreement, Licensor grants Licensee a non-exclusive, non-transferable license.
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
            """;
        
        Console.WriteLine("\n1. Contract Example:");
        Console.WriteLine("Input:");
        Console.WriteLine(contractExample);
        
        var contractResult = DocumentAI.ParseDocument(contractExample);
        var contractJson = DocumentAI.ToJson(contractResult);
        
        Console.WriteLine("\nParsed JSON:");
        Console.WriteLine(contractJson);
        
        // Example 2: Procedure document
        var procedureExample = """
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
            
            1.1. Send welcome email to new employee
            1.2. Prepare workspace and equipment
            1.3. Schedule orientation sessions
            
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
            """;
        
        Console.WriteLine("\n\n2. Procedure Example:");
        Console.WriteLine("Input:");
        Console.WriteLine(procedureExample);
        
        var procedureResult = DocumentAI.ParseDocument(procedureExample);
        var procedureJson = DocumentAI.ToJson(procedureResult);
        
        Console.WriteLine("\nParsed JSON:");
        Console.WriteLine(procedureJson);
        
        // Example 3: Simple text document
        var simpleExample = """
            Welcome to our company!
            
            We're excited to have you join our team.
            Please review the attached documents.
            """;
        
        Console.WriteLine("\n\n3. Simple Text Example:");
        Console.WriteLine("Input:");
        Console.WriteLine(simpleExample);
        
        var simpleResult = DocumentAI.ParseDocument(simpleExample);
        var simpleJson = DocumentAI.ToJson(simpleResult);
        
        Console.WriteLine("\nParsed JSON:");
        Console.WriteLine(simpleJson);
        
        // Demonstrate round-trip serialization
        Console.WriteLine("\n\n4. Round-trip Test:");
        var roundTripResult = DocumentAI.FromJson(contractJson);
        Console.WriteLine("Original and deserialized objects are equal: " + 
                         (contractResult.Head == roundTripResult.Head && 
                          contractResult.Body.Count == roundTripResult.Body.Count));
    }
}