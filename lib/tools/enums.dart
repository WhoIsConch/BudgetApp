import 'package:flutter/material.dart';

enum ObjectManageMode { add, edit } // Normal enum

enum AmountFilterType { greaterThan, lessThan, exactly }

// Enums with values, in case I need to store them in a database
enum TransactionType {
  expense(0),
  income(1);

  const TransactionType(this.value);
  final int value;
}

enum RelativeDateRange {
  today("Today"),
  yesterday("Yesterday"),
  thisWeek("This Week"),
  thisMonth("This Month"),
  thisYear("This Year");

  const RelativeDateRange(this.name);
  final String name;

  DateTimeRange getRange({DateTime? fromDate, bool fullRange = false}) {
    DateTime now = fromDate ?? DateTime.now();
    final startOfWeek = DateTime(now.year, now.month, now.day)
        .subtract(Duration(days: now.weekday - 1));

    return switch (this) {
      RelativeDateRange.today => DateTimeRange(
          start: DateTime(now.year, now.month, now.day),
          end: DateTime(now.year, now.month, now.day + 1)),
      RelativeDateRange.yesterday => DateTimeRange(
          start: DateTime(now.year, now.month, now.day - 1),
          end: DateTime(now.year, now.month, now.day)),
      RelativeDateRange.thisWeek => fullRange
          ? DateTimeRange(
              start: startOfWeek,
              end: startOfWeek.add(
                  const Duration(days: 6, hours: 23, minutes: 59, seconds: 59)))
          : DateTimeRange(start: startOfWeek, end: now),
      RelativeDateRange.thisMonth => fullRange
          ? DateTimeRange(
              start: DateTime(now.year, now.month),
              end: DateTime(now.year, now.month + 1))
          : DateTimeRange(start: DateTime(now.year, now.month), end: now),
      RelativeDateRange.thisYear => fullRange
          ? DateTimeRange(
              start: DateTime(now.year), end: DateTime(now.year + 1))
          : DateTimeRange(start: DateTime(now.year), end: now),
    };
  }
}

enum CategoryResetIncrement {
  daily(1),
  weekly(2),
  biweekly(3),
  monthly(4),
  yearly(5),
  never(0);

  const CategoryResetIncrement(this.value);
  final num value;

  factory CategoryResetIncrement.fromValue(int value) {
    return values.firstWhere((e) => e.value == value);
  }

  RelativeDateRange? getRelRange() {
    return switch (value) {
      1 => RelativeDateRange.today,
      2 => RelativeDateRange.thisWeek,
      4 => RelativeDateRange.thisMonth,
      5 => RelativeDateRange.thisYear,
      _ => null,
    };
  }

  String getText() => switch (value) {
        1 => "Day",
        2 => "Week",
        3 => "Two Weeks",
        4 => "Month",
        5 => "Year",
        0 => "Never Reset",
        _ => "Error"
      };
}

enum PageType {
  home(0),
  transactions(1);

  const PageType(this.value);
  final int value;
}

// Not by definition an enum but it works nonetheless
class AmountFilter {
  final AmountFilterType? type;
  final double? value;

  AmountFilter({this.type, this.value});

  bool isPopulated() {
    return type != null && value != null;
  }
}

final GlobalKey<ScaffoldMessengerState> scaffoldMessengerKey =
    GlobalKey<ScaffoldMessengerState>();
