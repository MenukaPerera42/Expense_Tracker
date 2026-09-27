Flutter performance review — 2026-09-28

This is a source review with automated regression checks, not a device profile.
No frame-time, heap-size, or billed-read improvement is claimed without measurement.

Two changes have a direct, bounded benefit:

- `lib/domain/usecases/expense_chart_data.dart`: monthly chart totals now use one
  scan and one totals array. Previously each displayed month built a complete
  summary, including category totals and sorted recent transactions that the
  chart discarded. Work is now O(n + monthsBack), with O(monthsBack) working
  storage. Local calendar month handling, zero months, and chronological output
  are preserved.
- `lib/presentation/providers/expense_providers.dart`: filtering/sorting has its
  own cached provider, so each debounced search scans the existing ordered result
  without sorting it again. Selecting the normalized query also skips recalculation
  for equivalent case/whitespace edits. This retains one extra list of expense
  references while searching; expense objects are not duplicated.

| Area | Finding and decision |
| --- | --- |
| Dashboard Firestore reads | Summary and chart providers transform `expenseListProvider` data synchronously. Month navigation does not query Firestore. All consumers share one repository listener per provider instance. |
| Invalidation | Pull-to-refresh and Retry explicitly recreate the expense listener. Saving/deleting relies on stream updates, without redundant invalidation. Edit deliberately fetches an individual document from the server; transactions also read their target document. Those reads preserve freshness and write preconditions. |
| Search/filter rebuilds | Search already debounces for 300 ms. The history consumer rebuilds when results change, which is expected. Const search/filter children avoid parent-driven rebuilds, and delete-state selection limits updates to the affected row. Repeated sorting and semantically equivalent searches were addressed above. |
| List rendering | History uses `ListView.builder` with item count and expense-ID keys, inside `Expanded`, without shrink wrapping. Skeleton rows are also built lazily. Dashboard recent transactions are capped at five and categories are enum-bounded, so its ordinary `ListView` is appropriate. No forced fixed row height was added because text scaling changes row height. |
| Charts | Monthly series has six points; daily/weekly series have at most 31/five points. Category slices are bounded by the category enum. Analytics timeframe changes rebuild the summary/category widgets too, but the small fixed tree does not justify further refactoring without a profile. No speculative repaint boundaries or animation removal. |
| Calculations | Summary computation still scans expenses and sorts the selected month's records for its five recent entries. Filtering runs when data or filters change; search scans matching records. These remain synchronous. Profile representative large histories before adding isolates or indexes. |
| Images | No raster image loading, decoded-image cache, or byte-buffer image patterns were found in `lib`. Avatars use text/icons. No image optimization is needed. |
| Widget complexity | No intrinsic-layout or backdrop-filter hotspot was found. Cards/shadows and chart gradients may incur paint cost, but source inspection alone does not show jank. Form controller listeners rebuild the form and notify its parent on each edit; narrowing that is lower priority than the data work above. |
| Stream cleanup | Repository cancellation releases both Firebase auth and query subscriptions. Auth changes/errors stop the old listener. Search cancels its timer and disposes its text controller. Forms dispose their controllers; the router disposes its refresh notifier. The expense stream intentionally survives route changes. |
| Async work | Firebase initialization and repository calls are awaited outside widget build work; duplicate submit/delete calls are guarded while pending. Add/edit controllers are auto-disposed but set state after awaits without checking `ref.mounted`; navigation during a pending write merits a separate lifecycle regression/fix. |

Remaining findings, ordered by priority:

1. **Session lifecycle needs follow-up.** `expenseListProvider` depends on the
   repository future, which does not change with user identity. The repository
   closes its stream when auth changes, but a subsequent login does not directly
   invalidate/recreate the retained provider. Fresh subscription therefore depends
   on retry/refresh behavior rather than the new session. Add explicit user-ID
   scoping and a logout → login-as-another-user regression test. Retain listener
   sharing within a session. This is a correctness issue, not a measured speedup;
   it was not mixed into the two performance changes.
2. **Unbounded history is the main scaling limit.** The repository query orders
   the entire expense collection without a limit. Initial subscription loads all
   records, and the app retains the decoded history plus derived lists. Snapshot
   handling also decodes the full snapshot. Lazy rows bound widget creation, not
   data memory or initial reads. Pagination would require separately designed
   historical totals/search; adding a limit alone would silently break them.
   Measure realistic account sizes before changing this architecture.
3. **Metadata events can repeat local work.** `includeMetadataChanges: true` can
   emit unchanged committed data and trigger decoding/aggregation again. It also
   lets the current pending-write gate observe write acknowledgement. Do not
   simply remove it; measure duplicate emissions before adding a deduplication
   layer and test acknowledgement behavior if doing so.
4. **Delete results can outlive their consumer.** The retained delete-state map
   is cleared by the history screen's listener. If that screen disappears during
   deletion, a finished entry may remain until later cleanup. This is a small
   retention/lifecycle risk, not evidence of a large leak.
5. **Fonts need separate validation.** The theme requests Google Fonts Poppins,
   with no bundled font assets declared in `pubspec.yaml`. Cold/offline startup
   should be measured; font-loading setup currently also causes theme test errors.
   Bundling fonts would be a packaging change, not part of this patch.

An additional correctness observation: daily/weekly aggregation reads UTC entity
date fields directly, whereas monthly aggregation uses local calendar dates.
Around local midnight/month boundaries those charts can disagree. This predates
the review and was not changed as a performance optimization.

Validation:

- `flutter analyze`: eight pre-existing diagnostics (one unused local and seven
  deprecated `withOpacity` calls), all in unchanged files. The unchanged HEAD
  checkout produces the same diagnostics.
- `flutter test`: 213 passing, 17 failures reported, plus four theme tests marked
  incomplete. An isolated unchanged HEAD checkout has 211 passing and the exact
  same 21 failure/incomplete entries. The two additional passing tests are the
  new regressions. Existing failures include outdated UI finders, navigation
  overflow at large text sizes, and Google Fonts binding setup.
- Focused chart-data, expense-provider, and repository tests: **42 passed**.
  These cover single-listener reuse while changing month/filter/search, no
  one-shot repository reads from derived views, retention across consumer removal,
  cancellation on container disposal, normalized-query reuse, and chart totals
  across year/window boundaries.
- `git diff --check`: clean.
- Device integration tests, production Firestore billing, and profile-mode frame
  timing were not run. The review does not claim the full test suite is green.
