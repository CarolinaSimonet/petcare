import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:location/location.dart';
import 'package:petcare/screens/Walking/camara.dart';
import 'package:petcare/screens/data/animal.dart';
import 'package:petcare/screens/data/firebase_functions.dart';
import 'package:petcare/screens/general/navigation_bar.dart';
import 'package:url_launcher/url_launcher.dart';
import 'dart:async';
import 'package:camera/camera.dart';
import 'package:petcare/screens/Walking/auxFunctions.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class MapPage extends StatefulWidget {
  const MapPage({super.key});
  @override
  _MapPageState createState() => _MapPageState();
}

class _MapPageState extends State<MapPage> {
  final MapController _mapController = MapController();
  final Location _location = Location();
  late Stream<LocationData> _locationStream;
  List<Animal> _selectedAnimals = [];
  List<Marker> markers = [];
  List<LatLng> points = [];
  Timer? _timer;
  int _seconds = 0;
  String? imageUrl;
  Animal? selectedAnimal;
  String get _formattedTime =>
      '${(_seconds ~/ 3600).toString().padLeft(2, '0')}:${((_seconds % 3600) ~/ 60).toString().padLeft(2, '0')}:${(_seconds % 60).toString().padLeft(2, '0')}';

  bool _isTracking = false;

  Future<void>? _initializeCameraFuture;
  @override
  void dispose() {
    super.dispose();
  }

  @override
  void initState() {
    super.initState();
    if (imageUrl != null) {
      // If there's an imageUrl, you might want to do something with it
      print("Received image URL: $imageUrl");
      // You can also display the image or use it in any other required logic
    }
    _locationStream = _location.onLocationChanged;
    _location.requestPermission().then((granted) {
      if (granted != PermissionStatus.granted) {
        throw Exception('Location permission not granted');
      }
    });
    if (_selectedAnimals.isEmpty) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        print("Show Dialog");

        _showAnimalChoiceDialog().then((value) {
          if (value != null) {
            setState(() {
              _selectedAnimals = value;
            });
          }
        });
      });
    }

    _locationStream.listen((LocationData currentLocation) {
      _mapController.move(
          LatLng(currentLocation.latitude!, currentLocation.longitude!), 18.0);
      setState(() {
        points
            .add(LatLng(currentLocation.latitude!, currentLocation.longitude!));
        markers = [
          Marker(
            width: 80.0,
            height: 80.0,
            point:
                LatLng(currentLocation.latitude!, currentLocation.longitude!),
            child: Container(
              child:
                  const Icon(Icons.location_on, size: 40.0, color: Colors.red),
            ),
          ),
        ];
      });
    });
  }

  final FirebaseFirestore firestore = FirebaseFirestore.instance;
  final FirebaseAuth auth = FirebaseAuth.instance;

  Future<List<Animal>> _fetchAnimals() async {
    String userId =
        FirebaseAuth.instance.currentUser!.uid; // Get the current user's ID
    List<Animal> pets = [];

    var querySnapshot = await FirebaseFirestore.instance
        .collection('pets')
        .where('userId', isEqualTo: userId)
        .get();

    for (var doc in querySnapshot.docs) {
      pets.add(Animal.fromMap(doc.data(), doc.id));
    }

    return pets;
  }

  Future<void> _showAnimalChoiceDialog() async {
    final animals = await _fetchAnimals();
    if (!mounted) return;
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext context) {
        return AlertDialog(
          insetPadding:
              const EdgeInsets.symmetric(horizontal: 10.0, vertical: 10.0),
          title: const Text(' Com que vais passear ?'),
          content: SingleChildScrollView(
            child: ListBody(
              children: animals
                  .map((animal) => ListTile(
                        contentPadding: const EdgeInsets.symmetric(
                            horizontal: 10.0, vertical: 5.0),
                        leading: CircleAvatar(
                          radius: 60, // Size of the circle
                          backgroundImage: Image.asset(
                            animal.image,
                            fit: BoxFit.cover,
                          ).image,
                        ),
                        title: Text(animal.name),
                        onTap: () {
                          // Do something when an animal is tapped
                          selectedAnimal = animal;
                          Navigator.of(context).pop();
                        },
                      ))
                  .toList(),
            ),
          ),
        );
      },
    );

    return selectedAnimals;
  }

  void _toggleTracking() {
    setState(() {
      _isTracking = !_isTracking;
      if (_isTracking) {
        _locationStream = _location.onLocationChanged;
        _locationStream.listen((LocationData currentLocation) {
          LatLng newLocation =
              LatLng(currentLocation.latitude!, currentLocation.longitude!);
          if (_isTracking) {
            // Only add points if tracking is enabled
            points.add(newLocation);
            markers = [
              Marker(
                width: 80.0,
                height: 80.0,
                point: newLocation,
                child: Container(
                  child: const Icon(Icons.location_on,
                      size: 40.0, color: Colors.red),
                ),
              ),
            ];
          }
          _mapController.move(newLocation, 18.0);
        });
        _timer = Timer.periodic(const Duration(seconds: 1), (Timer t) {
          setState(() {
            _seconds++;
          });
          if (_seconds == 3) {
            // 180 seconds have passed
            _timer?.cancel();
            _isTracking = false;
            _showAlertDialog(); // Show the alert dialog after 3 minutes
          }
        });
      } else {
        _timer?.cancel();
      }
    });
  }

  void _showAlertDialog() async {
    final cameras = await availableCameras();
    if (!mounted) return; // Ensure the context is still valid
    showDialog(
      context: context,
      barrierDismissible:
          true, // Prevents closing the dialog by tapping outside it.
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Center(child: Text('Tempo do DogReal')),
          actions: <Widget>[
            Center(
              child: Column(
                children: [
                  const Text('Memorize este momento'),
                  const SizedBox(height: 40),
                  ElevatedButton(
                    onPressed: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                            builder: (context) => CameraWidget(
                                  onImageUrlUpdate: updateImageUrl,
                                )),
                      );
                    },
                    style: ElevatedButton.styleFrom(
                        backgroundColor: const Color.fromRGBO(93, 99, 209, 1),
                        foregroundColor: Colors.white,
                        shape: const CircleBorder()),
                    child: const Padding(
                      padding: EdgeInsets.all(10.0),
                      child: Icon(
                        Icons.camera_alt_outlined,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        );
      },
    );
  }

  void updateLocation(LatLng newLocation) {
    setState(() {
      points.add(newLocation);
      markers = [
        Marker(
          width: 80.0,
          height: 80.0,
          point: newLocation,
          child: Container(
            child: const Icon(Icons.location_on, size: 40.0, color: Colors.red),
          ),
        ),
      ];
    });
    _mapController.move(newLocation, 18.0);
  }

  void updateImageUrl(String url) {
    setState(() {
      imageUrl = url;
    });
  }

  void _stopTracking() {
    setState(() {
      _isTracking = false;
      _timer?.cancel();
      _seconds = 0;
      LatLng lastLocation;
      if (points.isNotEmpty) {
        lastLocation = points.last;
      } else {
        lastLocation = markers.last.point;
      }
      _finalizeAlertDialog();

      points.clear();
      markers.clear();
      updateLocation(lastLocation);

      // Reset timer
    });
  }

  void _finalizeAlertDialog() {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('Terminar'),
          content:
              const Text('Tem a certeza que pertende terminar o seu passeio'),
          actions: <Widget>[
            Row(
              children: [
                IconButton(
                  icon: const Icon(Icons.check_circle_outline),
                  onPressed: () {
                    double distance = calculateTotalDistance(points);
                    // Close the dialog
                    // Implement your camera functionality here
                    debugPrint(imageUrl);
                    addActivity(
                      imageUrl: imageUrl ?? "",
                      userId: FirebaseAuth.instance.currentUser!
                          .uid, // Assuming the user is logged in
                      description: 'Morning walk in the park',
                      date: DateTime.now(),
                      distance: distance,
                    );

                    // atualizar o counter da distaniac nos caes
                    for (var animal in _selectedAnimals) {
                      updateAnimalDistance(animal, distance);
                    }

                    Navigator.push(
                      context,
                      MaterialPageRoute(
                          builder: (context) => const NavigationBarScreen()),
                    );
                  },
                ),
                IconButton(
                  icon: const Icon(Icons.cancel_outlined),
                  onPressed: () {
                    Navigator.of(context).pop(); // Close the dialog
                    // Implement your camera functionality here
                  },
                ),
              ],
            ),
          ],
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Stack(children: [
        FlutterMap(
            mapController: _mapController,
            options: const MapOptions(
                center: LatLng(51.5, -0.09), // Default center
                zoom: 18.0,
                maxZoom: 18.0),
            children: [
              TileLayer(
                urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                subdomains: const ['a', 'b', 'c'],
                userAgentPackageName: 'com.example.app',
              ),
              RichAttributionWidget(attributions: [
                TextSourceAttribution(
                  'OpenStreetMap contributors',
                  onTap: () => launchUrl(
                      Uri.parse('https://openstreetmap.org/copyright')),
                ),
              ]),
              MarkerLayer(markers: markers),
              PolylineLayer(
                polylines: [
                  Polyline(
                    points: points,
                    strokeWidth: 4.0,
                    color: const Color.fromARGB(255, 0, 0, 255),
                  ),
                ],
              ),
            ]),
        Positioned(
          top: 500, // Adjust the positioning to fit your layout
          right: 10.0,
          left: 10.0,
          child: Card(
            child: Padding(
              padding: const EdgeInsets.all(8.0),
              child: Column(
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      ElevatedButton(
                        onPressed: _toggleTracking,
                        style: ElevatedButton.styleFrom(
                            backgroundColor:
                                const Color.fromRGBO(93, 99, 209, 1),
                            foregroundColor: Colors.white,
                            shape: const CircleBorder()),
                        child: Padding(
                          padding: const EdgeInsets.all(10.0),
                          child: Icon(
                              _isTracking ? Icons.pause : Icons.play_arrow),
                        ),
                      ),
                      ElevatedButton(
                        onPressed: _stopTracking,
                        style: ElevatedButton.styleFrom(
                            backgroundColor:
                                const Color.fromRGBO(93, 99, 209, 1),
                            foregroundColor: Colors.white,
                            shape: const CircleBorder()),
                        child: const Padding(
                          padding: EdgeInsets.all(10.0),
                          child: Icon(
                            Icons.stop,
                          ),
                        ),
                      ),
                    ],
                  ),
                  Column(
                    children: [
                      const Text(
                        ' Tempo de Passeio:',
                        style: TextStyle(
                          fontSize: 10.0,
                        ),
                      ),
                      Padding(
                        padding: const EdgeInsets.symmetric(vertical: 8.0),
                        child: Text(
                          ' $_formattedTime',
                          style: const TextStyle(
                            fontSize: 30.0,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ),
        Positioned(
          top: 10,
          left: 0,
          child: ElevatedButton(
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                    builder: (context) => const NavigationBarScreen()),
              );
            },
            style: ElevatedButton.styleFrom(
                backgroundColor: const Color.fromRGBO(93, 99, 209, 1),
                foregroundColor: Colors.white,
                shape: const CircleBorder()),
            child: const Padding(
              padding: EdgeInsets.all(5.0),
              child: Icon(
                Icons.arrow_back,
              ),
            ),
          ),
        ),
      ]),
    );
  }

  void updateAnimalDistance(Animal animal, double calculateTotalDistance) {
    dynamic doc = FirebaseFirestore.instance.collection('pets').doc(animal.id);
    doc.update({
      'actualKmWalk': calculateTotalDistance + animal.actualKmWalk,
    });
  }
}
