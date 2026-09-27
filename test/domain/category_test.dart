import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:expense_tracker/domain/entities/expense_category.dart';
import 'package:expense_tracker/presentation/widgets/category_selector.dart';

void main() {
  group('ExpenseCategory domain and presentation mapping', () {
    test('all 9 categories have unique codes and roundtrip correctly', () {
      final codes = <String>{};
      for (final category in ExpenseCategory.values) {
        expect(
          codes.add(category.code),
          isTrue,
          reason: 'Duplicate code: ${category.code}',
        );
        expect(ExpenseCategory.fromCode(category.code), category);
      }
      expect(ExpenseCategory.values.length, 9);
    });

    test('unknown category code throws FormatException', () {
      expect(
        () => ExpenseCategory.fromCode('unknown_code'),
        throwsA(isA<FormatException>()),
      );
      expect(
        () => ExpenseCategory.fromCode(''),
        throwsA(isA<FormatException>()),
      );
    });

    test('every category has a meaningful, unique display name', () {
      final names = <String>{};
      for (final category in ExpenseCategory.values) {
        expect(category.displayName.isNotEmpty, isTrue);
        expect(names.add(category.displayName), isTrue);
        expect(category.displayName[0], category.displayName[0].toUpperCase());
      }
    });

    test('every category has an icon in category_selector', () {
      final icons = <IconData>{};
      for (final category in ExpenseCategory.values) {
        final icon = iconForCategory(category);
        expect(icon, isNotNull);
        expect(icons.add(icon), isTrue, reason: 'Duplicate icon for $category');
      }
    });

    test('every category has a distinct color in category_selector', () {
      final colors = <Color>{};
      for (final category in ExpenseCategory.values) {
        final color = colorForCategory(category);
        expect(color, isNotNull);
        expect(
          colors.add(color),
          isTrue,
          reason: 'Duplicate color for $category',
        );
      }
    });
  });
}
