using System;
using System.Collections.Generic;
using Microsoft.Build.Framework;
using Microsoft.Build.Logging.StructuredLogger;

class Program
{
    static int Main(string[] args)
    {
        if (args.Length == 0)
        {
            Console.Error.WriteLine("Usage: BinlogWarningExtractor <path-to-binlog>");
            return 1;
        }

        var binlogPath = args[0];

        if (!System.IO.File.Exists(binlogPath))
        {
            Console.Error.WriteLine($"Binlog not found: {binlogPath}");
            return 1;
        }

        // This is the correct API
        Build build = BinaryLog.ReadBuild(binlogPath);

        // Aggregate warnings by code and text
        var warningGroups = new Dictionary<string, (string Text, int Count)>();
        var warnings = new List<object>();

        build.VisitAllChildren<Warning>(node =>
        {
            warnings.Add(new {
                Code = node.Code,
                Text = node.Text,
                Title = node.Title,
                File = node.File,
            });
            if (string.IsNullOrEmpty(node.Code))
            {
                return; // Skip warnings with no code
            }

            var code = node.Code;
            var text = node.Text;

            if (!warningGroups.ContainsKey(code))
            {
                warningGroups[code] = (text, 0);
            }
            warningGroups[code] = (text, warningGroups[code].Count + 1);
        });

        Console.WriteLine("\nAggregated Warning Summary:");
        var warningList = new List<object>();
        foreach (var group in warningGroups
            .OrderByDescending(g => g.Value.Count) // Sort by count descending
            .ThenBy(g => g.Key)) // Then by code alphabetically
        {
            Console.WriteLine($"Code: {group.Key}, Count: {group.Value.Count}, Text: {group.Value.Text}");
            warningList.Add(new { Code = group.Key, Count = group.Value.Count, Text = group.Value.Text });
        }

        // Write the warnings to a JSON file
        var jsonOutputPath = Path.Combine(Path.GetDirectoryName(binlogPath), $"{Path.GetFileNameWithoutExtension(binlogPath)}.json");
        System.IO.File.WriteAllText(jsonOutputPath, System.Text.Json.JsonSerializer.Serialize(warnings, new System.Text.Json.JsonSerializerOptions { WriteIndented = true }));
        Console.WriteLine($"\nWarnings written to {jsonOutputPath}");

        return 0;
    }
}
