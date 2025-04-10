import 'package:budget/components/transactions_list.dart';
import 'package:budget/tools/api.dart';
import 'package:budget/tools/enums.dart';
import 'package:budget/tools/validators.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

class TransactionSearch extends StatefulWidget {
  final Set<TransactionFilter>? initialFilters;
  final Sort? initialSortType;

  const TransactionSearch(
      {super.key, this.initialFilters, this.initialSortType});

  @override
  State<TransactionSearch> createState() => _TransactionSearchState();
}

class _TransactionSearchState extends State<TransactionSearch> {
  // Making filters a Set ensures that all items are unique and there is not
  // a multiple of a filter in there
  late Set<TransactionFilter> filters;
  late Sort sort;
  bool isSearching = false; // Is the title bar a search field?
  TextEditingController searchController = TextEditingController();

  dynamic getFilterValue(FilterType filterType) {
    try {
      return filters.singleWhere((e) => e.filterType == filterType).value;
    } on StateError {
      return null;
    }
  }

  void updateFilter(TransactionFilter newFilter) {
    filters.removeWhere((e) => e.filterType == newFilter.filterType);
    filters.add(newFilter);
  }

  List<Widget> getFilterChips() {
    List<Widget> chips = [];
    DateFormat dateFormat = DateFormat('MM/dd');

    for (TransactionFilter filter in filters) {
      String label = switch (filter.filterType) {
        FilterType.string => "\"${filter.value}\"", // "Value"
        FilterType.amount => "${switch (filter.info as AmountFilterType) {
            AmountFilterType.exactly => "=",
            AmountFilterType.lessThan => "<",
            AmountFilterType.greaterThan => ">"
          }} \$${formatAmount(filter.value, exact: true)}", // > $Value
        FilterType.category => filter.value.length > 3
            ? "${filter.value.length} categories"
            : filter.value.map((e) => e.name).join(", "),
        FilterType.dateRange =>
          "${dateFormat.format(filter.value.start)}–${dateFormat.format(filter.value.end)}",
        FilterType.type =>
          filter.value == TransactionType.expense ? "Expense" : "Income"
      };

      chips.add(GestureDetector(
        onTap: () => _activateFilter(filter.filterType),
        child: Chip(
          label: Text(label),
          deleteIcon: const Icon(Icons.close),
          onDeleted: () => setState(() {
            filters.remove(filter);
            searchController.clear();
          }),
        ),
      ));
    }

    return chips;
  }

  Widget getTitle() {
    if (isSearching) {
      return TextField(
        controller: searchController,
        decoration:
            const InputDecoration(icon: Icon(Icons.search), hintText: "Search"),
      );
    }
    return const Text("Transactions");
  }

  Future<TransactionFilter?> _showAmountFilterDialog(
      BuildContext context) async {
    // Shows a dialog inline with a dropdown showing the filter type first,
    // then the amount as an input.
    TextEditingController controller = TextEditingController();
    // Either get the current amountFilter or create a new one
    TransactionFilter amountFilter = filters.firstWhere(
        (e) => e.filterType == FilterType.amount,
        orElse: () => const TransactionFilter(
            FilterType.amount, AmountFilterType.exactly, null));
    // Update the text to match
    controller.text = amountFilter.value?.toStringAsFixed(2) ?? "";

    // Listen for changes on the controller since it's easier and better-looking
    // than redoing it in the end, though probably less performant
    controller.addListener(() => amountFilter = TransactionFilter(
        FilterType.amount,
        amountFilter.info,
        double.tryParse(controller.text) ?? amountFilter.value));

    return showDialog<TransactionFilter>(
        context: context,
        builder: (context) {
          return StatefulBuilder(
              builder: (BuildContext context, StateSetter setState) {
            return AlertDialog(
                title: const Text("Filter by Amount"),
                content: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    SegmentedButton(
                      onSelectionChanged: (type) => setState(() {
                        amountFilter = TransactionFilter(
                            FilterType.amount, type.first, amountFilter.value);
                      }),
                      showSelectedIcon: false,
                      selected: {amountFilter.info ?? AmountFilterType.exactly},
                      segments: AmountFilterType.values
                          .map((value) => ButtonSegment(
                              value: value,
                              label: Text(
                                toTitleCase(value.name),
                                maxLines: 2,
                              )))
                          .toList(),
                    ),
                    const SizedBox(height: 24),
                    Padding(
                      padding: const EdgeInsets.only(left: 8),
                      child: TextField(
                          inputFormatters: [DecimalTextInputFormatter()],
                          keyboardType: TextInputType.number,
                          controller: controller,
                          decoration: const InputDecoration(
                              hintText: "Amount",
                              prefixText: "\$ ",
                              isDense: true)),
                    ),
                  ],
                ),
                actions: [
                  TextButton(
                    onPressed: () => Navigator.pop(context, null),
                    child: const Text("Cancel"),
                  ),
                  TextButton(
                    onPressed: () {
                      if (double.tryParse(controller.text) == null) {
                        return Navigator.pop(context);
                      }

                      return Navigator.pop(context, amountFilter);
                    },
                    child: const Text("OK"),
                  )
                ]);
          });
        });
  }

  Future<List<Category>?> _showCategoryInputDialog(BuildContext context) async {
    // Shows a dropdown of all available categories.
    // Returns a list of selected categories.
    // This shows an AlertDialog with nothing in it other than a dropdown
    // which a user can select multiple categories from.
    final provider = Provider.of<TransactionProvider>(context, listen: false);

    List<Category> categories = provider.categories;
    List<Category> selectedCategories =
        getFilterValue(FilterType.category) ?? [];

    if (!context.mounted) {
      return [];
    }

    return showDialog<List<Category>>(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (BuildContext context, StateSetter setState) {
            return AlertDialog(
              scrollable: true,
              title: const Text("Select Categories"),
              content: SizedBox(
                width: double.maxFinite,
                child: ListView.builder(
                  shrinkWrap: true,
                  itemCount: categories.length,
                  itemBuilder: (BuildContext context, int index) {
                    final category = categories[index];
                    return CheckboxListTile(
                      title: Text(category.name),
                      value: selectedCategories
                          .where(
                            (e) => e.id == category.id,
                          )
                          .isNotEmpty,
                      onChanged: (bool? value) {
                        setState(() {
                          if (value != null) {
                            if (value) {
                              selectedCategories.add(category);
                            } else {
                              selectedCategories
                                  .removeWhere((e) => e.id == category.id);
                            }
                          }
                        });
                      },
                    );
                  },
                ),
              ),
              actions: [
                Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      TextButton(
                        onPressed: () =>
                            setState(() => selectedCategories = []),
                        child: Text("Clear",
                            style: TextStyle(
                                color: Theme.of(context).colorScheme.error)),
                      ),
                      TextButton(
                        onPressed: () {
                          Navigator.of(context).pop(selectedCategories);
                        },
                        child: const Text('OK'),
                      ),
                    ])
              ],
            );
          },
        );
      },
    );
  }

  void toggleTransactionType() {
    TransactionType? typeFilterValue = getFilterValue(FilterType.type);
    TransactionFilter? filter;

    if (typeFilterValue == null || typeFilterValue == TransactionType.income) {
      filter = const TransactionFilter(
          FilterType.type, TransactionType.expense, TransactionType.expense);
    } else if (typeFilterValue == TransactionType.expense) {
      filter = const TransactionFilter(
        FilterType.type,
        TransactionType.income,
        TransactionType.income,
      );
    }

    setState(() {
      filters.removeWhere((e) => e.filterType == FilterType.type);

      if (filter == null) {
        return;
      }

      filters.add(filter);
    });
  }

  List<Widget> get filterMenuButtons => [
        MenuItemButton(
          child: const Text("Date"),
          onPressed: () => _activateFilter(FilterType.dateRange),
        ),
        MenuItemButton(
          child: const Text("Amount"),
          onPressed: () => _activateFilter(FilterType.amount),
        ),
        MenuItemButton(
          child: const Text("Type"),
          onPressed: () => _activateFilter(FilterType.type),
        ),
        MenuItemButton(
          child: const Text("Category"),
          onPressed: () => _activateFilter(FilterType.category),
        ),
      ];

  List<Widget> get sortMenuButtons => SortType.values
      .map((type) => MenuItemButton(
          closeOnActivate: false,
          trailingIcon: sort.sortType == type
              ? switch (sort.sortOrder) {
                  SortOrder.ascending => const Icon(Icons.arrow_upward),
                  SortOrder.descending => const Icon(Icons.arrow_downward)
                }
              : null,
          onPressed: () {
            if (sort.sortType == type) {
              sort = Sort(
                  type,
                  sort.sortOrder == SortOrder.descending
                      ? SortOrder.ascending
                      : SortOrder.descending);
            } else {
              sort = Sort(
                type,
                SortOrder.descending,
              );
            }

            setState(() => sort = sort);
          },
          child: Text(toTitleCase(type.name))))
      .toList();

  List<Widget> get mainMenuButtons => [
        SubmenuButton(
          menuChildren: filterMenuButtons,
          child: const Text("Filter by"),
        ),
        SubmenuButton(
          menuChildren: sortMenuButtons,
          child: const Text("Sort by"),
        ),
      ];

  Widget get filterButton => MenuAnchor(
        alignmentOffset: const Offset(-40, 0),
        menuChildren: mainMenuButtons,
        builder:
            (BuildContext context, MenuController controller, Widget? child) =>
                IconButton(
                    icon: const Icon(Icons.tune),
                    onPressed: () {
                      if (controller.isOpen) {
                        controller.close();
                      } else {
                        controller.open();
                      }
                    }),
      );

  void _activateFilter(FilterType filterType) => switch (filterType) {
        FilterType.dateRange => showDateRangePicker(
                  context: context,
                  initialDateRange: getFilterValue(
                      filterType), // Should be null or a date range
                  firstDate:
                      DateTime.now().subtract(const Duration(days: 365 * 10)),
                  lastDate: DateTime.now().add(const Duration(days: 365 * 10)))
              .then((DateTimeRange? value) {
            if (value == getFilterValue(filterType) || value == null) return;

            setState(() {
              filters.removeWhere((e) => e.filterType == filterType);
              filters.add(TransactionFilter(
                  FilterType.dateRange, "Date", value.makeInclusive()));
            });
          }),
        FilterType.string => setState(() => isSearching = true),
        FilterType.amount => _showAmountFilterDialog(context).then((value) {
            if (value == null) {
              return;
            }
            setState(() {
              filters.removeWhere((e) => e.filterType == filterType);
              filters.add(value);
            });
          }),
        FilterType.type => toggleTransactionType(),
        FilterType.category => _showCategoryInputDialog(context).then((value) {
            if (value == null) {
              return;
            } else if (value.isEmpty) {
              setState(
                () => filters
                    .removeWhere((e) => e.filterType == FilterType.category),
              );
            } else {
              setState(() => updateFilter(
                  TransactionFilter(FilterType.category, "Categories", value)));
            }
          })
      };

  @override
  void initState() {
    super.initState();

    // Initialize these filters to easily use and edit inside of the menus
    filters = widget.initialFilters ?? {};
    sort = widget.initialSortType ??
        const Sort(SortType.date, SortOrder.descending);
  }

  @override
  void dispose() {
    searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    List<Widget> appBarActions = [];
    Widget body;
    Widget? leading;

    if (!isSearching) {
      appBarActions = [
        IconButton(
            icon: const Icon(Icons.search),
            onPressed: () {
              setState(() => isSearching = true);
            }),
        filterButton,
      ];
    } else {
      appBarActions = [
        IconButton(
          icon: const Icon(Icons.check),
          onPressed: () {
            String text = searchController.text.trim();

            if (text.length > 30) {
              text = "${text.substring(0, 27)}...";
            }

            TransactionFilter filter =
                TransactionFilter(FilterType.string, "Text", text);

            if (filters.contains(filter) || filter.value.isEmpty) {
              // The list of filters already has the exact same filter,
              // so we don't do anything other than stop searching.
              setState(() => isSearching = false);
              return;
            }

            setState(() {
              isSearching = false;
              filters.removeWhere((e) => e.filterType == filter.filterType);
              filters.add(filter);
            });
          },
        )
      ];

      leading = IconButton(
        icon: const Icon(Icons.close),
        onPressed: () => setState(() => isSearching = false),
      );
    }

    if (filters.isNotEmpty) {
      body = Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8.0),
            child: Wrap(
              spacing: 4,
              children: getFilterChips(),
            ),
          ),
          Expanded(
              child: TransactionsList(
            filters: filters,
            sort: sort,
          ))
        ],
      );
    } else {
      body = TransactionsList(
        sort: sort,
      );
    }

    return Scaffold(
        appBar: AppBar(
          leading: leading,
          titleSpacing: 0,
          title: getTitle(),
          actions: appBarActions,
        ),
        body: body);
  }
}
