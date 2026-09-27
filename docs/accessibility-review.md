Accessibility and responsive design audit — 2026-09-28

The existing blue palette, rounded controls, navigation arrangement, and screen
structure are preserved. Text scaling is not capped. Layouts reflow when needed.

| Finding | Fix |
| --- | --- |
| Bottom navigation overflowed with enlarged labels | Measure labels at their actual width and text scale; reserve sufficient height. The raised Add control now sits inside its parent's hit-test bounds. |
| Custom gesture-only controls were missing keyboard interaction and button state | Shared accessible action exposes enabled/selected/button semantics, supports Tab/Enter through InkWell, paints a focus border over opaque controls, and enforces a 48×48 minimum target. Applied to navigation, category pills, theme/timeframe controls and quick Add. |
| Month arrows were tiny and unlabeled | Shared month selector uses 48×48 icon buttons with Previous/Next month tooltips and correctly disabled Next behavior. |
| Rows clipped titles/amounts or overflowed at large text sizes | Dense expense/category/summary rows stack on constrained layouts; section headings and controls wrap. Removed single-line truncation of transaction titles, summary values and greeting names. |
| Fixed history header competed with the keyboard and short landscape viewport | Heading, search and filters scroll with the lazy sliver list. The shell hides bottom navigation while the keyboard is visible. |
| Category sheet could overflow vertically | Made the picker scrollable within its available height. Filter clear icons have explicit tooltips. |
| Low contrast on inactive navigation and segmented controls | Darkened light-mode muted labels and brightened dark-mode navigation labels. Updated input outlines/focus borders; search has a visible focused outline and persistent label. |
| Chart information depended on sight/touch | Added spoken trend values and category percentages. Scaled axis labels receive more height and horizontal space, with scrolling when necessary. Pie label text selects black/white based on slice luminance. |
| Date input did not explicitly announce its role/state | Announces Date, the formatted value, button role and enabled state. |

Automated coverage in `test/presentation/accessibility_layout_test.dart` includes
320×568, 568×320 and 1024×768 logical pixels at 1×, 2× and 3× text scaling, in both
themes. Dashboard, analytics, history, settings, add and edit are exercised and
scrolled: 108 screen configurations. Long transaction titles and large currency
amounts are included. Additional checks cover keyboard overlap on history/add,
registration with a landscape keyboard, scrolling the category picker, rendered
navigation/segmented-label contrast, and keyboard/button semantics.

The theme tests now construct Google Fonts themes inside the test zone, allowing
the existing theme accessibility checks to execute instead of failing at load.

This is automated layout/semantics validation and source inspection. Physical
device TalkBack/VoiceOver traversal, real-font screenshot comparison, and browser
keyboard behavior still need manual device QA; this is not a certification of
accessibility conformance. No Firebase rules, data access or persistence behavior
was changed by this audit.

Validation: `flutter analyze` reports no issues. All 56 focused accessibility,
theme, chart, filter, search, settings and history tests pass. The full suite
reports 231 passing and 15 failing tests; every remaining failure name also
appears in the unchanged baseline captured during the prior review. The existing
navigation overflow test now passes, and theme tests execute successfully.
`git diff --check` is clean. The final date-field focus adjustment was verified
with the analyzer and the 56-test focused suite after the full-suite run.
