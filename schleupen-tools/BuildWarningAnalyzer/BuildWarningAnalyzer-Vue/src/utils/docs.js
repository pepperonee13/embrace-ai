const knownDocLinks = {
  CS0436: "https://learn.microsoft.com/en-us/dotnet/csharp/misc/cs0436",
  CS8618: "https://learn.microsoft.com/en-us/dotnet/csharp/language-reference/compiler-messages/nullable-warnings",
  CS8602: "https://learn.microsoft.com/en-us/dotnet/csharp/language-reference/compiler-messages/nullable-warnings",
}

export function getDocsUrl(code) {
  if (knownDocLinks[code]) {
    return knownDocLinks[code]
  }

  if (code.startsWith("CA")) {
    return `https://learn.microsoft.com/en-us/dotnet/fundamentals/code-analysis/quality-rules/${code}`
  }

  if (code.startsWith("SA")) {
    return `https://github.com/DotNetAnalyzers/StyleCopAnalyzers/blob/master/documentation/${code}.md`
  }

  if (code && code !== "Uncoded" && code !== "Unknown") {
    return `https://www.bing.com/search?q=${encodeURIComponent(code + ' site:learn.microsoft.com')}`
  }

  return null
}
