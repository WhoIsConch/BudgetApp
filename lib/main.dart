import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:dynamic_color/dynamic_color.dart';
import 'package:budget/layouts/overview.dart';
import 'package:budget/layouts/spending_overview.dart';
import 'package:budget/layouts/account.dart';
import 'package:provider/provider.dart';
import 'package:budget/tools/enums.dart' as tools;
import 'package:budget/tools/api.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  final provider = TransactionProvider();
  provider.loadTransactions();

  SystemChrome.setPreferredOrientations([DeviceOrientation.portraitUp])
      .then(((value) {
    runApp(ChangeNotifierProvider(
        create: (context) => provider, child: const MyApp()));
  }));
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});
  @override
  Widget build(BuildContext context) {
    return DynamicColorBuilder(builder: (lightDynamic, darkDynamic) {
      return MaterialApp(
          title: 'Flutter Demo',
          home: const HomePage(),
          theme: ThemeData(
            colorScheme: lightDynamic ?? ThemeData.light().colorScheme,
          ),
          darkTheme: ThemeData(
            colorScheme: darkDynamic ?? ThemeData.dark().colorScheme,
          ),
          themeMode: ThemeMode.system);
    });
  }
}

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  int selectedIndex = 0;

  void indexCallback(tools.PageType page) {
    setState(() {
      selectedIndex = page.value;
    });
  }

  @override
  Widget build(BuildContext context) {
    ThemeData theme = Theme.of(context);

    return Scaffold(
        bottomNavigationBar: NavigationBar(
          backgroundColor: theme.appBarTheme.backgroundColor,
          selectedIndex: selectedIndex,
          onDestinationSelected: (value) {
            setState(() {
              selectedIndex = value;
            });
          },
          destinations: const [
            NavigationDestination(
              icon: Icon(Icons.home_outlined),
              label: "Home",
              selectedIcon: Icon(Icons.home),
            ),
            NavigationDestination(
              icon: Icon(Icons.paid_outlined),
              selectedIcon: Icon(Icons.paid),
              label: "Spending",
            ),
            NavigationDestination(
              icon: Icon(Icons.person_outlined),
              selectedIcon: Icon(Icons.person),
              label: "Account",
            )
          ],
        ),
        body: [
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Overview(swapCallback: indexCallback),
            ),
          ),
          const SafeArea(
              child: Padding(
            padding: EdgeInsets.all(16),
            child: TransactionsOverview(),
          )),
          const SafeArea(
              child: Padding(
            padding: EdgeInsets.all(16),
            child: Account(),
          ))
        ][selectedIndex]);
  }
}
