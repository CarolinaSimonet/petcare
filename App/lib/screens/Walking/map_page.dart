import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:location/location.dart';
import 'package:petcare/screens/Walking/camara.dart';
import 'package:petcare/screens/data/animal.dart';
import 'package:url_launcher/url_launcher.dart';
import 'dart:async';
import 'dart:io';
import 'package:camera/camera.dart';
import 'package:path_provider/path_provider.dart';

class MapPage extends StatefulWidget {
  @override
  _MapPageState createState() => _MapPageState();
}

class _MapPageState extends State<MapPage> {
  final MapController _mapController = MapController();
  final Location _location = Location();
  late Stream<LocationData> _locationStream;
  Animal? _selectedAnimal;
  List<Marker> markers = [];
  List<LatLng> points = [];
  Timer? _timer;
  int _seconds = 0;
  String get _formattedTime =>
      '${(_seconds ~/ 3600).toString().padLeft(2, '0')}:${((_seconds % 3600) ~/ 60).toString().padLeft(2, '0')}:${(_seconds % 60).toString().padLeft(2, '0')}';

  bool _isTracking = false;
  List<CameraDescription>? cameras;
  CameraController? _cameraController;
  Future<void>? _initializeCameraFuture;
  @override
  void dispose() {
    _cameraController?.dispose();
    super.dispose();
  }

  @override
  void initState() {
    super.initState();
    _initCamera();
    _locationStream = _location.onLocationChanged;
    _location.requestPermission().then((granted) {
      if (granted != PermissionStatus.granted) {
        throw Exception('Location permission not granted');
      }
    });
    if (_selectedAnimal == null) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _showAnimalChoiceDialog();
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
            builder: (ctx) => Container(
              child: Icon(Icons.location_on, size: 40.0, color: Colors.red),
            ),
          ),
        ];
      });
    });
  }

  void _initCamera() async {
    cameras = await availableCameras();
    if (cameras != null && cameras!.isNotEmpty) {
      _cameraController = CameraController(cameras![0], ResolutionPreset.low);
      _initializeCameraFuture = _cameraController!.initialize();
    }
  }

  Future<void> _takePicture() async {
    if (!_cameraController!.value.isInitialized) {
      print('Controller is not initialized');
      return;
    }

    try {
      await _initializeCameraFuture;
      final image = await _cameraController!.takePicture();
      final directory = await getApplicationDocumentsDirectory();
      final imagePath =
          '${directory.path}/${DateTime.now().toIso8601String()}.jpg';
      final imageFile = File(imagePath);
      await imageFile.writeAsBytes(await image.readAsBytes());

      showDialog(
        context: context,
        builder: (context) => AlertDialog(
          content: Text('Picture saved to $imagePath'),
        ),
      );
    } catch (e) {
      print('Error taking picture: $e');
    }
  }

  Future<void> _showAnimalChoiceDialog() async {
    final animals = await fetchAnimals();
    if (!mounted) return;
    showDialog(
      context: context,
      barrierDismissible: false, // User must tap a button!
      builder: (BuildContext context) {
        return AlertDialog(
          insetPadding: EdgeInsets.symmetric(horizontal: 10.0, vertical: 10.0),
          title: const Text(' Com que vais passear ?'),
          content: SingleChildScrollView(
            child: ListBody(
              children: animals
                  .map((animal) => ListTile(
                        contentPadding: EdgeInsets.symmetric(
                            horizontal: 10.0, vertical: 5.0),
                        leading: CircleAvatar(
                          radius: 60, // Size of the circle
                          backgroundImage: Image.asset(
                            'assets/${animal.image}',
                            fit: BoxFit.cover,
                          ).image,
                        ),
                        title: Text(animal.name),
                        onTap: () {
                          // Do something when an animal is tapped
                          Navigator.of(context).pop();
                        },
                      ))
                  .toList(),
            ),
          ),
        );
      },
    );
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
                builder: (ctx) => Container(
                  child: Icon(Icons.location_on, size: 40.0, color: Colors.red),
                ),
              ),
            ];
          }
          _mapController.move(newLocation, 18.0);
        });
        _timer = Timer.periodic(Duration(seconds: 1), (Timer t) {
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

  void _showAlertDialog() {
    if (!mounted) return; // Ensure the context is still valid
    showDialog(
      context: context,
      barrierDismissible:
          true, // Prevents closing the dialog by tapping outside it.
      builder: (BuildContext context) {
        return AlertDialog(
          title: Center(child: Text('Tempo do DogReal')),
          actions: <Widget>[
            Center(
              child: Column(
                children: [
                  Text('Memorize este momento'),
                  SizedBox(height: 40),
                  ElevatedButton(
                    onPressed: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(builder: (context) => CameraWidget()),
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
          builder: (ctx) => Container(
            child: Icon(Icons.location_on, size: 40.0, color: Colors.red),
          ),
        ),
      ];
    });
    _mapController.move(newLocation, 18.0);
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
      points.clear();
      markers.clear();
      updateLocation(lastLocation);
      _finalizeAlertDialog();
      // Reset timer
    });
  }

  void _finalizeAlertDialog() {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: Text('Terminar'),
          content: Text('Tem a certeza que pertende terminar o seu passeio'),
          actions: <Widget>[
            IconButton(
              icon: Icon(Icons.close),
              onPressed: () {
                Navigator.of(context).pop(); // Close the dialog
                // Implement your camera functionality here
              },
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
            options: MapOptions(
                center: LatLng(51.5, -0.09), // Default center
                zoom: 18.0,
                maxZoom: 18.0),
            children: [
              TileLayer(
                urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                subdomains: ['a', 'b', 'c'],
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
                            shape: CircleBorder()),
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
      ]),
    );
  }
}