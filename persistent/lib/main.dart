// ignore_for_file: prefer_const_constructors, prefer_const_literals_to_create_immutables

import 'dart:convert';

import 'package:english_words/english_words.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  runApp(MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<SharedPreferences>(
      future: SharedPreferences.getInstance(),
      builder:
          (BuildContext context, AsyncSnapshot<SharedPreferences> snapshot) {
        final sharedPrefs = snapshot.data;
        return ChangeNotifierProvider(
          create: (context) => MyAppState(sharedPrefs),
          child: MaterialApp(
            title: 'Namer App',
            theme: ThemeData(
              useMaterial3: true,
              colorScheme: ColorScheme.fromSeed(seedColor: Colors.deepOrange),
            ),
            home: MyHomePage(),
          ),
        );
      },
    );
  }
}

class MyAppState extends ChangeNotifier {
  MyAppState(this._sharedPrefs) {
    _loadState();
  }

  final SharedPreferences? _sharedPrefs;
  final List<WordPair> _history = [];
  final List<WordPair> _favorites = [];

  WordPair _current = WordPair.random();
  GlobalKey? _historyListKey;

  WordPair get current => _current;
  List<WordPair> get history => _history;
  List<WordPair> get favorites => _favorites;
  GlobalKey? get historyListKey => _historyListKey;

  void _loadState() {
    if (_sharedPrefs == null) {
      return;
    }

    final historyData = _sharedPrefs?.getStringList('history');
    if (historyData != null) {
      _history
          .addAll(historyData.map((e) => WordPair.fromJson(json.decode(e))));
    }

    final favoritesData = _sharedPrefs?.getStringList('favorites');
    if (favoritesData != null) {
      _favorites
          .addAll(favoritesData.map((e) => WordPair.fromJson(json.decode(e))));
    }

    final currentData = _sharedPrefs?.getString('current');
    if (currentData != null) {
      _current = WordPair.fromJson(json.decode(currentData));
    }
  }

  void _saveState() {
    if (_sharedPrefs == null) {
      return;
    }

    _sharedPrefs.setStringList(
        'history', _history.map((e) => json.encode(e.toJson())).toList());
    _sharedPrefs.setStringList(
        'favorites', _favorites.map((e) => json.encode(e.toJson())).toList());
    _sharedPrefs.setString('current', json.encode(_current.toJson()));
  }

  void getNext() {
    _history.insert(0, _current);
    final animatedList = _historyListKey?.currentState as AnimatedListState?;
    animatedList?.insertItem(0);
    _current = WordPair.random();
    _saveState();
    notifyListeners();
  }

  void toggleFavorite([WordPair? pair]) {
    pair = pair ?? _current;
    if (_favorites.contains(pair)) {
      _favorites.remove(pair);
    } else {
      _favorites.add(pair);
    }
    _saveState();
    notifyListeners();
  }

  void removeFavorite(WordPair pair) {
    _favorites.remove(pair);
    _saveState();
    notifyListeners();
  }
}

class MyHomePage extends StatefulWidget {
  @override
  State<MyHomePage> createState() => _MyHomePageState();
}

class _MyHomePageState extends State<MyHomePage> {
  var selectedIndex = 0;

  @override
  Widget build(BuildContext context) {
    var colorScheme = Theme.of(context).colorScheme;

    Widget page;
    switch (selectedIndex) {
      case 0:
        page = GeneratorPage();
        break;
      case 1:
        page = FavoritesPage();
        break;
      default:
        throw UnimplementedError('no widget for $selectedIndex');
    }

    // The container for the current page, with its background color
    // and subtle switching animation.
    var mainArea = ColoredBox(
      color: colorScheme.surfaceVariant,
      child: AnimatedSwitcher(
        duration: Duration(milliseconds: 200),
        child: page,
      ),
    );

    return Scaffold(
      body: LayoutBuilder(
        builder: (context, constraints) {
          if (constraints.maxWidth < 450) {
            // Use a more mobile-friendly layout with BottomNavigationBar
            // on narrow screens.
            return Column(
              children: [
                Expanded(child: mainArea),
                SafeArea(
                  child: BottomNavigationBar(
                    items: [
                      BottomNavigationBarItem(
                        icon: Icon(Icons.home),
                        label: 'Home',
                      ),
                      BottomNavigationBarItem(
                        icon: Icon(Icons.favorite),
                        label: 'Favorites',
                      ),
                    ],
                    currentIndex: selectedIndex,
                    onTap: (value) {
                      setState(() {
                        selectedIndex = value;
                      });
                    },
                  ),
                )
              ],
            );
          } else {
            return Row(
              children: [
                SafeArea(
                  child: NavigationRail(
                    extended: constraints.maxWidth >= 600,
                    destinations: [
                      NavigationRailDestination(
                        icon: Icon(Icons.home),
                        label: Text('Home'),
                      ),
                      NavigationRailDestination(
                        icon: Icon(Icons.favorite),
                        label: Text('Favorites'),
                      ),
                    ],
                    selectedIndex: selectedIndex,
                    onDestinationSelected: (value) {
                      setState(() {
                        selectedIndex = value;
                      });
                    },
                  ),
                ),
                Expanded(child: mainArea),
              ],
            );
          }
        },
      ),
    );
  }
}

class GeneratorPage extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    var appState = context.watch<MyAppState>();
    var pair = appState.current;

    IconData icon;
    if (appState.favorites.contains(pair)) {
      icon = Icons.favorite;
    } else {
      icon = Icons.favorite_border;
    }

    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Expanded(
            flex: 3,
            child: HistoryListView(),
          ),
          SizedBox(height: 10),
          BigCard(pair: pair),
          SizedBox(height: 10),
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              ElevatedButton.icon(
                onPressed: () {
                  appState.toggleFavorite();
                },
                icon: Icon(icon),
                label: Text('Like'),
              ),
              SizedBox(width: 10),
              ElevatedButton(
                onPressed: () {
                  appState.getNext();
                },
                child: Text('Next'),
              ),
            ],
          ),
          Spacer(flex: 2),
        ],
      ),
    );
  }
}

class BigCard extends StatelessWidget {
  const BigCard({
    Key? key,
    required this.pair,
  }) : super(key: key);

  final WordPair pair;

  @override
  Widget build(BuildContext context) {
    var theme = Theme.of(context);
    var style = theme.textTheme.displayMedium!.copyWith(
      color: theme.colorScheme.onPrimary,
    );

    return Card(
      color: theme.colorScheme.primary,
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: AnimatedSize(
          duration: Duration(milliseconds: 200),
          // Make sure that the compound word wraps correctly when the window
          // is too narrow.
          child: MergeSemantics(
            child: Wrap(
              children: [
                Text(
                  pair.first,
                  style: style.copyWith(fontWeight: FontWeight.w200),
                ),
                Text(
                  pair.second,
                  style: style.copyWith(fontWeight: FontWeight.bold),
                )
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class FavoritesPage extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    var theme = Theme.of(context);
    var appState = context.watch<MyAppState>();

    if (appState.favorites.isEmpty) {
      return Center(
        child: Text('No favorites yet.'),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.all(30),
          child: Text('You have '
              '${appState.favorites.length} favorites:'),
        ),
        Expanded(
          // Make better use of wide windows with a grid.
          child: GridView(
            gridDelegate: SliverGridDelegateWithMaxCrossAxisExtent(
              maxCrossAxisExtent: 400,
              childAspectRatio: 400 / 80,
            ),
            children: [
              for (var pair in appState.favorites)
                ListTile(
                  leading: IconButton(
                    icon: Icon(Icons.delete_outline, semanticLabel: 'Delete'),
                    color: theme.colorScheme.primary,
                    onPressed: () {
                      appState.removeFavorite(pair);
                    },
                  ),
                  title: Text(
                    pair.asLowerCase,
                    semanticsLabel: pair.asPascalCase,
                  ),
                ),
            ],
          ),
        ),
      ],
    );
  }
}

class HistoryPage extends StatefulWidget {
  const HistoryPage({Key? key}) : super(key: key);

  @override
  _HistoryPageState createState() => _HistoryPageState();
}

class _HistoryPageState extends State<HistoryPage> {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Namer App'),
      ),
      body: Consumer<MyAppState>(
        builder: (context, state, child) {
          final historyPairs = state.history;
          return historyPairs.isEmpty
              ? Center(child: Text('No history yet'))
              : AnimatedList(
                  key: state.historyListKey,
                  initialItemCount: historyPairs.length,
                  itemBuilder: (context, index, animation) {
                    final pair = historyPairs[index];
                    return SizeTransition(
                      sizeFactor: animation,
                      child: ListTile(
                        title: Text(pair.asPascalCase),
                        onTap: () {
                          state.toggleFavorite(pair);
                        },
                      ),
                    );
                  },
                );
        },
      ),
    );
  }
}
