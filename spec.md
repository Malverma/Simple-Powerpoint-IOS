# SimpleSlides — Product & Technical Spec

**Platform:** iOS 17+ / iPadOS 17+ (universal)
**Stack:** Swift 5.10+, SwiftUI, SwiftData, PencilKit, AVFoundation, PDFKit
**Version:** 1.0 (MVP)
**Last updated:** 2026-10-05

---

## 1. Vision

A presentation maker that feels as easy as writing a note, but lets you design a slide down to the pixel when you want to.

**The one rule:** *simple by default, deep on demand.* Every screen shows only the essentials. Advanced controls exist, but they live one tap deeper (an "More" disclosure, a long-press, or an inspector tab) and never clutter the main canvas.

### 1.1 Goals
- Build a clean 5-slide deck in under 2 minutes with no tutorial.
- Give full control over every element's position, size, rotation, color, typography, effects, and animation.
- Present from the phone, AirPlay / external display, or export to PDF, images, video, and PowerPoint.
- Work fully offline. No account required.

### 1.2 Non-goals (v1)
- Real-time multi-user collaboration.
- Charts with live data, embedded spreadsheets.
- Android / web clients.
- Importing complex `.pptx` / `.key` files (export only in v1).

### 1.3 Target users
| Persona | Need |
|---|---|
| Student | Fast decks for class presentations, from the phone. |
| Small business owner | On-brand pitch decks with their own fonts and colors. |
| Designer / creator | Fine control over layout, effects, and motion; video export for social. |

---

## 2. Design Principles

1. **Canvas first.** The slide fills the screen. Chrome is minimal and translucent.
2. **Progressive disclosure.** Basic → Advanced → Expert. Defaults are good enough to never open Advanced.
3. **Direct manipulation.** Drag, pinch, rotate, and snap on the canvas. Inspector values update live and vice versa.
4. **Nothing is lost.** Unlimited undo/redo, autosave on every change, version snapshots.
5. **Native feel.** System gestures, SF Symbols, Dynamic Type in the UI, Dark Mode, haptics on snap.
6. **Consistency through themes.** Per-element overrides are always allowed, but theme changes propagate to anything not overridden.

---

## 3. Information Architecture

```
App
├── Library (home)
│   ├── Deck grid / list, search, sort, folders
│   └── New deck → Theme picker
├── Editor
│   ├── Canvas (current slide)
│   ├── Slide strip (thumbnails)
│   ├── Toolbar (Insert, Format, Play, More)
│   └── Inspector (sheet on iPhone, sidebar on iPad)
│       ├── Style   (fill, stroke, shadow, opacity, corner radius)
│       ├── Text    (font, size, spacing, alignment, lists)
│       ├── Arrange (position, size, rotation, layer order, align, lock)
│       └── Animate (build in / out, transition, timing)
├── Theme Editor
├── Presenter (play mode + presenter view)
└── Settings
```

---

## 4. Core Features

### 4.1 Library
- Grid of deck thumbnails (first slide), title, last edited date.
- Create, duplicate, rename, delete (with 30-day "Recently Deleted"), move to folder.
- Search by title and slide text.
- Sort: last edited, created, name.
- Share / export from context menu.

### 4.2 Creating a deck
1. Tap **+** → theme picker (8 built-in themes + user themes + "Blank").
2. Choose aspect ratio: **16:9** (default), 4:3, 1:1, 9:16 (stories), custom.
3. Deck opens with a Title slide, cursor in the title.

### 4.3 Slides
- Add slide (**+** at end of strip) using a layout:
  Title, Title + Body, Two Column, Image Full-bleed, Image + Caption, Quote, Section Header, Blank.
- Reorder by drag in strip; multi-select to move, duplicate, delete, skip.
- **Skip slide** flag (hidden during presentation).
- Per-slide background override (see §5.2).
- Speaker notes per slide (rich text).
- Slide-level transition (see §5.6).

### 4.4 Elements (insertable objects)
| Element | Basic | Deep customization |
|---|---|---|
| **Text box** | Type, pick style preset (Title / Heading / Body / Caption) | Any font (system + imported .ttf/.otf), weight, size, color/gradient fill, letter spacing, line height, paragraph spacing, alignment, vertical alignment, bullets/numbering (custom glyph, indent), text stroke, text shadow, uppercase/small caps, auto-fit vs. fixed size, columns (1–3), padding |
| **Image** | Insert from Photos / Files / Camera, drag to place | Crop (free / ratio / mask to shape), filters (brightness, contrast, saturation, exposure, temperature, blur), corner radius, border, shadow, opacity, blend mode, flip, replace image keeping style |
| **Shape** | Rectangle, rounded rect, circle, triangle, line, arrow, star, polygon | Fill (solid / linear / radial / angular gradient / image), stroke (width, color, dash pattern, cap, join), corner radius per corner, number of points/sides, star inner radius, arrow heads, text inside shape |
| **Icon** | Search SF Symbols | Rendering mode (mono, hierarchical, palette, multicolor), weight, per-layer colors |
| **Video / Audio** | Insert from Photos / Files | Trim, poster frame, autoplay, loop, mute, volume, play across slides (audio) |
| **Drawing** | PencilKit freehand | Converted to vector element; can recolor, resize, animate "draw on" |
| **Table** | Rows × cols picker | Cell fill, borders, padding, header row/column styling, per-cell text style |
| **Group** | Multi-select → Group | Groups behave as a single element; can be entered to edit children |

### 4.5 Canvas interaction
- **Tap** select, **double-tap** edit text / enter group, **long-press** context menu (Cut, Copy, Paste, Paste Style, Duplicate, Delete, Lock, Group, Bring to Front / Send to Back).
- **Drag** move; **handles** resize (Shift-equivalent: lock aspect toggle); **rotation handle** rotate (snap every 15° with haptic).
- **Two-finger pinch** zooms the canvas (not the element) 25%–400%.
- **Smart guides**: snap to slide center/edges, other elements' edges/centers, equal spacing. Toggle in More.
- Optional **grid** (configurable size) and **rulers** (iPad).
- **Nudge**: arrow keys with hardware keyboard (1pt; 10pt with ⇧).
- **Multi-select**: tap-and-hold then tap others, or marquee drag with two fingers on iPad.
- **Copy / Paste Style** between elements.

### 4.6 Undo / Redo
- Unlimited per-session via `UndoManager`; two-finger tap = undo, three-finger tap = redo, toolbar buttons, ⌘Z / ⇧⌘Z.

### 4.7 Presenting
- **Play** from the start or current slide.
- Swipe / tap to advance; builds play in order.
- **Presenter view** on external display / AirPlay: current + next slide, notes, timer, clock.
- **Laser pointer** (long-press) and **ink** annotation (temporary) while presenting.
- **Auto-play mode** with per-slide duration and loop (kiosk use).
- Respects Reduce Motion (cross-fades replace motion transitions).

### 4.8 Export & Share
| Format | Notes |
|---|---|
| `.simpleslides` | Native package (JSON + assets). Lossless re-import. |
| PDF | One page per slide; optional notes pages; respects skip flag. |
| Images | PNG / JPEG per slide, 1×/2×/3× scale. |
| Video | MP4 (H.264/HEVC), 720p/1080p/4K, includes transitions and builds, per-slide duration. |
| PowerPoint | `.pptx` best-effort (text, shapes, images; animations simplified). |

Share sheet integration; "Open In" supports importing `.simpleslides` files.

---

## 5. Deep Customization

### 5.1 Themes
A theme is a reusable design system for a deck.
- **Color palette:** 6 named slots (Background, Surface, Primary, Secondary, Accent, Text) + unlimited custom swatches.
- **Typography:** 4 text styles (Title, Heading, Body, Caption) each with font, weight, size, line height, letter spacing, color slot.
- **Master layouts:** each of the 8 layouts is editable — placeholder positions, sizes, styles.
- **Default backgrounds** per layout.
- **Default transition** and element defaults (shape fill, stroke, corner radius, shadow).
- Elements reference theme tokens (e.g. `color: .primary`) unless overridden; changing the theme re-styles the deck.
- Save any deck's theme as a user theme; import/export themes as `.sstheme`.

### 5.2 Backgrounds
Solid · Linear / radial / angular / mesh gradient (editable stops & angle) · Image (fill, fit, tile, blur, tint overlay) · Video (muted loop) · Pattern (dots, grid, lines; color and scale).

### 5.3 Color picker
- Theme swatches, recent colors, document colors.
- System color picker (HSB, RGB sliders, hex, eyedropper from canvas).
- Opacity on every color.
- Gradient editor: add/remove/drag stops, angle dial, type switcher.

### 5.4 Effects (all elements)
- Opacity, blend mode (normal, multiply, screen, overlay, etc.).
- Drop shadow: color, opacity, blur, x/y offset.
- Inner shadow, glow (shapes & text).
- Background blur (frosted glass) behind element.
- Border: width, color, dash, position (inside/center/outside).
- Corner radius (uniform or per corner).

### 5.5 Arrange
- Numeric X / Y / W / H / rotation fields (points, relative to slide).
- Lock aspect ratio, lock position (prevents accidental moves).
- Align: left, center, right, top, middle, bottom — to slide or to selection.
- Distribute horizontally / vertically.
- Layer order list (drag to reorder, show/hide, lock) — iPad sidebar, iPhone sheet.
- Flip horizontal / vertical.

### 5.6 Animation
**Slide transitions:** None, Fade, Push, Slide, Cover, Zoom, Dissolve, Flip, Cube, **Magic Move** (matches elements with same ID across consecutive slides and morphs position/size/rotation/color/opacity).
Options: duration (0.1–5s), direction, easing (linear, ease in/out, spring with bounce).

**Element builds:**
- Build In: Appear, Fade, Move In, Scale, Pop, Blur, Typewriter (text), Draw On (drawings/lines).
- Build Out: mirrors of above.
- Emphasis: Pulse, Shake, Spin, Bounce.
- Text granularity: all at once, by paragraph, by word, by character.
- Trigger: on tap, with previous, after previous (+ delay).
- **Build order list** — drag to reorder; preview button.

### 5.7 Custom fonts
Import `.ttf` / `.otf` via Files; registered with `CTFontManager` and embedded in the `.simpleslides` package so decks render identically on other devices.

---

## 6. UI Layout

### 6.1 iPhone (portrait)
```
┌──────────────────────────────┐
│ ‹ Decks     Untitled    ▶  ⋯ │  nav bar
├──────────────────────────────┤
│                              │
│        ┌────────────┐        │
│        │   SLIDE    │        │  canvas (fit to width)
│        └────────────┘        │
│                              │
├──────────────────────────────┤
│ [1][2][3][4] +               │  slide strip (horizontal)
├──────────────────────────────┤
│  ＋Insert   🖌Format   ↶  ↷   │  bottom toolbar
└──────────────────────────────┘
```
- **Format** opens the Inspector as a resizable sheet (medium / large detents). Canvas stays visible above medium detent.
- iPhone landscape: strip hides; canvas fills; toolbar floats.

### 6.2 iPad
- Slide strip in left sidebar (vertical), canvas center, Inspector right sidebar (collapsible).
- Full keyboard shortcuts and pointer hover states.
- Stage Manager / Split View supported.

### 6.3 Inspector structure (progressive disclosure)
Each tab shows the 3–5 most-used controls first, then a **"More"** disclosure group with the rest. Example — Text tab:
- **Visible:** style preset, font, size, color, alignment.
- **More:** weight, letter spacing, line height, paragraph spacing, lists, stroke, shadow, case, columns, padding, auto-fit.

---

## 7. Data Model

Persisted with **SwiftData**; assets stored as files in the app container and referenced by ID.

```swift
@Model final class Deck {
    var id: UUID
    var title: String
    var createdAt: Date
    var updatedAt: Date
    var aspectRatio: AspectRatio          // .wide16x9, .standard4x3, .square, .story9x16, .custom(w,h)
    var theme: Theme
    @Relationship(deleteRule: .cascade) var slides: [Slide]   // ordered by `index`
    var folder: Folder?
}

@Model final class Slide {
    var id: UUID
    var index: Int
    var layoutID: String
    var background: Fill?                 // nil → theme default
    var transition: Transition?           // nil → theme default
    var notes: AttributedString
    var isSkipped: Bool
    var autoAdvanceAfter: TimeInterval?
    var elements: [Element]               // z-order = array order (Codable)
    var builds: [Build]                   // ordered
}

struct Element: Codable, Identifiable {
    var id: UUID                          // stable across duplicated slides → Magic Move
    var kind: ElementKind                 // .text(TextContent) | .image(ImageContent) | .shape(ShapeContent) | .icon | .media | .drawing | .table | .group([Element])
    var frame: CGRect                     // in slide coordinates (slide = 1920×1080 for 16:9)
    var rotation: Angle
    var style: ElementStyle               // fill, stroke, shadow, opacity, blend, cornerRadii, effects
    var isLocked: Bool
    var isHidden: Bool
    var name: String?
}

enum Fill: Codable {
    case solid(ColorRef)
    case gradient(Gradient)               // type, stops[ColorRef, location], angle/center
    case image(assetID: UUID, mode: ImageFillMode, blur: Double, tint: ColorRef?)
    case video(assetID: UUID)
    case pattern(PatternKind, ColorRef, scale: Double)
}

enum ColorRef: Codable {
    case theme(ThemeColorSlot)            // resolves through Theme
    case custom(RGBA)
}

struct Theme: Codable {
    var id: UUID
    var name: String
    var palette: [ThemeColorSlot: RGBA]
    var swatches: [RGBA]
    var textStyles: [TextStyleKind: TextStyle]
    var layouts: [Layout]
    var defaultTransition: Transition
    var elementDefaults: ElementDefaults
}
```

**Coordinates:** each slide has a fixed logical size (e.g. 1920×1080). The canvas scales to fit the view; all stored values are resolution-independent.

**Native file format `.simpleslides`:** a package directory (`UTType` conforming to `com.apple.package`) containing `deck.json`, `assets/`, `fonts/`, `thumbnails/`.

---

## 8. Architecture

- **Pattern:** SwiftUI + `@Observable` view models; one `EditorModel` per open deck owns selection, undo, and mutations.
- **Rendering:** A single `SlideRenderer` SwiftUI view renders a slide from the model — reused by canvas, thumbnails, presenter, and export (`ImageRenderer` for PNG/PDF, `AVAssetWriter` for video).
- **Mutations:** all edits go through `EditorModel.apply(_ command: EditCommand)` which registers the inverse with `UndoManager` and marks the deck dirty → debounced autosave (500 ms).
- **Modules (folders):**
  - `App/` — entry, routing, settings
  - `Model/` — SwiftData models, Codable value types, theme resolution
  - `Library/` — deck list
  - `Editor/` — canvas, gestures, selection, smart guides, slide strip
  - `Inspector/` — Style, Text, Arrange, Animate tabs; color & gradient pickers
  - `Rendering/` — `SlideRenderer`, element views, effects
  - `Presenter/` — play mode, presenter view, external display scene
  - `Export/` — PDF, image, video, pptx, package
  - `Resources/` — built-in themes (JSON), layouts, sample assets

---

## 9. Accessibility

- VoiceOver labels for every control; canvas elements expose name + type + position ("Title text, top center").
- Element **alt text** field for images (exported to PDF tags).
- Dynamic Type for all app UI (slide content keeps its designed sizes).
- Contrast warning in Inspector when text/background contrast < 4.5:1.
- Reduce Motion honored in editor and presenter.
- Full keyboard navigation on iPad.

---

## 10. Performance Targets

| Metric | Target |
|---|---|
| Cold launch → Library | < 1.0 s |
| Open 50-slide deck | < 0.5 s |
| Canvas drag / resize | 60 fps (120 on ProMotion) |
| Thumbnail regeneration | async, < 50 ms per slide |
| Autosave | off main thread, never blocks UI |
| 1080p video export, 20 slides | < 30 s on A15 |

Images are downsampled to display size for editing; originals kept for export.

---

## 11. Settings

- Default aspect ratio and theme.
- Snapping, guides, grid size.
- Presenter: show timer, auto-advance default.
- Export defaults (quality, include notes, include skipped).
- iCloud sync on/off (v1.1).
- Haptics on/off.

---

## 12. Milestones

| Phase | Scope |
|---|---|
| **M1 — Foundation** | Data model, Library, create/open deck, slide strip, text + shape + image elements, move/resize/rotate, basic inspector, undo, autosave. |
| **M2 — Design depth** | Themes & theme editor, gradients, effects, smart guides, arrange tools, custom fonts, layouts. |
| **M3 — Present** | Play mode, transitions, builds, presenter view, external display. |
| **M4 — Export** | PDF, images, native package import/export, video. |
| **M5 — Polish** | Magic Move, tables, drawings, media, pptx export, accessibility audit, iPad keyboard shortcuts. |
| **v1.1** | iCloud sync, `.pptx` import, collaboration exploration. |

---

## 13. Acceptance Criteria (MVP)

- [ ] A new user can create, style, and present a 5-slide deck without help.
- [ ] Every element property listed in §4.4 and §5 is editable and undoable.
- [ ] Theme changes restyle all non-overridden elements across the deck.
- [ ] A deck exported as `.simpleslides` and re-imported is pixel-identical.
- [ ] PDF export matches the canvas rendering.
- [ ] No data loss on force-quit (autosave verified).
- [ ] VoiceOver can navigate Library, Editor, and Presenter.

---

## 14. Open Questions

1. Should Magic Move ship in v1 or move to v1.1 given complexity?
2. Bundle a curated free font set, or rely on system + imported fonts?
3. Monetization: free with paid theme packs, or one-time Pro unlock (video export, custom fonts)?
4. Minimum iOS version: 17 (SwiftData, `@Observable`) vs. 16 for broader reach.
