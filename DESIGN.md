# DESIGN.md — REVO Theatre Operations Platform Design System & UI Specification

> **Aesthetic Archetype**: Calm Repertory Precision  
> **Brand Mission**: Provide a reliable, distraction-free, zero-conflict operations and rehearsal planning environment across Admin, Director, and Actor roles.

---

## 1. Visual Foundation & Design Philosophy

REVO manages high-pressure back-of-house theatre production logistics. Backstage environments demand extreme clarity, immediate glanceability, low cognitive load, and zero visual chaos.

### Core Tenets
1. **Calm Authority**: Muted neutral backgrounds with purposeful, high-contrast role-specific cues.
2. **Information Priority**: Critical operational alerts and clashes surface first; secondary administrative navigation stays subordinate.
3. **Deterministic State Signaling**: Statuses are never ambiguous. Red/Amber indicates immediate blocker/shift; Green indicates verified schedule locking; Indigo denotes primary system action.
4. **Scannable Density**: Monospaced tabular numbers for dates and times, tight padding on list items, clear card hierarchy.

---

## 2. Color Palette & Token System

### Brand & Primary
| Token | Hex | Role & Usage |
|---|---|---|
| `primary` | `#3B4A9A` | Deep Indigo — Core brand color, primary actions, active bottom tabs, administrative authority. |
| `primary-hover` | `#2D3977` | Pressed / hover state for primary action buttons. |
| `primary-subtle` | `#EEF1FB` | Very light indigo tint used for active role toggles and active list row highlights. |
| `on-primary` | `#FFFFFF` | Text/icons on primary surfaces. |

### Semantic State Tokens
| Token | Hex | Role & Usage |
|---|---|---|
| `warning-amber` | `#F2B33D` | Stage Amber — Alert banners, detected clashes, pending notifications, reschedule callouts. |
| `warning-surface` | `#FEF8EC` | Soft amber container background for warning callouts and banner cards. |
| `warning-text` | `#946300` | High-contrast accessible text on warning surfaces. |
| `success-green` | `#3FA672` | Confirmed Green — Verified rehearsal slots, conflict resolved state, call-sheet verified badges. |
| `success-surface` | `#EBF7F1` | Soft green container background for confirmed bookings. |
| `success-text` | `#1A633F` | Dark green readable typography on green pills. |
| `error-crimson` | `#D9383A` | Double-booking clash banners, cancelled old calls, blocked facility warnings. |
| `error-surface` | `#FDF2F2` | Background for collision alert sheets and struck-through old call cards. |

### Neutrals & Surfaces
| Token | Hex | Role & Usage |
|---|---|---|
| `surface-base` | `#F9F9FF` | Primary viewport background (crisp, light cool surface tint). |
| `surface-container-lowest` | `#FFFFFF` | Pure white cards, modal bodies, top app bars, bottom tab bar. |
| `surface-container-low` | `#F1F3FF` | Secondary card backgrounds, timeline grid lines, inactive pill backgrounds. |
| `surface-dim` | `#E2E6F2` | Borders, subtle dividers, timeline vertical time rules. |
| `text-primary` | `#171B26` | High-emphasis body, headlines, production titles, actor names. |
| `text-secondary` | `#586074` | Medium-emphasis labels, timestamps, metadata, venue names. |
| `text-tertiary` | `#8C95A8` | Low-emphasis breadcrumbs, struck-through old call times, icons in idle state. |

---

## 3. Typography Hierarchy

**Font Family**: `DM Sans`, system-ui, -apple-system, BlinkMacSystemFont, "Segoe UI", Roboto, sans-serif.  
**Tabular Figures**: `font-variant-numeric: tabular-nums;` for all time intervals, dates, and capacity counts.

| Level | Size | Weight | Line Height | Usage |
|---|---|---|---|---|
| **Display / Title 1** | 22px / 1.375rem | 700 Bold | 1.25 | Mobile Screen Headers, Modal Titles |
| **Title 2** | 18px / 1.125rem | 600 SemiBold | 1.3 | Card Section Titles, Show Names |
| **Headline** | 15px / 0.9375rem | 600 SemiBold | 1.35 | Rehearsal Call Names, Conflict Warnings |
| **Body Large** | 14px / 0.875rem | 500 Medium | 1.4 | Primary List Row Content, Input Fields |
| **Body Medium** | 13px / 0.8125rem | 400 Regular | 1.45 | Metadata, Director notes, Venue specs |
| **Caption / Badge** | 11px / 0.6875rem | 600 SemiBold | 1.2 | Status Badges, Role Tags, Monospace Timestamps |

---

## 4. Spacing & Elevation

### Spacing Scale
- `2xs`: 2px
- `xs`: 4px
- `sm`: 8px
- `md`: 12px
- `lg`: 16px (Standard page gutter on mobile)
- `xl`: 20px
- `2xl`: 24px
- `3xl`: 32px

### Radii
- **Buttons & Tags**: `8px` (`rounded-lg`)
- **Cards & Banners**: `12px` to `16px` (`rounded-xl` or `rounded-2xl`)
- **Modals / Bottom Sheets**: `20px 20px 0 0`
- **Pill Badges**: `9999px` (`rounded-full`)

### Elevation & Shadows
- `elevation-0`: Flat borders (`border border-[#E2E6F2]`)
- `elevation-card`: `0 1px 3px rgba(23, 27, 38, 0.05), 0 1px 2px rgba(23, 27, 38, 0.03)`
- `elevation-floating`: `0 8px 24px rgba(59, 74, 154, 0.12), 0 2px 6px rgba(23, 27, 38, 0.06)` (used for FAB `+` and conflict sheets)

---

## 5. Persona Shells & Layout Archetypes

### A. Admin Shell (Operations Authority)
- **Top Bar**: REVO Monogram aperture logo, "All venues live" status badge, profile badge.
- **Bottom Navigation (4 Tabs + Floating Action Button)**:
  1. `Schedule` (Calendar Timeline icon)
  2. `Shows` (Theatre Masks icon)
  3. `People` (Users Directory icon)
  4. `Venues` (Building / Hall icon)
  - Centered Floating Action Button: Indigo circle `+` for rapid rehearsal creation.

### B. Director Shell (Production & Creative Command)
- **Top Bar**: Show Context Indicator (*The Crucible*), Today's Focus Callout.
- **Bottom Navigation (2 Tabs + FAB)**:
  1. `Home` (Today's Run & Cast Call feed)
  2. `My Show` (Roster, Blocking notes, Scene list)
  - Direct Rehearsal scheduling FAB `+`.

### C. Actor Shell (Cast Portal · Strict Read-Only)
- **Top Bar**: Minimalist greeting (*John Proctor · Week 3 of 6*), Notification bell.
- **Bottom Navigation (3 Tabs · Zero Edit Controls)**:
  1. `Home` (Next Call highlight & Schedule Amber Notice)
  2. `Schedule` (7-Day Strip & daily call times)
  3. `My Show` (Minimal verified role card: Show title, Role name, Director)
  - *No creation buttons or destructive actions accessible.*

---

## 6. Key Component Patterns

### 1. Schedule Amber Alert Banner
- Container: `#FEF8EC` with `#F2B33D` left accent border (3px).
- Icon: Amber warning bell.
- Copy: Headline stating the changed rehearsal with quick link "Tap to review call sheet".

### 2. Multi-Venue Timeline Grid (Admin Schedule)
- Side-by-side vertical facility swimlanes (`Studio A`, `Studio B`, `Main Stage`).
- Time-coded block cards with start and end times in tabular numerals.
- Conflicting overlaps trigger red border flash and prominent amber exclamation badge.

### 3. Conflict Resolution Comparison Card
- Left pane: **Old Call** (Cancelled, Studio A, red tag, struck-through time).
- Right pane: **New Call** (Studio B, confirmed green tag, active call time).
- Consequence footer: *"✓ Recommended · Zero cast delay · Direct SMS broadcast ready"*.

### 4. 7-Day Date Strip
- Horizontal pill strip (Mon through Sun).
- Indicator dot below dates that possess scheduled rehearsals or active changes.
- Selected date styled in filled Deep Indigo `#3B4A9A` with white typography.

---

## 7. Accessibility & Motion

- **Touch Target Minimum**: 44px × 44px across all interactive targets.
- **Contrast**: Compliant with WCAG 2.1 AA (minimum 4.5:1 for body copy against light backgrounds).
- **Reduced Motion Support**: All sheet slide-ins and modal transitions transition smoothly with `150ms ease-out` curves, gracefully respecting `prefers-reduced-motion`.
