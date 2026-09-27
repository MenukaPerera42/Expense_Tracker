/// Stable storage codes are independent of enum order and UI presentation.
enum ExpenseCategory {
  food('food', 'Food'),
  transport('transport', 'Transport'),
  shopping('shopping', 'Shopping'),
  bills('bills', 'Bills'),
  entertainment('entertainment', 'Entertainment'),
  health('health', 'Health'),
  education('education', 'Education'),
  travel('travel', 'Travel'),
  other('other', 'Other');

  const ExpenseCategory(this.code, this.displayName);
  final String code;
  final String displayName;

  static ExpenseCategory fromCode(String code) => values.firstWhere(
    (category) => category.code == code,
    orElse: () => throw FormatException('Unknown expense category: $code'),
  );
}
