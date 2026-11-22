# AI Career Advisor - NextGen Dark Glass UI: Design Tokens (for Flutter)

Source of truth: `ai_career_advisor_nextgen_dark_glass_ui.html`. Per-screen references: `roadmap_screen.html`, `history_screen.html` (open in a browser; use the "Toggle Light / Dark" button).

## Font
Plus Jakarta Sans (400, 500, 600, 700, 800). Use google_fonts or a bundled font asset.

## Colors
| Token | Value |
|---|---|
| Dark canvas | #0B0F19 |
| Dark card | #131927 |
| Dark surface | #1E293B |
| Light canvas | #F8FAFC |
| Brand purple 400 / 500 / 600 / 700 | #C084FC / #A855F7 / #9333EA / #7E22CE |
| Indigo (gradient end) | #4F46E5 |
| Cyan accent | #06B6D4 |
| Emerald / Rose / Amber | #10B981 / #F43F5E / #F59E0B |
| Slate text (muted) | slate-400 #94A3B8, slate-300 #CBD5E1, white for titles |

Primary gradient: `#9333EA -> #4F46E5` (left to right). Hero gradient: `#9333EA -> #4F46E5 -> #06B6D4`.

## Glass card (dark)
- Fill `rgba(26, 34, 53, 0.70)` -> `Color(0xB31A2235)`
- `BackdropFilter(ImageFilter.blur(sigmaX: 16, sigmaY: 16))` inside `ClipRRect`
- Border 1px `rgba(255,255,255,0.10)`
- Radius: 16 (cards), 12 (small cards), 999 (pills)

## Glass card (light)
- Fill `#FFFFFF`, border 1px `#E2E8F0`, shadow `0 4 14 rgba(15,23,42,0.06)`

## Primary button
Gradient purple->indigo, radius 12, shadow `0 4 20 -2 rgba(168,85,247,0.4)` (glow-purple), white bold text 12-14px.

## Badges / pills (dark -> light)
| Kind | Dark | Light |
|---|---|---|
| Purple | bg purple 20% / text #D8B4FE / border purple 30% | bg #F3E8FF / text #6B21A8 / border #C084FC |
| Cyan | bg cyan 20% / text #67E8F9 / border cyan 30% | bg #E0F2FE / text #0369A1 / border #7DD3FC |
| Red (Needs Attention) | bg red 20% / text #F87171 | - |
| Amber (Developing) | bg amber 20% / text #FCD34D | bg #FEF3C7 / text #92400E |
| Emerald (Matched Strength) | bg emerald 20% / text #6EE7B7 | - |

## Light mode text
Headings #0F172A, body #334155, muted #475569, borders #CBD5E1 / #E2E8F0.

## Type scale used in HTML (Tailwind px)
text-[9px], [10px], [11px], xs=12, sm=14, base=16, xl=20. Titles are extrabold (800), labels bold (700).

## Skill-gap colours (Roadmap)
Left border 4px: red-500 (gap >= 2), amber-500 (gap == 1), emerald-500 (gap <= 0). Progress track slate-800, height 6, radius full.

## Screen padding
24px all sides, 12-16px gaps between cards.
