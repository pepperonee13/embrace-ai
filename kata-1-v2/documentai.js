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
    
    // Handle <block> tags
    if (line === '<block>') {
      const blockContent = extractTag(lines, i, 'block');
      body.push(parseBlock(blockContent.content));
      i = blockContent.endIndex;
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

function extractTag(lines, startIndex, tagName) {
  let content = [];
  let nestedCount = 0;
  
  for (let i = startIndex + 1; i < lines.length; i++) {
    const line = lines[i];
    
    // Check for nested opening tags
    if (line.includes(`<${tagName}`)) {
      nestedCount++;
    }
    
    if (line === `</${tagName}>`) {
      if (nestedCount > 0) {
        nestedCount--;
      } else {
        return { content: content.join('\n'), endIndex: i + 1 };
      }
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
  
  let i = 0;
  while (i < lines.length) {
    const line = lines[i];
    let itemMatch = null;
    
    if (kind === '.') {
      itemMatch = line.match(/^(\d+(?:\.\d+)*\.)\s*(.*)$/);
    } else if (kind === '*') {
      itemMatch = line.match(/^([•o*])\s*(.*)$/);
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
      i++;
    } else {
      // Check for nested content (tags or text)
      const dictMatch = line.match(/^<dict sep="([^"]+)">$/);
      const listMatch = line.match(/^<list kind="([^"]+)">$/);
      
      if (dictMatch) {
        const dictContent = extractTagFromLines(lines, i, 'dict');
        currentItemContent.push(parseDict(dictContent.content, dictMatch[1]));
        i = dictContent.endIndex;
      } else if (listMatch) {
        const listContent = extractTagFromLines(lines, i, 'list');
        currentItemContent.push(parseList(listContent.content, listMatch[1]));
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
    // Check if this is a mixed list scenario
    if (hasMixedContent(list)) {
      return nestMixedOrderedList(list);
    } else {
      return nestOrderedList(list);
    }
  } else if (kind === '*') {
    return nestBulletedList(list);
  }
  
  return list;
}

function extractTagFromLines(lines, startIndex, tagName) {
  let content = [];
  let nestedCount = 0;
  
  for (let i = startIndex + 1; i < lines.length; i++) {
    const line = lines[i];
    
    // Check for nested opening tags
    if (line.includes(`<${tagName}`)) {
      nestedCount++;
    }
    
    if (line === `</${tagName}>`) {
      if (nestedCount > 0) {
        nestedCount--;
      } else {
        return { content: content.join('\n'), endIndex: i + 1 };
      }
    }
    
    content.push(line);
  }
  
  return { content: content.join('\n'), endIndex: lines.length };
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

function nestOrderedList(list) {
  const result = { kind: "list", items: [] };
  
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

function hasMixedContent(list) {
  // Check if the list contains items with nested list content
  return list.items.some(item => 
    item.body && item.body.some(bodyItem => 
      typeof bodyItem === 'object' && bodyItem.kind === 'list'
    )
  );
}

function nestMixedOrderedList(list) {
  const result = { kind: "list", items: [] };
  
  // Find the item with nested list content
  let parentItem = null;
  let nestedListContent = null;
  
  for (const item of list.items) {
    const itemDepth = (item.number.match(/\./g) || []).length;
    
    if (itemDepth === 1) {
      // This is a potential parent for nested content
      parentItem = item;
      result.items.push(item);
    } else if (itemDepth === 2) {
      // Check if this sub-item has nested list content that should be moved to parent
      if (item.body && item.body.some(b => b.kind === 'list')) {
        nestedListContent = item.body.filter(b => b.kind === 'list');
        // Move nested list to the most recent depth-1 parent
        if (parentItem && !parentItem.body) {
          parentItem.body = [];
        }
        if (parentItem) {
          parentItem.body.push(...nestedListContent);
        }
        // Remove nested list from sub-item and add sub-item as top-level
        item.body = item.body.filter(b => b.kind !== 'list');
        if (item.body.length === 0) {
          delete item.body;
        }
      }
      // Add sub-item as top-level item
      result.items.push(item);
    }
  }
  
  return result;
}

module.exports = { parse };