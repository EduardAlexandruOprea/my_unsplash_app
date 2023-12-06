import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:http/http.dart' as http;
import 'package:url_launcher/url_launcher.dart';

Future<void> main() async {
  await dotenv.load();
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Unsplash Infinite Photos with pagination',
      theme: ThemeData(
        primarySwatch: Colors.blue,
        visualDensity: VisualDensity.adaptivePlatformDensity,
      ),
      home: const PhotoListScreen(),
    );
  }
}

class PhotoListScreen extends StatefulWidget {
  const PhotoListScreen({super.key});

  @override
  PhotoListScreenState createState() => PhotoListScreenState();
}

class PhotoListScreenState extends State<PhotoListScreen> {
  final ScrollController _scrollController = ScrollController();
  final List<Map<String, dynamic>> _photos = <Map<String, dynamic>>[];
  int _currentPage = 1;
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _loadPhotos();
    _scrollController.addListener(() {
      if (_scrollController.position.maxScrollExtent == _scrollController.offset) {
        _loadMorePhotos();
      }
    });
  }

  Future<void> _loadPhotos() async {
    setState(() => _isLoading = true);
    final List<Map<String, dynamic>> newPhotos = await _fetchPhotos(_currentPage);
    setState(() {
      _photos.addAll(newPhotos);
      _isLoading = false;
    });
  }

  Future<void> _loadMorePhotos() async {
    if (!_isLoading) {
      setState(() => _currentPage++);
      await _loadPhotos();
    }
  }

  Future<List<Map<String, dynamic>>> _fetchPhotos(int page) async {
    final String? apiKey = dotenv.env['UNSPLASH_ACCESS_KEY'];
    final Uri url = Uri.parse('https://api.unsplash.com/photos?page=$page&per_page=10&client_id=$apiKey');
    final http.Response response = await http.get(url);

    if (response.statusCode == 200) {
      final List<dynamic> body = json.decode(response.body) as List<dynamic>;
      return body.map((dynamic item) {
        return <String, dynamic>{
          'urls': item['urls'] as Map<String, dynamic>,
          'name': item['alt_description'] as String? ?? 'No Title',
          'description': item['description'] as String? ?? 'No Description',
          'artistName': item['user']['name'] as String? ?? 'No Name',
          'artistProfile': item['user']['links']['html'] as String? ?? 'No Profile'
        };
      }).toList();
    } else {
      throw Exception('Eroare la obtinerea datelor din API');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Unsplash Infinite Photos With Pagination')),
      body: Column(
        children: <Widget>[
          Expanded(
            child: GridView.builder(
              controller: _scrollController,
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 1,
              ),
              itemCount: _photos.length,
              itemBuilder: (BuildContext context, int index) {
                final Map<String, dynamic> photo = _photos[index];
                final String smallImageUrl = photo['urls']['small'] as String;
                return Padding(
                  padding: const EdgeInsets.all(8.0),
                  child: Column(
                    children: <Widget>[
                      Image.network(
                        smallImageUrl,
                        fit: BoxFit.cover,
                      ),
                      Text('Name of the picture: ${photo['name']}'),
                      Text('Description: ${photo['description']}'),
                      Text("Artist's name: ${photo['artistName']}"),
                      InkWell(
                        child: const Text("Artist's profile", style: TextStyle(color: Colors.blue)),
                        onTap: () async {
                          final String urlString = photo['artistProfile'] as String;
                          if (Uri.tryParse(urlString) != null && urlString != 'No Profile') {
                            await launchUrl(Uri.parse(urlString));
                          }
                        },
                      ),
                      const SizedBox(height: 1.5),
                    ],
                  ),
                );
              },
            ),
          ),
          if (_isLoading) const Center(child: CircularProgressIndicator()),
        ],
      ),
    );
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }
}
