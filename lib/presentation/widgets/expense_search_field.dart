import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../providers/expense_providers.dart';

/// Search box for the expense history list (title/note substring match).
/// Purely presentational: [ExpenseSearchEngine] does the actual matching,
/// reached through [expenseSearchQueryProvider].
///
/// Typing updates the on-screen text immediately, but the provider — and so
/// the filtered list — only updates after a short debounce, so a fast typist
/// doesn't re-filter the list on every keystroke. This is a local, in-memory
/// filter (no Firestore query either way), but debouncing keeps the pattern
/// consistent and avoids pointless rebuilds as the list grows.
class ExpenseSearchField extends ConsumerStatefulWidget {
  const ExpenseSearchField({super.key});

  @override
  ConsumerState<ExpenseSearchField> createState() => _ExpenseSearchFieldState();
}

class _ExpenseSearchFieldState extends ConsumerState<ExpenseSearchField> {
  static const _debounceDuration = Duration(milliseconds: 300);

  late final TextEditingController _controller;
  Timer? _debounce;

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController(
      text: ref.read(expenseSearchQueryProvider),
    );
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _controller.dispose();
    super.dispose();
  }

  void _onChanged(String value) {
    _debounce?.cancel();
    _debounce = Timer(_debounceDuration, () {
      ref.read(expenseSearchQueryProvider.notifier).setQuery(value);
    });
  }

  void _clear() {
    _debounce?.cancel();
    _controller.clear();
    ref.read(expenseSearchQueryProvider.notifier).clear();
    setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    // Keeps this field in sync when the query is cleared from elsewhere —
    // e.g. the "Clear search & filters" action on an empty filtered result —
    // rather than only reacting to its own suffix-icon tap.
    ref.listen<String>(expenseSearchQueryProvider, (previous, next) {
      if (next.isEmpty && _controller.text.isNotEmpty) {
        _controller.clear();
      }
    });

    return ValueListenableBuilder<TextEditingValue>(
      valueListenable: _controller,
      builder: (context, value, _) {
        return TextField(
          controller: _controller,
          onChanged: _onChanged,
          textInputAction: TextInputAction.search,
          decoration: InputDecoration(
            isDense: true,
            hintText: 'Search title or note',
            prefixIcon: const Icon(Icons.search),
            suffixIcon: value.text.isEmpty
                ? null
                : IconButton(
                    tooltip: 'Clear search',
                    icon: const Icon(Icons.clear),
                    onPressed: _clear,
                  ),
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
          ),
        );
      },
    );
  }
}
