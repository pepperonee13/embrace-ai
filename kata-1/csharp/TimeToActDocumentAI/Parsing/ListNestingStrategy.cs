using TimeToActDocumentAI.Models;

namespace TimeToActDocumentAI.Parsing;

/// <summary>
/// Domain service that encapsulates complex list nesting behavior using DDD principles.
/// Handles the business logic for determining when and how list items should be nested.
/// </summary>
public static class ListNestingStrategy
{
    /// <summary>
    /// Represents the result of a nesting decision operation.
    /// </summary>
    public readonly struct NestingDecision
    {
        public bool ShouldNest { get; }
        public Block? ParentItem { get; }
        public int ParentIndex { get; }

        private NestingDecision(bool shouldNest, Block? parentItem, int parentIndex)
        {
            ShouldNest = shouldNest;
            ParentItem = parentItem;
            ParentIndex = parentIndex;
        }

        public static NestingDecision DontNest() => new(false, null, -1);
        public static NestingDecision NestUnder(Block parentItem, int parentIndex) => 
            new(true, parentItem, parentIndex);
    }

    /// <summary>
    /// Determines if a list item should be nested under a previous item based on domain rules.
    /// </summary>
    /// <param name="currentItem">The item being processed</param>
    /// <param name="existingItems">The list of items already processed</param>
    /// <param name="hasExplicitNestedLists">Whether explicit nested list tags are present</param>
    /// <returns>A nesting decision indicating whether and where to nest the item</returns>
    public static NestingDecision ShouldNestItem(Block currentItem, List<Block> existingItems, bool hasExplicitNestedLists)
    {
        if (existingItems.Count == 0 || currentItem.Number == null)
            return NestingDecision.DontNest();

        // In mixed list contexts with explicit nested lists, disable automatic nesting for numbered items
        if (hasExplicitNestedLists)
            return NestingDecision.DontNest();

        var lastItem = existingItems[^1];
        if (lastItem.Number == null)
            return NestingDecision.DontNest();

        // Apply domain-specific nesting rules
        if (ShouldNestNumberedItem(currentItem, lastItem))
            return NestingDecision.NestUnder(lastItem, existingItems.Count - 1);

        if (ShouldNestBulletItem(currentItem, lastItem))
            return NestingDecision.NestUnder(lastItem, existingItems.Count - 1);

        return NestingDecision.DontNest();
    }

    /// <summary>
    /// Creates or retrieves a nested list within a parent item using immutable patterns.
    /// </summary>
    /// <param name="parentItem">The parent item to contain the nested list</param>
    /// <returns>A tuple containing the nested list and the updated parent item</returns>
    public static (ListBlock nestedList, Block updatedParent) GetOrCreateNestedList(Block parentItem)
    {
        // Check if parent already has a nested list
        if (parentItem.Body?.LastOrDefault() is ListBlock existingList)
        {
            return (existingList, parentItem);
        }

        // Create new nested list using immutable pattern
        var nestedList = new ListBlock();
        var newBody = new List<ContentNode>(parentItem.Body ?? []) { nestedList };
        var updatedParent = parentItem with { Body = newBody };

        return (nestedList, updatedParent);
    }

    /// <summary>
    /// Finds the appropriate parent item for a nested list in mixed list scenarios.
    /// </summary>
    /// <param name="items">The list of items to search</param>
    /// <returns>The item that should serve as the parent for the nested list</returns>
    public static Block FindAppropriateParentForNestedList(List<Block> items)
    {
        if (items.Count == 0)
            throw new InvalidOperationException("Cannot find parent in empty list");

        var lastItem = items[^1];

        // If the last item is a numbered sub-item (like 2.1.), 
        // look for its logical parent (like 2.)
        if (lastItem.Number != null && lastItem.Number.Contains('.'))
        {
            var lastParts = lastItem.Number.TrimEnd('.').Split('.');
            if (lastParts.Length > 1)
            {
                // Look for a parent item (e.g., "2." for "2.1.")
                var parentNumber = lastParts[0] + ".";
                for (int i = items.Count - 2; i >= 0; i--)
                {
                    if (items[i].Number == parentNumber)
                    {
                        return items[i];
                    }
                }
            }
        }

        // Default to last item if no appropriate parent found
        return lastItem;
    }

    private static bool ShouldNestNumberedItem(Block currentItem, Block lastItem)
    {
        // For numbered lists, check if current number is a sub-number of the last item
        if (!currentItem.Number!.Contains('.') || !lastItem.Number!.Contains('.'))
            return false;

        var currentParts = currentItem.Number.TrimEnd('.').Split('.');
        var lastParts = lastItem.Number.TrimEnd('.').Split('.');

        // Check if current item is a sub-item (e.g., 2.1 under 2, or 2.1.3 under 2.1)
        if (currentParts.Length <= lastParts.Length)
            return false;

        // Check if the prefix matches
        for (int i = 0; i < lastParts.Length; i++)
        {
            if (currentParts[i] != lastParts[i])
                return false;
        }

        return true;
    }

    private static bool ShouldNestBulletItem(Block currentItem, Block lastItem)
    {
        // For bullet lists, check if current bullet is different from last (indicating nesting)
        if (currentItem.Number!.Contains('.') || lastItem.Number!.Contains('.'))
            return false;

        return currentItem.Number != lastItem.Number;
    }
}