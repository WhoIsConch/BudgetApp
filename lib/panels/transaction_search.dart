import 'package:budget/components/transactions_list.dart';
import 'package:budget/tools/api.dart';
import 'package:budget/tools/enums.dart';
import 'package:budget/tools/filters.dart';
import 'package:budget/tools/validators.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

class TransactionSearch extends StatefulWidget {
  final List<TransactionFilter>? initialFilters;
  final Sort? initialSortType;

  const TransactionSearch(
      {super.key, this.initialFilters, this.initialSortType});

  @override
  State<TransactionSearch> createState() => _TransactionSearchState();
}

class _TransactionSearchState extends State<TransactionSearch> {
  // Making filters a Set ensures that all items are unique and there is not
  // a multiple of a filter in there
  late List<TransactionFilter> filters;
  late Sort sort;
  bool isSearching = false; // Is the title bar a search field?
  TextEditingController searchController = TextEditingController();

  List<Widget> getFilterChips() {
    List<Widget> chips = [];
    DateFormat dateFormat = DateFormat('MM/dd');

    for (TransactionFilter filter in filters) {
      String label = switch (filter) {
        TransactionFilter<String> t => "\"${t.value}\"", // "Value"
        TransactionFilter<AmountFilter> t =>
          "${t.value.type!.symbol} \$${formatAmount(t.value.amount ?? 0, exact: true)}", // > $Value
        TransactionFilter<List<Category>> t => t.value.length > 3
            ? "${t.value.length} categories"
            : t.value.map((e) => e.name).join(", "),
        TransactionFilter<DateTimeRange> t =>
          "${dateFormat.format(t.value.start)}–${dateFormat.format(t.value.end)}",
        TransactionFilter<RelativeDateRange> t =>
          "${dateFormat.format(t.value.getRange().start)}–${dateFormat.format(t.value.getRange().end)}",
        TransactionFilter<TransactionType> t =>
          t.value == TransactionType.expense ? "Expense" : "Income",
        _ => "ERR ${filter.value}"
      };

      chips.add(GestureDetector(
        onTap: () => _activateFilter(filter.value.runtimeType),
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
    AmountFilter amountFilter =
        getFilterValue<AmountFilter>(filters) ?? AmountFilter();
    // Update the text to match
    controller.text = amountFilter.amount?.toStringAsFixed(2) ?? "";

    // Listen for changes on the controller since it's easier and better-looking
    // than redoing it in the end, though probably less performant
    controller.addListener(() => amountFilter = AmountFilter(
        type: amountFilter.type,
        amount: double.tryParse(controller.text) ?? amountFilter.amount));

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
                        amountFilter = AmountFilter(
                            type: type.first, amount: amountFilter.amount);
                      }),
                      showSelectedIcon: false,
                      selected: {amountFilter.type ?? AmountFilterType.exactly},
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

                      return Navigator.pop(context,
                          TransactionFilter<AmountFilter>(amountFilter));
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
        getFilterValue<List<Category>>(filters) ?? [];

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
    TransactionType? typeFilterValue = getFilterValue<TransactionType>(filters);
    TransactionFilter? filter;

    if (typeFilterValue == null || typeFilterValue == TransactionType.expense) {
      filter = const TransactionFilter<TransactionType>(TransactionType.income);
    } else if (typeFilterValue == TransactionType.income) {
      filter =
          const TransactionFilter<TransactionType>(TransactionType.expense);
    }

    setState(() {
      if (filter == null) {
        removeFilter<TransactionType>(filters);
      } else {
        updateFilter(filter, filters);
      }
    });
  }

  List<Widget> get filterMenuButtons => [
        MenuItemButton(
          child: const Text("Date"),
          onPressed: () => _activateFilter(DateTimeRange),
        ),
        MenuItemButton(
          child: const Text("Amount"),
          onPressed: () => _activateFilter(AmountFilter),
        ),
        MenuItemButton(
          child: const Text("Type"),
          onPressed: () => _activateFilter(TransactionType),
        ),
        MenuItemButton(
          child: const Text("Category"),
          onPressed: () => _activateFilter(List<Category>),
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

  Map<Type, Function> get _filterActions => {
        DateTimeRange: () => showDateRangePicker(
                    context: context,
                    initialDateRange: getFilterValue<DateTimeRange>(filters),
                    firstDate:
                        DateTime.now().subtract(const Duration(days: 365 * 10)),
                    lastDate:
                        DateTime.now().add(const Duration(days: 365 * 10)))
                .then((DateTimeRange? value) {
              if (value == null) return;

              setState(() => updateFilter(
                  TransactionFilter<DateTimeRange>(value), filters));
            }),
        String: () => setState(() => isSearching = true),
        AmountFilter: () => _showAmountFilterDialog(context).then((value) {
              if (value == null) {
                return;
              }
              setState(() => updateFilter(
                  value as TransactionFilter<AmountFilter>, filters));
            }),
        TransactionType: () => toggleTransactionType(),
        List<Category>: () => _showCategoryInputDialog(context).then((value) {
              if (value == null) {
                return;
              } else if (value.isEmpty) {
                setState(
                  () => removeFilter<List<Category>>(filters),
                );
              } else {
                setState(() => updateFilter(
                    TransactionFilter<List<Category>>(value), filters));
              }
            }),
      };

  void _activateFilter(Type type) {
    final action = _filterActions[type];

    if (action != null) {
      action();
    } else {
      throw FilterTypeException(type);
    }
  }

  @override
  void initState() {
    super.initState();

    // Initialize these filters to easily use and edit inside of the menus
    filters = widget.initialFilters ?? [];
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

            TransactionFilter filter = TransactionFilter<String>(text);

            if (filters.contains(filter) || filter.value.isEmpty) {
              // The list of filters already has the exact same filter,
              // so we don't do anything other than stop searching.
              setState(() => isSearching = false);
              return;
            }

            setState(() {
              isSearching = false;
              updateFilter(filter, filters);
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
