# Expense Tracker

Android-only Flutter application using the existing Firebase project.
Authentication, the expense data layer, the full expense editor (add, edit,
delete, history), the main dashboard with charts, filtering/sorting/
search of the history list, a Settings screen (theme, currency preference,
logout, app info), and a UX polish pass (pull-to-refresh, skeleton loading,
consistent snackbars, and empty/error/confirmation-state consistency across
every screen) are implemented.

## Run

Use Flutter 3.47.5 stable / Dart 3.13.4 (the SDK used to validate this module).

```sh
flutter pub get
flutter run
```

Firebase initialization uses `DefaultFirebaseOptions.currentPlatform` through
`FirebaseServices`, invoked from `lib/main.dart`. The existing Firebase IDs, `lib/firebase_options.dart`,
`android/app/google-services.json`, and Android Gradle configuration are preserved.
Do not regenerate them to run this module.

## Structure and decisions

- `lib/main.dart`: Flutter binding, Riverpod scope, and Firebase initialization.
- `lib/app.dart`: application composition using MaterialApp.router.
- `lib/core/`: shared constants, spacing, light/dark themes, and currency config.
- `lib/domain/`: framework-independent entities, repository contracts, and validation.
- `lib/data/`: Firebase initialization, data sources, and repository implementations.
- `lib/presentation/`: providers, screens, and reusable list/form widgets.
- `lib/routing/`: go_router ownership, routes, and missing-page recovery.

The initializer is injected and asynchronous, so a loading view appears while
Firebase starts. Failures are reported through FlutterError and presented with a
retry action. Tests inject an initializer without contacting live Firebase.
Riverpod owns the router lifecycle and app state. Presentation contains no
Firebase SDK imports or direct database calls.

Material 3 follows the device theme by default and the choice (system/light/dark)
is persisted locally via the Settings screen — see "Settings module" below.
Currency is centralized in `CurrencyConfig`, defaulting to LKR / en_LK with two
decimal places; Settings exposes a persisted currency preference, scoped as
described in that section.

Installed dependencies include Firebase Core/Auth/Firestore, Riverpod, go_router,
intl, fl_chart, shared_preferences, and mocktail for tests. Pub resolves stable
compatible versions and `pubspec.lock` records the result. Serialization code
generation and integration_test will be introduced with modules that use them.
Simple immutable configuration does not need generated models.

## Verification

```sh
dart format .
flutter analyze
flutter test
flutter build apk --debug
```

Tests cover currency formatting/customization, initialization caching and retry,
theme state and UI selection, loading/error/success transitions, route recovery,
compact/tablet layouts with enlarged text, authentication (validation, repository,
state transitions, routing guards), the expense domain model and its
serialization, the Firestore expense repository (CRUD, streaming, ownership
isolation, error mapping), expense form validation, the Add Expense screen, the
Expense History screen (loaded/empty/error states, delete confirm/success/
failure, edit navigation), the expense editor (existing data loading, field
changes, validation, successful/failed update, missing expense, loading state,
and the unsaved-changes guard), the dashboard (month aggregation, month
navigation, empty month, and that switching months never re-queries Firestore),
expense filtering/sorting (category, exact date, date range, month, all four
sort orders, combined filters, clear filters, and an empty filtered result —
at both the pure-model level and wired through the history screen), and
expense search (title, note, case-insensitivity, whitespace tolerance, no
result, combined with a category filter, combined with a date filter, clear
search, and that the filtered list only updates once the debounce elapses),
and the dashboard's charts (category aggregation into chart-ready slices,
zero data, one category, many categories, large amounts, the monthly-trend
transformation, and that each chart renders without error in both light and
dark mode), and Settings (theme mode state, restoring a persisted theme mode,
setting a theme mode persisting it, switching between all three modes,
currency preference state/persistence, the Settings screen's appearance
control, currency picker, logout confirm/cancel flow, and app info display),
and the UX polish pass (`ExpenseListSkeleton` rendering its configured row
count without error in light and dark mode, `ScrollableFill` filling short
content to the viewport height and remaining pull-to-refresh-able even when
its content doesn't overflow, and the edit/delete row actions meeting a
44x44 minimum tap target). They do not verify a live Firebase connection.
Launch on the configured Pixel emulator for that check.

## Next modules

Wiring the persisted currency preference into amount formatting throughout
the app (dashboard, history, charts currently still use
`CurrencyConfig.defaultCurrency` — see "Settings module" below).

The UI shell needs no Console changes. Using Auth and Firestore requires the
setup and rules described in docs/firebase-setup.md.

## Foundation conventions

`AppTheme` defines Material 3 typography, seeded light/dark color schemes,
input focus/error borders, rounded cards, and shared button sizing. Buttons have
a minimum 48 logical-pixel height and can grow with accessibility text scaling.
`AppSpacing` supplies 8/16/24/32 logical-pixel layout spacing; `AppConstants`
owns the application name. Material semantic text styles remain the typography
API; no custom design-system widget layer is needed.

`AppRouter` declares the home route, the (authenticated-only) Add Expense
route, and the edit-expense route pattern; Riverpod disposes the router.
Startup continues to use the existing Firebase options via the injected
initializer. Theme selection lives in `presentation/providers` and remains
session-only.

## Firebase data foundation

Firebase Auth and Cloud Firestore dependencies and injectable data sources are now
installed. See [Firebase setup](docs/firebase-setup.md) for exact remaining Console
steps, local emulator configuration, rule deployment, and testing limitations.
Authentication UI is implemented. The expense data layer supports CRUD and streams.

## Add/Edit expense module

`ExpenseForm` (`presentation/widgets/expense_form.dart`) is the single
implementation of the expense fields — title, amount, category, date, optional
note — shared by `AddExpenseScreen` and the expense editor, so validation, the
"no future dates" rule, and the field layout live in exactly one place. It
takes initial values, a `saving` flag, a submit label, and an `onSubmit`
callback that only ever receives validated primitives; building an `Expense`
and calling the repository is each owning screen's job, since create and
update differ there.

- **Amounts**: entry is restricted to digits and a single decimal point via an
  input formatter, and independently validated as a positive, finite number no
  larger than a sanity ceiling (`ExpenseValidation.maxAmount`). Because the
  formatter already blocks `-`, a true negative-amount attempt can only reach
  the validator programmatically; it is covered by a validator unit test
  rather than a widget test.
- **Dates**: expenses record money already spent, so a future date is
  rejected. The date picker's `lastDate` is pinned to "now" so the picker never
  offers an invalid choice, and `ExpenseValidation.date` is a defensive second
  check for any date that reaches submission another way.
- **Category**: a single-select `ChoiceChip` row (`CategorySelector`) rather
  than a dropdown, so all nine categories and their icons stay visible and
  reachable in one tap.
- **IDs**: `ExpenseRepository.newExpenseId()` allocates a Firestore
  auto-generated ID locally (no network round trip) for new expenses; edits
  reuse the existing ID.
- Title and note both use the field's own `maxLength`, which Flutter enforces
  by truncating input as it's typed; the corresponding validator checks are
  therefore only exercised as unit tests.

**Create** (`AddExpenseScreen` + `AddExpenseController`): builds a new
`Expense` with a fresh ID and the signed-in user as owner, then calls
`ExpenseRepository.createExpense`.

**Edit** (`EditExpenseScreen` + `EditExpenseFormView` + `EditExpenseController`):
the route only carries the expense ID (`/expenses/:id/edit`); the screen
fetches the expense itself via `expenseByIdProvider` (an
autoDispose family `FutureProvider` over `ExpenseRepository.getExpenseById`)
rather than trusting an object passed along with the navigation, so it
handles four states: loading (spinner), not found (`Expense` was deleted
since the list was read — a status view with "Go back"), error (mapped
message with Retry), and loaded (the form). `EditExpenseController.submit`
takes the *original* `Expense` alongside the edited primitives and rebuilds
it with the original's `id`, `userId`, and `createdAt` — the form and its
"dirty" tracking never see these fields, so they cannot be altered by
editing even in principle. `updatedAt` is refreshed locally to keep the
entity's own invariant (`updatedAt >= createdAt`) satisfied; the repository
already replaces it with a Firestore server timestamp on write, same as
create, and already strips `id`/`userId`/`createdAt` from the update payload
— no repository changes were needed for this module.

**Unsaved changes**: `ExpenseForm` compares each field's current value
against its initial value and reports "dirty" via `onDirtyChanged` — exact
value comparison, so reverting a field back to its original value clears
dirty again, but retyping the same amount in a different textual form (e.g.
"24.0" for an initial "24") still reads as dirty; a practical, not
perfect, approximation. Both `AddExpenseScreen` and the edit screen wrap
their content in `PopScope`, blocking back navigation while dirty and
showing a shared discard-confirmation dialog
(`presentation/widgets/discard_changes_dialog.dart`) before allowing the pop.
Both screens pop with plain `Navigator.pop` rather than go_router's
`context.pop()`, since "return to whoever pushed me" doesn't need go_router
specifically and this keeps the screens navigable from a plain `Navigator`
in tests.

## Expense History module

`ExpenseHistoryView` (`presentation/screens/expense_history_view.dart`) is
Home's body. It watches `expenseListProvider`, a `StreamProvider<List<Expense>>`
built on `ExpenseRepository.watchExpenses()` — real-time and newest-first by
construction, so the view does no sorting of its own — and renders one of the
four required states via `AsyncValue.when`: a centered spinner while loading, a
`StatusView` with a Retry button (`ref.invalidate(expenseListProvider)`) on
error, a `StatusView` with an "Add expense" call to action when the list is
empty, or a `ListView.builder` of `ExpenseListItem` cards otherwise.

- **Reusable row widget**: `ExpenseListItem` (`presentation/widgets/`) renders
  the category icon, title, an optional note indicator icon, the
  category/date subtitle, the formatted amount, and edit/delete icon buttons.
  It is purely presentational plus the delete confirmation dialog — it never
  shows its own SnackBar — so it stays correct even if the row is removed
  from the tree mid-delete once the list updates.
- **Rebuild scoping**: `ExpenseHistoryView`'s Scaffold/AppBar (in `HomeScreen`)
  never watches the expense stream, so theme/sign-out actions don't rebuild
  the list. Each row reads its own delete state with
  `deleteExpenseControllerProvider.select((s) => s[expense.id])`, so deleting
  one expense does not rebuild every other row. `ListView.builder` is lazy and
  each item carries a `ValueKey(expense.id)` so Flutter can diff insertions/
  removals efficiently instead of rebuilding the whole list.
- **Delete flow**: `DeleteExpenseController` is a `Map<String, AsyncValue<void>>`
  keyed by expense ID (not a family provider, to keep the manual-Notifier
  pattern identical to the rest of the app). Confirming the dialog calls
  `delete(id)`, which shows a per-row spinner and disables that row's actions
  while `ExpenseRepository.deleteExpense` runs. `ExpenseHistoryView` listens to
  the whole map and turns a loading→success transition into a "Expense
  deleted." SnackBar and a loading→error transition into an error SnackBar
  (using the same mapped `AppException` message as elsewhere); either way the
  per-ID entry is then cleared. The row's actual removal from the screen comes
  from the Firestore stream re-emitting without that document — the real
  "Update UI" step — rather than an optimistic local splice, so the list can
  never show a stale row Firestore has already deleted, or hide one it hasn't.
- **Edit action**: pushes `/expenses/:id/edit` (see "Add/Edit expense module"
  above for what that route now does).

Because `HomeScreen`'s body depends on `expenseRepositoryProvider`, every test
that reaches an authenticated Home screen — including the existing startup/
theme/routing and authentication tests — overrides it with a fake or mocked
`ExpenseRepository`; otherwise resolving the provider would reach for a real
Firebase instance the test never initialized. The full, unfiltered history
list itself moved to its own route (see "Dashboard module" below); `HomeScreen`
now shows `DashboardView`, and `ExpenseHistoryView` is reused as-is inside a
thin `ExpenseHistoryScreen` at `/expenses`.

## Dashboard module

`DashboardView` (`presentation/screens/dashboard_view.dart`) is now Home's
body: a greeting, a month selector, the selected month's total and
transaction count, a per-category breakdown, and its most recent expenses,
with a "View all" link to the full history at `/expenses`.

- **No extra Firestore reads**: `monthlyExpenseSummaryProvider` is a plain
  synchronous `Provider<AsyncValue<MonthlyExpenseSummary>>` — not a new
  stream or future — that combines `selectedMonthProvider` (the month
  currently shown) with the data already held by `expenseListProvider`, the
  same single live listener the history screen uses. Changing the selected
  month only re-aggregates data already in memory; a widget test
  (`dashboard_view_test.dart`) asserts `watchExpenses()` is called exactly
  once even after navigating across several months, to make this concrete
  rather than just asserted in prose. Pull-to-refresh is the one action that
  does re-subscribe (`ref.refresh(expenseListProvider.future)`), since that's
  the explicit "get me the latest" gesture.
- **Domain-level aggregation**: `ExpenseSummaryCalculator.summarize`
  (`domain/usecases/expense_summary.dart`) is a pure function — no widgets,
  no providers — so the monthly total, transaction count, category totals,
  and recent-expense ordering are each unit tested directly
  (`test/domain/expense_summary_test.dart`) without pumping a widget tree.
  Month membership is decided by `expense.date` — never `createdAt` or
  `updatedAt` — per the requirement that the monthly total reflect when the
  money was spent, not when it was recorded. `recentExpenses` is explicitly
  re-sorted newest-first inside `summarize` rather than trusted from the
  input list's order, so it stays correct however the caller's list is
  ordered, and is capped at `ExpenseSummaryCalculator.recentLimit` (5).
- **Month navigation**: `MonthNavigation` (`domain/usecases/month_navigation.dart`)
  is a second pure class — `normalize`, `previous`, `next`, `isCurrentMonth` —
  backing `SelectedMonthController`. `next` is capped at the current month
  (it's a no-op once there), and `_MonthSelector` also disables the "next"
  button outright at that point, rather than leaving it clickable with no
  effect, so it's visibly clear there's nothing later to move to yet.
- **States**: `monthlyExpenseSummaryProvider`'s `AsyncValue` still carries
  loading and error from the underlying `expenseListProvider`, so
  `DashboardView` handles those the same way the rest of the app does
  (spinner; `StatusView` with Retry). A month with no expenses shows a
  distinct empty state (`_EmptyMonth`, "No expenses in \<Month Year\>") with
  its own "Add expense" action, instead of an empty category list and recent
  list.
- **Category summary doubles as the chart**: `CategorySummaryList`
  (`presentation/widgets/category_summary_list.dart`) renders each category
  sorted by spend with a proportional `LinearProgressIndicator`. This is a
  deliberate, disclosed stand-in for a real chart — neither the dashboard's
  requirements nor its test list call for a specific charting library, so
  `fl_chart` has not been added yet; swapping this widget for a chart later
  needs no change to the summary data it's given.
- **Greeting**: `greetingForHour` (`core/utils/greeting.dart`) is a pure,
  unit-testable helper (morning/afternoon/evening/night) rather than logic
  inlined in the widget; the dashboard adds the signed-in user's name when
  `AuthUser.name` is available.

`HomeScreen`'s FAB stays visible over the dashboard exactly as it did over
the history list, so "Add expense" is reachable from Home either way.

## Filtering & sorting module

The expense history screen (`/expenses`) can now be narrowed by category,
an exact date, a date range, or a month, and reordered by newest, oldest,
highest amount, or lowest amount — any combination at once.

- **Immutable state, pure logic**: `ExpenseFilter` (`domain/usecases/expense_filter.dart`)
  holds the four optional constraints and the current `ExpenseSortOption`;
  every change goes through a `copyWith*` method that returns a new instance
  rather than mutating one in place. `ExpenseFilterEngine.apply` is a
  standalone pure function — filter, then sort, on a plain `List<Expense>` —
  with no dependency on widgets or providers, so `test/domain/expense_filter_test.dart`
  exercises category filtering, exact-date filtering, date-range filtering
  (its own small `DateRange` value type, an inclusive whole-day range),
  month filtering, all four sort orders, several filters combined at once,
  clearing back to `ExpenseFilter.initial`, and a combination matching
  nothing, entirely without pumping a widget tree.
- **Mutual exclusion lives in the model, not the UI**: setting an exact date
  clears any active date range or month (and vice versa) inside
  `ExpenseFilter`'s own `copyWith*` methods, since the three date modes are
  alternatives, not independent constraints. Category and sort are
  orthogonal to all three and to each other, so "category = Food, date
  range = Sept 1–30, sort = highest amount" narrows and orders in one pass,
  as required.
- **No extra Firestore reads**: `filteredExpenseListProvider`
  (`presentation/providers/expense_providers.dart`) is a plain synchronous
  `Provider` that maps `expenseListProvider`'s already-loaded data through
  `ExpenseFilterEngine.apply` and the current `expenseFilterProvider` state —
  the same pattern as the dashboard's monthly summary. Changing a filter or
  the sort order only re-filters data already in memory.
- **`ExpenseHistoryView`** now tells apart "no expenses at all" (checked
  against the raw, unfiltered `expenseListProvider`) from "nothing matches
  the current search/filters" (checked against `filteredExpenseListProvider`,
  which — see "Search module" below — folds in the search text too), so the
  empty state and its call to action differ: "No expenses yet" → Add
  expense, versus "No matching expenses" → a Clear action scoped to whatever
  is actually active (Clear search / Clear filters / Clear search & filters).
  The search field and filter bar only appear once there's at least one
  expense to search or filter.
- **`ExpenseFilterBar`** (`presentation/widgets/expense_filter_bar.dart`) is
  presentation-only — every chip reads or writes `expenseFilterProvider`
  through its controller, never `ExpenseFilterEngine` directly. The category
  picker is a bottom sheet of `ChoiceChip`s reusing `CategorySelector`'s
  icons; date and date-range use Flutter's built-in pickers; month reuses
  the date picker in its year-view mode (there's no dedicated month-only
  picker in Flutter) and keeps only the year/month of whatever gets
  confirmed. A "Clear filters" chip appears only while a filter is active.
- Covered again at the widget level in `test/presentation/expense_filter_bar_test.dart`
  (picking a category narrows the list, an unmatched combination shows the
  empty-filtered state and Clear filters recovers from it, and changing sort
  reorders the rendered rows) — the same combined/clear/empty-result
  behavior as the domain tests, this time proven through the actual UI.

## Search module

The expense history screen can also be searched by title or note, and the
result respects whatever filters/sort are already active.

- **Pure matching**: `ExpenseSearchEngine` (`domain/usecases/expense_search.dart`)
  is a standalone function, independent of `ExpenseFilterEngine` — filtering
  and searching are two separate concerns that happen to compose. `normalize`
  lowercases, trims, and collapses runs of whitespace on *both* sides of the
  comparison (the typed query and the stored title/note), so the match is
  case-insensitive and tolerant of incidental extra spacing in either.
  `test/domain/expense_search_test.dart` covers title matches, note matches,
  case-insensitivity, whitespace tolerance, no result, clearing (an empty or
  blank query returns the input unchanged), and — composed by chaining
  `ExpenseFilterEngine.apply` into `ExpenseSearchEngine.apply` — a category
  filter and a date filter each combined with a search term.
- **Composes with filtering, not instead of it**: `filteredExpenseListProvider`
  now applies `ExpenseFilterEngine.apply` first and `ExpenseSearchEngine.apply`
  second, both against `expenseListProvider`'s already-loaded data via a new
  `expenseSearchQueryProvider`/`ExpenseSearchQueryController`. Neither the
  filter nor the search text can ever trigger another Firestore read — only
  re-computation over data already in memory.
- **Debounced, not query-per-keystroke**: `ExpenseSearchField`
  (`presentation/widgets/expense_search_field.dart`) updates its own
  `TextEditingController` immediately (so typing feels instant) but only
  pushes the value into `expenseSearchQueryProvider` — and so only
  re-filters the rendered list — 300ms after the user stops typing. There's
  no Firestore query either way (this is a local, in-memory filter), but the
  debounce still avoids rebuilding the filtered list on every keystroke, and
  keeps the pattern consistent if search ever needs to reach the server.
  `test/presentation/expense_search_field_test.dart` asserts the list is
  still unfiltered immediately after typing and only updates once the
  debounce elapses.
- **Clear search vs. clear filters stay independent**: the search field's
  own suffix icon clears only the search text; `ExpenseFilterBar`'s "Clear
  filters" chip clears only the filters. The combined empty-result view in
  `ExpenseHistoryView` offers a single action button, but its label and
  effect adapt to what's actually active — Clear search, Clear filters, or
  Clear search & filters — so there's always exactly one tap back to a
  non-empty result whatever combination produced the empty state. Because
  `ExpenseSearchField` only sets its own state from user input, it also
  listens for external clears of `expenseSearchQueryProvider` (e.g. from that
  shared button) so its own text box stays in sync.

## Charts module

The dashboard now visualizes spending with `fl_chart` instead of numbers
alone: a donut chart of the selected month's category breakdown, and a bar
chart of the last six months' totals.

- **Pure transformation, no Firestore coupling**: `domain/usecases/expense_chart_data.dart`
  turns already-computed data into chart-ready shapes — `CategorySlice`
  (category, amount, percentage of the chart's total) from a category→total
  map, and `MonthlySpendingPoint` (month, total) from a raw expense list by
  re-running `ExpenseSummaryCalculator.summarize` per month. Both chart
  widgets (`CategoryPieChart`, `MonthlySpendingChart`) take these plain data
  types as constructor parameters — never a repository, a provider, or a raw
  `Expense` list — so they have no path to Firestore at all and can be
  previewed or reused against any data. `test/domain/expense_chart_data_test.dart`
  covers category aggregation and totals (sorted, percentages summing to
  1.0), the zero-data case (an empty map → an empty slice list), one
  category (a single 100% slice), many categories (all nine represented),
  large amounts (exact, no float rounding surprises), and the monthly
  transformation for a selected month and window.
- **No extra Firestore reads**: the category chart's slices are computed
  inline in `DashboardView` from `summary.categoryTotals` (already resolved
  by `monthlyExpenseSummaryProvider` — no separate provider needed for a
  one-line pure-function call). `monthlySpendingChartProvider` is a plain
  `Provider` re-mapping `expenseListProvider`'s already-loaded data, keyed
  off `selectedMonthProvider` — browsing months recomputes the trend chart
  from memory, the same pattern as every other dashboard figure.
- **Not visually dominant**: both charts render at a fixed, modest height
  (160px) regardless of screen width — `CategoryPieChart` also caps its own
  diameter at 320px so it doesn't stretch edge-to-edge on a tablet — rather
  than becoming the page's focal point. `CategorySummaryList` (the existing
  proportional-bar list) stays directly under the pie chart and doubles as
  its legend: it already prints exact figures and category names the pie
  chart's slices don't have room for, and now shares its colors
  (`colorForCategory` in `category_selector.dart`) with the chart, so a
  slice and its legend row are visually tied together.
- **Zero data**: each chart shows a short text message ("No spending yet" /
  "No spending in this period yet") instead of an empty or broken chart.
  **One category**: a single full slice with a "100%" label. **Many
  categories**: small slices below an 8% share skip their in-chart
  percentage label (it wouldn't fit legibly) but stay fully represented in
  the legend. **Large amounts**: percentages and bar heights are computed
  from the real totals with no artificial cap; the bar chart's `maxY` always
  leaves headroom above the tallest bar. **Dark mode**: category colors are
  a fixed, deliberately theme-independent palette (`shade400` tones chosen
  to read clearly on both a light and a dark surface) rather than derived
  from the seeded color scheme, while every other chart element (grid lines,
  axis labels, the empty-state message, the tooltip) uses `Theme.of(context)`
  colors, so it adapts automatically. **Responsive layouts**: both charts
  size themselves from their parent's constraints (via `LayoutBuilder` /
  `SizedBox`) rather than a hard-coded width, so they render correctly at
  phone and tablet widths alike.
- **Labels where useful, not everywhere**: the bar chart labels its x-axis
  with abbreviated months and highlights the selected month's bar in the
  primary color (others muted), with exact figures available on touch via a
  tooltip rather than printed permanently on every bar — printing nine
  currency labels on a 160px-tall chart would be the "visually dominant,
  hard to read" outcome this module was asked to avoid.
- Covered at the widget level in `test/presentation/dashboard_charts_test.dart`:
  zero data, one category, many categories, a very large amount, and dark
  mode for both charts, each asserting the widget renders without a
  `takeException()` failure.

## Settings module

A new `SettingsScreen` (`presentation/screens/settings_screen.dart`, at
`/settings`) replaces Home's old "Appearance" popup menu with a proper
Settings screen covering appearance, currency, account, and app information.
Home's AppBar now has a "Settings" icon button alongside the existing "Sign
out" button, which is unchanged — Settings additionally offers its own,
confirmed "Log out", so both remain valid ways to sign out.

- **Local persistence choice**: `shared_preferences` is used for both
  persisted preferences here. The data being stored is two small, primitive
  values (a `ThemeMode` name and a currency code string) with no querying,
  relations, or need to sync across devices — exactly the shape
  `shared_preferences`'s key-value store is for, and it is lighter weight
  than pulling in a database (e.g. `sqflite`, Hive) for this. A single
  `sharedPreferencesProvider` (`data/services/local_preferences_providers.dart`,
  a `FutureProvider<SharedPreferences>`) is shared by both controllers so
  there's exactly one call to `SharedPreferences.getInstance()`.
- **Theme mode, persisted**: `ThemeModeController` (rewritten in
  `presentation/providers/theme_mode_provider.dart`) still returns
  `ThemeMode.system` synchronously from `build()` — so the app always has a
  theme to render on the very first frame — but now also kicks off an async
  `_restore()` that reads the `theme_mode` key from `sharedPreferencesProvider`
  and updates `state` once it resolves. This is a deliberate, disclosed
  trade-off: on a device with a previously-saved Dark preference, there can be
  a single frame of the system theme before the restore completes and flips
  it — acceptable given how fast `SharedPreferences` resolves in practice, and
  far simpler than blocking the whole app shell on preference restoration the
  way Firebase startup is blocked. `setMode` is now `async`: it updates
  `state` immediately (so the UI responds instantly) and then persists
  `mode.name` to `shared_preferences`.
- **Currency preference, persisted but intentionally not wired everywhere
  yet**: `CurrencyPreferenceController`
  (`presentation/providers/currency_preference_provider.dart`) follows the
  same restore-then-persist pattern, storing just the chosen `CurrencyConfig`'s
  `code` and matching it back against a new `CurrencyConfig.options` list
  (LKR, USD, EUR, GBP, INR) on restore. This is a real, working, persisted
  preference — not a cosmetic placeholder — but the prompt asked for a
  "currency preference placeholder/configuration," and the rest of the app
  (dashboard totals, history rows, chart tooltips) still formats amounts with
  `CurrencyConfig.defaultCurrency`. Rather than silently limiting the scope,
  that's called out explicitly here and in "Next modules" above: picking a
  currency in Settings persists correctly and is fully tested, but does not
  yet change how amounts are displayed elsewhere.
- **Settings screen contents**: Appearance (a `SegmentedButton<ThemeMode>`
  with System/Light/Dark segments, each with an icon, mirroring the
  three-mode requirement directly rather than through a menu); Currency (a
  `ListTile` showing the current code that opens a bottom sheet of
  `RadioListTile<CurrencyConfig>` options); Account ("Log out", styled in
  `colorScheme.error`, behind a confirmation `AlertDialog` — mirroring the
  existing discard-changes dialog's confirm/cancel shape — before calling
  `AuthController.logout()`); About (`AppConstants.appName` and the new
  `AppConstants.appVersion`).
- **Every screen supports both themes — audit findings**: a full grep across
  `lib/` for `Colors.` and `Color(0x` turned up exactly three hardcoded colors
  in the whole app, all pre-existing and each a deliberate, narrow exception
  rather than an oversight: `AppTheme._seedColor`, the single seed color
  `ColorScheme.fromSeed` derives both the light and dark schemes from
  (`core/theme/app_theme.dart`); the fixed categorical palette in
  `category_selector.dart`'s `colorForCategory`, needed because one seed color
  cannot generate nine visually distinct category hues, chosen in `shade400`
  tones deliberately so they stay legible on both a light and dark surface
  (documented already in the Charts module above); and the pie chart's
  in-slice label text color (`Colors.white` in `category_pie_chart.dart`),
  needed because slice labels sit on top of the categorical colors above,
  not the theme surface, so they can't be a `ColorScheme` color either.
  Every other audited surface — cards (`CardThemeData`), input fields
  (`InputDecorationThemeData`, including focus/error borders), dialogs
  (Material 3's `AlertDialog` already derives from `ColorScheme` with no
  extra theming needed), icons and buttons (`FilledButton`/`ElevatedButton`/
  `OutlinedButton`/`TextButton` themes, plus the un-styled `IconButton`s and
  `Icon`s throughout, which inherit `IconThemeData`/`colorScheme.onSurface`
  by default), navigation (the `AppBar`, `BottomSheet`, and `SegmentedButton`
  above all derive from `ThemeData`), and chart chrome (grid lines, axis
  labels, tooltip background, the empty-state text — everything in
  `CategoryPieChart`/`MonthlySpendingChart` except the categorical palette
  itself) — already read from `Theme.of(context)`/`ColorScheme` rather than a
  literal color, so no changes were needed there for this module; the audit
  confirmed the existing `AppTheme` from earlier modules already holds this
  invariant rather than needing new theming work now.
- **Tests**: `test/presentation/theme_mode_provider_test.dart` covers theme
  state (defaults to system before restore), persistence (restoring a
  previously-saved dark mode; `setMode` writing the chosen mode to storage),
  and switching between all three modes — plus the equivalent three cases for
  the currency preference controller. `test/presentation/settings_screen_test.dart`
  covers the screen itself: the appearance control reflecting and updating
  `themeModeProvider`, a switch being written to local storage, restoring a
  previously-persisted dark theme on mount, picking a currency updating both
  the shown code and storage, confirming the logout dialog calling
  `AuthRepository.logout()`, cancelling it not doing so, and the app
  name/version being shown. `test/widget_test.dart`'s theme-switching test
  now navigates to Settings and drives the `SegmentedButton` instead of the
  old popup menu. Every existing test that mounts the full `ExpenseTrackerApp`
  now calls `SharedPreferences.setMockInitialValues({})` before pumping,
  since both new controllers now depend on `shared_preferences` during
  startup.

## UX polish pass

A pass over every existing screen for spacing, typography, alignment,
keyboard behavior, SafeArea, loading/empty/error states, button states,
touch targets, accessibility, dark mode, responsiveness, scrolling, form
usability, confirmation dialogs, and success feedback — deliberately no new
features or architecture changes, only consistency and polish on what
already existed.

- **Pull-to-refresh everywhere the dashboard already had it**: the dashboard
  had `RefreshIndicator` from its own module; the expense history screen
  (`/expenses`, `ExpenseHistoryView`) did not. It now wraps its whole body in
  the same `RefreshIndicator` → `ref.refresh(expenseListProvider.future)`
  pattern, available in every state (loading, error, empty, no-matches,
  loaded) via a new shared `ScrollableFill` widget
  (`presentation/widgets/scrollable_fill.dart`, extracted from the private
  helper the dashboard already had) that gives non-scrollable content (a
  spinner, a `StatusView`) a scrollable ancestor with
  `AlwaysScrollableScrollPhysics` — needed because `RefreshIndicator` only
  detects its pull gesture through a scrollable descendant, and short
  content that doesn't overflow its viewport doesn't register a drag at all
  under the default scroll physics. `test/presentation/ux_polish_test.dart`
  covers this directly: a `ScrollableFill` wrapping short, non-overflowing
  content still triggers `onRefresh` when dragged.
- **A real skeleton loader for the expense list**: the history screen's
  loading state was previously a bare centered spinner; it's now
  `ExpenseListSkeleton` (`presentation/widgets/expense_list_skeleton.dart`),
  a handful of card-shaped placeholder rows sized like `ExpenseListItem`.
  It's deliberately *static*, not shimmering/animated — the module's own
  instruction to avoid excessive animation — so it's a shape-of-the-content
  hint rather than a moving distraction. The dashboard's own loading state
  (a different, non-list shape) keeps its centered spinner, now with a
  `semanticsLabel` for parity with the labeled spinners already elsewhere
  (splash screen, form submit buttons).
- **Consistent snackbars/toasts everywhere in one place**: rather than
  editing every individual `showSnackBar` call across Add/Edit/Delete
  expense, auth, and settings, `AppTheme` now defines a single
  `snackBarTheme` (floating behavior, rounded shape matching the app's
  card/button corner radius, `colorScheme.inverseSurface` background) so
  every success and error toast in the app already looks the same without
  each call site needing to specify it.
- **44x44 minimum touch targets on the history row actions**:
  `ExpenseListItem`'s edit/delete `IconButton`s used
  `VisualDensity.compact` to fit two icons in a tight row, which could push
  their effective tap area below a comfortable minimum. They now use
  explicit `constraints: BoxConstraints(minWidth: 44, minHeight: 44)`
  instead, keeping the same compact visual icon size while guaranteeing the
  tap target — verified directly in `ux_polish_test.dart` via
  `tester.getSize`.
- **A real error state for sign-in/registration failures**: the auth
  screen's validation/auth error was plain colored text; it's now a boxed,
  iconed banner (`colorScheme.errorContainer`, matching how errors read
  elsewhere in the app — confirmation dialogs' destructive actions, the
  dashboard/history's `StatusView`) that fades in with a short
  `AnimatedSwitcher` rather than popping in abruptly.
- **Subtle, deliberately minimal animation, not more of it**: three small
  crossfades were added — the auth error banner appearing, the splash
  screen's loading→failed transition, and the dashboard's monthly-trend
  chart's loading→data transition — each a 150–200ms `AnimatedSwitcher`.
  Nothing else in the app was given a new animation; the skeleton loader
  above is intentionally static for the same reason.
- **Overflow guards for large text scale and narrow phones**: the
  dashboard's greeting (which can include a signed-in user's display name,
  arbitrary length) and its month-selector heading now cap at 1–2 lines with
  ellipsis instead of assuming they always fit — the existing 320-logical-
  pixel-width, 2x-text-scale widget test already exercised this class of
  layout, this closes a gap it hadn't hit yet.
- **Everything else was already in good shape and deliberately left alone**:
  every screen already had SafeArea, a loading spinner, an empty state with
  a call to action, an error state with Retry, and a confirmation dialog for
  every destructive action (delete, discard unsaved changes, logout) styled
  consistently (Cancel/destructive-action pair, the destructive action in
  `colorScheme.error`). Dark mode, spacing, and form keyboard behavior
  (`textInputAction` chains, `autofillHints`, scrollable forms) were already
  correct per the Charts and Settings modules' own audits, so this pass
  didn't re-touch them beyond the snackbar theme above.
- **Tests**: new `test/presentation/ux_polish_test.dart` covers
  `ExpenseListSkeleton` (row count, light/dark mode), `ScrollableFill`
  (fills short content to viewport height, remains pull-to-refresh-able),
  and the history row action touch targets. No existing test's expectations
  changed — the loading-state spinner assertions that exist elsewhere are
  all for per-row delete progress or the Add/Edit save buttons, not the list
  itself, so replacing the list's own loading spinner with the skeleton
  didn't require updating them.
