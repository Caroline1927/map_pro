import 'dart:async';
import 'dart:developer';
import 'dart:math' show cos, sqrt, asin;
import 'package:flutter_polyline_points/flutter_polyline_points.dart';
import 'package:geolocator/geolocator.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:custom_info_window/custom_info_window.dart';
import 'package:map_pro/map_style/map_style.dart';
import 'package:flutter/material.dart';

const LatLng _center = LatLng(54.4641, 17.0287);
bool isVisible = false;

class Home extends StatefulWidget {
  const Home({Key? key}) : super(key: key);

  @override
  _HomeState createState() => _HomeState();
}

class _HomeState extends State<Home> {
  final CustomInfoWindowController _customInfoWindowController =
  CustomInfoWindowController();

  PolylinePoints polylinePoints = PolylinePoints();
  Map<PolylineId, Polyline> polylines = {};
  LatLng? startLocation;
  LatLng? endLocation;

  @override
  void dispose() {
    _customInfoWindowController.dispose();
    super.dispose();
  }

  String googleApiKey = "AIzaSyDgTt2bcZuY9E80r1aglafLEyVd7g8Qcfk";
  GoogleMapController? mapController;
  Set<Marker> markers = {};

  String mapStyle = '';
  Position? _currentPosition;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Stack(
        children: [
          GoogleMap(
            mapToolbarEnabled: false,
            myLocationButtonEnabled: false,
            zoomControlsEnabled: false,
            onTap: (position) {
              _customInfoWindowController.hideInfoWindow!();
            },
            onCameraMove: (position) {
              _customInfoWindowController.onCameraMove!();
            },
            polylines: Set<Polyline>.of(polylines.values),
            zoomGesturesEnabled: true,
            initialCameraPosition: const CameraPosition(
              target: _center,
              zoom: 14.0,
            ),
            markers: markers,
            mapType: MapType.normal,
            onMapCreated: (controller) {
              _customInfoWindowController.googleMapController = controller;
              controller.setMapStyle(MapStyle.mapStyles);
              setState(() {
                mapController = controller;
              });
            },
          ),
          CustomInfoWindow(
            controller: _customInfoWindowController,
          ),
        ],
      ),
      floatingActionButton: Padding(
        padding:
        EdgeInsets.only(bottom: MediaQuery.of(context).size.height * 0.0),
        child: FloatingActionButton(
          backgroundColor: Colors.deepPurpleAccent,
          child: const Icon(
            Icons.location_searching,
            color: Colors.white,
          ),
          onPressed: () {
            setState(() {
              _getCurrentLocation();
              checkCurrentPosition();
            });
          },
        ),
      ),
    );
  }

  void checkCurrentPosition() {
    if (_currentPosition != null) {
      markers.add(Marker(
          markerId: const MarkerId('Home'),
          icon: BitmapDescriptor.defaultMarkerWithHue(
            BitmapDescriptor.hueGreen,
          ),
          position: LatLng(_currentPosition?.latitude ?? 0.0,
              _currentPosition?.longitude ?? 0.0)));
      mapController
          ?.animateCamera(CameraUpdate.newCameraPosition(CameraPosition(
        target: LatLng(_currentPosition?.latitude ?? 0.0,
            _currentPosition?.longitude ?? 0.0),
        zoom: 15.0,
      )));
    }
  }

  /// Determine the current position of the device.
  ///
  /// When the location services are not enabled or permissions
  /// are denied the `Future` will return an error.
  Future<Future<Position>?> _determinePosition() async {
    bool serviceEnabled;
    LocationPermission permission;
    serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) {
      return Future.error('Location services are disabled.');
    }
    permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
      if (permission == LocationPermission.denied) {
        return Future.error('Location permissions are denied');
      }
    }
    if (permission == LocationPermission.deniedForever) {
      return Future.error(
          'Location permissions are permanently denied, we cannot request permissions.');
    }
    return await _getCurrentLocation();
  }

  _getCurrentLocation() {
    Geolocator.getCurrentPosition(
      desiredAccuracy: LocationAccuracy.best,
    ).then((Position position) {
      setState(() {
        _currentPosition = position;
      });
    }).catchError((e) {
      print(e);
    });
  }

  double distance = 0.0;
  List<LatLng> polylineCoordinates = [];

  ListView _buildBottomNavigationMethod(
      name, address, imageURL, workHours, PointLatLng point) {
    return ListView(
      children: <Widget>[
        AspectRatio(
          aspectRatio: 16 / 10.2,
          child: Image.asset(
            imageURL,
            fit: BoxFit.fill,
          ),
        ),
        Padding(
          padding: const EdgeInsets.all(8.0),
          child: ListTile(
            leading: const Icon(Icons.maps_home_work_outlined),
            title: Text(name),
            subtitle: Text(address),
          ),
        ),
        Padding(
          padding: const EdgeInsets.only(left: 80, bottom: 20.0),
          child: Align(
              alignment: Alignment.topLeft,
              child: Text("Work hours: $workHours")),
        ),
        Padding(
          padding: const EdgeInsets.only(left: 20.0, right: 20),
          child: ElevatedButton(
              style: ElevatedButton.styleFrom(
                primary: Colors.black,
                minimumSize: const Size.fromHeight(50),
                // NEW
              ),
              onPressed: () async {
                isVisible = true;
                await getDirections(point);
                _customInfoWindowController.addInfoWindow!(
                  Container(
                    decoration: BoxDecoration(
                      color: Colors.deepPurpleAccent,
                      borderRadius: BorderRadius.circular(4),
                    ),
                    width: double.infinity,
                    height: double.infinity,
                    child: FittedBox(
                      fit: BoxFit.fitWidth,
                      child: Padding(
                        padding: const EdgeInsets.all(10.0),
                        child: Text(
                          ("Total Distance: ${distance.toStringAsFixed(2)} KM"),
                          softWrap: true,
                          style: const TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.bold,
                              color: Colors.white),
                        ),
                      ),
                    ),
                  ),
                  LatLng(point.latitude, point.longitude),
                );
                setState(() {
                  Navigator.pop(context);
                });
              },
              child: const Text(
                "Directions",
                style: TextStyle(fontSize: 14),
              )),
        )
      ],
    );
  }

  double totalDistance = 0.0;

  double calculateDistance(lat1, lon1, lat2, lon2) {
    var p = 0.017453292519943295;
    var a = 0.5 -
        cos((lat2 - lat1) * p) / 2 +
        cos(lat1 * p) * cos(lat2 * p) * (1 - cos((lon2 - lon1) * p)) / 2;
    return 12742 * asin(sqrt(a));
  }

  getDirections(PointLatLng pointLatLng) async {
    List<LatLng> polylineCoordinates = [];

    PolylineResult result = await polylinePoints.getRouteBetweenCoordinates(
      googleApiKey,
      PointLatLng(_currentPosition != null ? _currentPosition!.latitude : 0,
          _currentPosition != null ? _currentPosition!.longitude : 0),
      pointLatLng,
      travelMode: TravelMode.walking,
    );

    if (result.points.isNotEmpty) {
      for (var point in result.points) {
        polylineCoordinates.add(LatLng(point.latitude, point.longitude));
      }
    } else {
      print(result.errorMessage);
    }
    _customInfoWindowController.googleMapController = mapController;
    addPolyLine(polylineCoordinates);

    double totalDistance = 0;
    for (var i = 0; i < polylineCoordinates.length - 1; i++) {
      totalDistance += calculateDistance(
          polylineCoordinates[i].latitude,
          polylineCoordinates[i].longitude,
          polylineCoordinates[i + 1].latitude,
          polylineCoordinates[i + 1].longitude);
    }

    setState(() {
      distance = totalDistance;
    });
  }

  addPolyLine(List<LatLng> polylineCoordinates) {
    PolylineId id = const PolylineId("poly");
    Polyline polyline = Polyline(
      polylineId: id,
      color: Colors.deepPurpleAccent,
      points: polylineCoordinates,
      width: 5,
    );
    polylines[id] = polyline;
    setState(() {});
  }

  @override
  void initState() {
    addMarkers();
    super.initState();
    setState(() {
      _determinePosition();
    });
    DefaultAssetBundle.of(context).loadString('map_style.dart').then((string) {
      mapStyle = string;
    }).catchError((error) {
      log(error.toString());
    });
  }

  void mapCreated(GoogleMapController controller) {
    log(mapStyle);
    setState(() {
      mapController = controller;
      if (mapStyle != null) {
        mapController?.setMapStyle(mapStyle).then((value) {
          log("Map Style set");
        }).catchError((error) => log("Error setting map style:$error"));
      } else {
        log("GoogleMapView:_onMapCreated: Map style could not be loaded.");
      }
    });
  }

  addMarkers() async {
    markers.add(customMarker(
        const LatLng(54.468683, 17.028140),
        "Regionalne Centrum Wolontariatu",
        "aleja Henryka Sienkiewicza 6, 76-200 Słupsk",
        "images/1.jpg",
        "9:00 - 15:00",
        const PointLatLng(54.468683, 17.028140)));

    markers.add(customMarker(
        const LatLng(54.452438, 17.041785),
        "Pomeranian Academy in Slupsk",
        "Krzysztofa Arciszewskiego, 76-200 Słupsk",
        "images/2.jpg",
        "9:00 - 15:00",
        const PointLatLng(54.452438, 17.041785)));

    markers.add(customMarker(
        const LatLng(54.451206, 17.023427),
        "Municipal Family Assistance Center",
        "Słoneczna 15D, 76-200 Słupsk",
        "images/3.jpg",
        "9:00 - 15:00",
        const PointLatLng(54.451206, 17.023427)));

    markers.add(customMarker(
        const LatLng(54.458005, 17.028482),
        "Zespół Szkół Technicznych",
        "Karola Szymanowskiego 5, 76-200 Słupsk",
        "images/4.jpg",
        "9:00 - 15:00",
        const PointLatLng(54.458005, 17.028482)));

    setState(() {
      //refresh UI
    });
  }

  Marker customMarker(LatLng latLng, String name, String address, String image,
      String workHours, PointLatLng pointLatLng) {
    return Marker(
        markerId: MarkerId(latLng.toString()),
        position: latLng,
        infoWindow: const InfoWindow(
          //popup info
          // title: "Regionalne Centrum Wolontariatu",
          // snippet: "aleja Henryka Sienkiewicza 6, 76-200 Słupsk",
        ),
        icon: BitmapDescriptor.defaultMarker,
        onTap: () {
          showModalBottomSheet(
              isScrollControlled: true,
              context: context,
              builder: (builder) {
                return Wrap(children: <Widget>[
                  SizedBox(
                    height: MediaQuery.of(context).size.height * 0.60,
                    child: _buildBottomNavigationMethod(
                        name, address, image, workHours, pointLatLng),
                  ),
                ]);
              });
        } //Icon for Marker
    );
  }
}
