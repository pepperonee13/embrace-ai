function parse(input) {
  if (input === "") {
    return { kind: "block" };
  }
  
  return parseBlock(input);
}

function parseBlock(input) {
  const lines = input.split('\n').filter(line => line.trim() !== '');
  const result = { kind: "block" };
  const body = [];
  
  let i = 0;
  while (i < lines.length) {
    const line = lines[i];
    
    // Handle <head> tags
    const headMatch = line.match(/^<head>(.*?)<\/head>$/);
    if (headMatch) {
      result.head = headMatch[1];
      i++;
      continue;
    }
    
    // Handle <block> tags
    if (line === '<block>') {
      const blockContent = extractBlock(lines, i);
      body.push(parseBlock(blockContent.content));
      i = blockContent.endIndex;
      continue;
    }
    
    // Handle <dict> tags
    const dictMatch = line.match(/^<dict sep="([^"]+)">$/);
    if (dictMatch) {
      const dictContent = extractTag(lines, i, 'dict');
      body.push(parseDict(dictContent.content, dictMatch[1]));
      i = dictContent.endIndex;
      continue;
    }
    
    // Handle <list> tags
    const listMatch = line.match(/^<list kind="([^"]+)">$/);
    if (listMatch) {
      const listContent = extractTag(lines, i, 'list');
      body.push(parseList(listContent.content, listMatch[1]));
      i = listContent.endIndex;
      continue;
    }
    
    // Regular text content
    body.push(line);
    i++;
  }
  
  if (body.length > 0) {
    result.body = body;
  }
  
  return result;
}

function extractBlock(lines, startIndex) {
  let depth = 0;
  let content = [];
  
  for (let i = startIndex + 1; i < lines.length; i++) {
    const line = lines[i];
    
    if (line === '<block>') {
      depth++;
    } else if (line === '</block>') {
      if (depth === 0) {
        return { content: content.join('\n'), endIndex: i + 1 };
      }
      depth--;
    }
    
    content.push(line);
  }
  
  return { content: content.join('\n'), endIndex: lines.length };
}

function extractTag(lines, startIndex, tagName) {
  let depth = 0;
  let content = [];
  
  for (let i = startIndex + 1; i < lines.length; i++) {
    const line = lines[i];
    
    if (line.startsWith(`<${tagName}`)) {
      depth++;
    } else if (line === `</${tagName}>`) {
      if (depth === 0) {
        return { content: content.join('\n'), endIndex: i + 1 };
      }
      depth--;
    }
    
    content.push(line);
  }
  
  return { content: content.join('\n'), endIndex: lines.length };
}

function parseDict(content, separator) {
  const dict = { kind: "dict", items: {} };
  const lines = content.split('\n').filter(line => line.trim() !== '');
  
  for (const line of lines) {
    const separatorIndex = line.indexOf(separator);
    if (separatorIndex !== -1) {
      const key = line.substring(0, separatorIndex).trim();
      const value = line.substring(separatorIndex + separator.length).trim();
      dict.items[key] = value;
    }
  }
  
  return dict;
}

function parseList(content, kind) {
  const list = { kind: "list", items: [] };
  const lines = content.split('\n').filter(line => line.trim() !== '');
  
  let currentItem = null;
  let currentItemContent = [];
  let lastTopLevelItem = null; // Track the last top-level item for mixed content
  
  let i = 0;
  while (i < lines.length) {
    const line = lines[i];
    let itemMatch = null;
    
    if (kind === '.') {
      itemMatch = line.match(/^(\d+(?:\.\d+)*\.)\s*(.*)$/);
    } else if (kind === '*') {
      itemMatch = line.match(/^([•o\*])\s*(.*)$/);
    }
    
    if (itemMatch) {
      // Save previous item if exists
      if (currentItem) {
        if (currentItemContent.length > 0) {
          const bodyContent = processMixedContent(currentItemContent);
          if (bodyContent.length > 0) {
            currentItem.body = bodyContent;
          }
        }
        list.items.push(currentItem);
      }
      
      // Start new item
      currentItem = {
        kind: "block",
        number: itemMatch[1],
        head: itemMatch[2].trim()
      };
      currentItemContent = [];
      
      // Track if this is a top-level item (single digit + dot)
      if (kind === '.' && itemMatch[1].match(/^\d+\.$/)) {
        lastTopLevelItem = currentItem;
      }
      
      i++;
    } else {
      // Check for nested lists or other tags
      const dictMatch = line.match(/^<dict sep="([^"]+)">$/);
      const listMatch = line.match(/^<list kind="([^"]+)">$/);
      
      if (dictMatch) {
        const dictContent = extractTagFromLines(lines, i, 'dict');
        // For mixed content, attach to the last top-level item if available
        if (kind === '.' && lastTopLevelItem && !currentItem) {
          if (!lastTopLevelItem.body) lastTopLevelItem.body = [];
          lastTopLevelItem.body.push(parseDict(dictContent.content, dictMatch[1]));
        } else {
          currentItemContent.push(parseDict(dictContent.content, dictMatch[1]));
        }
        i = dictContent.endIndex;
      } else if (listMatch) {
        const listContent = extractTagFromLines(lines, i, 'list');
        // For mixed content, attach to the last top-level item if no current item body content
        if (kind === '.' && lastTopLevelItem && currentItemContent.length === 0) {
          if (!lastTopLevelItem.body) lastTopLevelItem.body = [];
          lastTopLevelItem.body.push(parseList(listContent.content, listMatch[1]));
        } else {
          currentItemContent.push(parseList(listContent.content, listMatch[1]));
        }
        i = listContent.endIndex;
      } else {
        currentItemContent.push(line);
        i++;
      }
    }
  }
  
  // Add the last item
  if (currentItem) {
    if (currentItemContent.length > 0) {
      const bodyContent = processMixedContent(currentItemContent);
      if (bodyContent.length > 0) {
        currentItem.body = bodyContent;
      }
    }
    list.items.push(currentItem);
  }
  
  // Now handle nesting for ordered lists
  if (kind === '.') {
    return nestOrderedList(list);
  } else if (kind === '*') {
    return nestBulletedList(list);
  }
  
  return list;
}

function processMixedContent(content) {
  const result = [];
  let textLines = [];
  
  for (const item of content) {
    if (typeof item === 'string') {
      textLines.push(item);
    } else {
      // Object (dict, list, etc.)
      if (textLines.length > 0) {
        result.push(...textLines);
        textLines = [];
      }
      result.push(item);
    }
  }
  
  // Add any remaining text lines
  if (textLines.length > 0) {
    result.push(...textLines);
  }
  
  return result;
}

function extractTagFromLines(lines, startIndex, tagName) {
  let depth = 0;
  let content = [];
  
  for (let i = startIndex + 1; i < lines.length; i++) {
    const line = lines[i];
    
    if (line.startsWith(`<${tagName}`)) {
      depth++;
    } else if (line === `</${tagName}>`) {
      if (depth === 0) {
        return { content: content.join('\n'), endIndex: i + 1 };
      }
      depth--;
    }
    
    content.push(line);
  }
  
  return { content: content.join('\n'), endIndex: lines.length };
}

function parseContent(content) {
  if (!content || content.trim() === '') {
    return [];
  }
  
  if (typeof content === 'object') {
    return [content];
  }
  
  const lines = content.split('\n').filter(line => line.trim() !== '');
  const result = [];
  
  let i = 0;
  while (i < lines.length) {
    const line = lines[i];
    
    // Handle <dict> tags
    const dictMatch = line.match(/^<dict sep="([^"]+)">$/);
    if (dictMatch) {
      const dictContent = extractTagFromLines(lines, i, 'dict');
      result.push(parseDict(dictContent.content, dictMatch[1]));
      i = dictContent.endIndex;
      continue;
    }
    
    // Handle <list> tags
    const listMatch = line.match(/^<list kind="([^"]+)">$/);
    if (listMatch) {
      const listContent = extractTagFromLines(lines, i, 'list');
      result.push(parseList(listContent.content, listMatch[1]));
      i = listContent.endIndex;
      continue;
    }
    
    // Handle <block> tags
    if (line === '<block>') {
      const blockContent = extractBlockFromLines(lines, i);
      result.push(parseBlock(blockContent.content));
      i = blockContent.endIndex;
      continue;
    }
    
    // Regular text content
    result.push(line);
    i++;
  }
  
  return result;
}

function extractBlockFromLines(lines, startIndex) {
  let depth = 0;
  let content = [];
  
  for (let i = startIndex + 1; i < lines.length; i++) {
    const line = lines[i];
    
    if (line === '<block>') {
      depth++;
    } else if (line === '</block>') {
      if (depth === 0) {
        return { content: content.join('\n'), endIndex: i + 1 };
      }
      depth--;
    }
    
    content.push(line);
  }
  
  return { content: content.join('\n'), endIndex: lines.length };
}

function nestOrderedList(list) {
  const result = { kind: "list", items: [] };
  
  // Check if any item has embedded content (mixed lists)
  const hasMixedContent = list.items.some(item => 
    item.body && item.body.some(bodyItem => typeof bodyItem === 'object' && bodyItem.kind === 'list')
  );
  
  if (hasMixedContent) {
    // For mixed content, don't nest based on numbering
    for (const item of list.items) {
      result.items.push(item);
    }
    return result;
  }
  
  // Regular nesting logic for pure ordered lists
  for (let i = 0; i < list.items.length; i++) {
    const item = list.items[i];
    const itemDepth = (item.number.match(/\./g) || []).length;
    
    if (itemDepth === 1) {
      // Top level item
      result.items.push(item);
      
      // Look for nested items
      const nestedItems = [];
      let j = i + 1;
      while (j < list.items.length) {
        const nextItem = list.items[j];
        const nextDepth = (nextItem.number.match(/\./g) || []).length;
        
        if (nextDepth === 1) {
          break; // Found next top-level item
        }
        
        if (nextDepth === 2) {
          nestedItems.push(nextItem);
        }
        j++;
      }
      
      if (nestedItems.length > 0) {
        if (!item.body) {
          item.body = [];
        }
        item.body.push({ kind: "list", items: nestedItems });
      }
      
      i = j - 1; // Skip the nested items we just processed
    }
  }
  
  return result;
}


function nestBulletedList(list) {
  const result = { kind: "list", items: [] };
  
  for (let i = 0; i < list.items.length; i++) {
    const item = list.items[i];
    
    if (item.number === '•') {
      // Main bullet item
      result.items.push(item);
      
      // Look for nested items (o bullets)
      const nestedItems = [];
      let j = i + 1;
      while (j < list.items.length && list.items[j].number === 'o') {
        nestedItems.push(list.items[j]);
        j++;
      }
      
      if (nestedItems.length > 0) {
        if (!item.body) {
          item.body = [];
        }
        item.body.push({ kind: "list", items: nestedItems });
      }
      
      i = j - 1; // Skip the nested items we just processed
    } else if (item.number === '*') {
      // Asterisk bullet (treat as main level)
      result.items.push(item);
    }
  }
  
  return result;
}

module.exports = { parse };