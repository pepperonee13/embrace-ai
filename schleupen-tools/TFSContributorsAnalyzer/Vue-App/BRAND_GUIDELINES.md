# Brand Guidelines - Button Classes

This document describes the standardized button classes available for use across the application. These classes ensure consistent branding using the TIMETOACT color palette.

## Available Button Classes

All button classes are defined in `style.css` using Tailwind's `@layer components` directive.

### Base Button Classes

#### Primary Button - Brand Blue
```html
<button class="btn-brand-primary">Click Me</button>
```
- **Color**: `#225EA9` (Brand Blue)
- **Hover**: `#054A80` (Brand Blue Dark)
- **Use for**: Main actions, primary CTAs

#### Secondary Button - Brand Teal
```html
<button class="btn-brand-secondary">Click Me</button>
```
- **Color**: `#088F9B` (Brand Teal)
- **Hover**: `#006B75` (Brand Teal Dark)
- **Use for**: Secondary actions, add operations

#### Accent Button - Brand Orange
```html
<button class="btn-brand-accent">Click Me</button>
```
- **Color**: `#F08223` (Brand Orange)
- **Hover**: `#D47113` (Brand Orange Dark)
- **Use for**: Highlighted actions, feature additions

#### Neutral Button - Gray
```html
<button class="btn-brand-neutral">Click Me</button>
```
- **Color**: Gray 500
- **Hover**: Gray 600
- **Use for**: Reset, cancel, neutral actions

#### Danger Button - Red
```html
<button class="btn-brand-danger">Delete</button>
```
- **Color**: Red 600
- **Hover**: Red 700
- **Use for**: Destructive actions, deletions

#### Success Button - Teal
```html
<button class="btn-brand-success">Save</button>
```
- **Color**: Teal 600
- **Hover**: Teal 700
- **Use for**: Success actions, confirmations, saves

### Size Modifiers

Combine base classes with size modifiers:

#### Small
```html
<button class="btn-brand-secondary btn-brand-sm">Small Button</button>
```
- Padding: `px-3 py-1.5`
- Font size: Small

#### Large
```html
<button class="btn-brand-primary btn-brand-lg">Large Button</button>
```
- Padding: `px-6 py-3`
- Font size: Large

#### Icon-Only
```html
<button class="btn-brand-danger btn-brand-icon">×</button>
```
- Size: `w-8 h-8`
- Padding: 0
- Centered content

## Usage Examples

### Admin View Buttons

```html
<!-- Team management -->
<button class="btn-brand-accent w-full py-3 text-lg">➕ Add New Team</button>
<button class="btn-brand-danger">🗑️ Remove Team</button>
<button class="btn-brand-secondary btn-brand-sm">Add Author</button>
<button class="btn-brand-danger btn-brand-icon">×</button>

<!-- Action bar -->
<button class="btn-brand-neutral">↺ Reset Changes</button>
<button class="btn-brand-primary">💾 Download All</button>
<button class="btn-brand-success">✓ Save All Changes</button>
```

### Combining with Utility Classes

You can combine brand button classes with Tailwind utility classes:

```html
<!-- Full width button -->
<button class="btn-brand-primary w-full">Full Width</button>

<!-- Custom padding -->
<button class="btn-brand-secondary py-3 text-lg">Custom Size</button>

<!-- Disabled state (automatically styled) -->
<button class="btn-brand-success" :disabled="saving">
  {{ saving ? 'Saving...' : 'Save' }}
</button>
```

## Color Palette Reference

### Brand Colors (from tailwind.config.js)

- **Brand Blue**: `#225EA9` (Primary)
  - Light: `#1E5EA8`
  - Dark: `#054A80`

- **Brand Teal**: `#088F9B` (Secondary)
  - Dark: `#006B75`

- **Brand Orange**: `#F08223` (Accent)
  - Dark: `#D47113`

- **Brand Gray**: `#2F3944` (Text/Headers)

### When to Use Each Color

1. **Blue (Primary)**: Main actions, navigation, primary features
2. **Teal (Secondary)**: Supporting actions, additions, success states
3. **Orange (Accent)**: Highlights, special features, calls-to-action
4. **Gray (Neutral)**: Reset, cancel, non-committal actions
5. **Red (Danger)**: Delete, remove, destructive operations

## Best Practices

1. **Consistency**: Always use these brand classes instead of inline colors
2. **Hierarchy**: Use primary for main actions, secondary for supporting actions
3. **Color Meaning**: Maintain semantic color meanings (red = danger, teal = success)
4. **Accessibility**: All button classes include focus states and proper contrast ratios
5. **Disabled States**: Disabled states are automatically handled for all brand buttons

## Adding New Button Variants

If you need to add new button variants, add them to `style.css` within the `@layer components` block:

```css
@layer components {
  .btn-brand-custom {
    @apply px-4 py-2 rounded-lg font-semibold transition-all duration-200;
    @apply bg-custom-color text-white hover:bg-custom-color-dark;
    @apply shadow-sm hover:shadow-md;
  }
}
```

## Migration Guide

To update existing buttons to use brand classes:

1. Replace `bg-blue-500` → `btn-brand-primary`
2. Replace `bg-green-500` → `btn-brand-success` or `btn-brand-accent`
3. Replace `bg-red-500` → `btn-brand-danger`
4. Replace `bg-gray-500` → `btn-brand-neutral`
5. Remove manual hover states (handled by brand classes)
6. Remove manual shadow classes (handled by brand classes)
