import 'package:flutter/material.dart';
import 'package:budget/components/transactions_list.dart';
import 'package:budget/components/transaction_form.dart';

class TransactionsPage extends StatefulWidget {
  const TransactionsPage({super.key, this.startingDateRange});

  final DateTimeRange? startingDateRange;

  @override
  State<TransactionsPage> createState() => _TransactionsPageState();
}

class _TransactionsPageState extends State<TransactionsPage> {
  DateTimeRange? dateRange;

  @override
  void initState() {
    super.initState();
  }

  Widget datePickerButton() {
    String buttonText = "All Transactions";

    if (dateRange != null) {
      buttonText =
          "${dateRange!.start.month}/${dateRange!.start.day}/${dateRange!.start.year} - ${dateRange!.end.month}/${dateRange!.end.day}/${dateRange!.end.year}";
    }

    return TextButton(
        child: Text(buttonText,
            style: TextStyle(
              fontSize: Theme.of(context).textTheme.headlineSmall!.fontSize,
            )),
        onPressed: () {
          showDateRangePicker(
                  context: context,
                  initialDateRange: dateRange,
                  firstDate:
                      DateTime.now().subtract(const Duration(days: 365 * 10)),
                  lastDate: DateTime.now())
              .then((value) {
            setState(() {
              dateRange = value;
            });
          });
        });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("Transactions"), actions: [
        Padding(
          padding: const EdgeInsets.fromLTRB(0, 0, 4, 0),
          child: IconButton(
              icon: const Icon(Icons.add),
              onPressed: () async {
                await showDialog(
                    context: context,
                    builder: (context) {
                      return const TransactionManageDialog();
                    });
              }),
        )
      ]),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            datePickerButton(),
            Expanded(child: TransactionsList(dateRange: dateRange)),
          ],
        ),
      ),
    );
  }
}
