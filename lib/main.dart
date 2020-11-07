import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:permissions_plugin/permissions_plugin.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:wifi_iot/wifi_iot.dart';


void main() {
  runApp(MyApp());
}

class MyApp extends StatelessWidget {
  // This widget is the root of your application.
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'HotOrNot',
      theme: ThemeData(
        primarySwatch: Colors.blue,
        visualDensity: VisualDensity.adaptivePlatformDensity,
      ),
      home: MyHomePage(title: 'HotOrNot'),
    );
  }
}

class MyHomePage extends StatefulWidget {
  MyHomePage({Key key, this.title}) : super(key: key);

  final String title;

  @override
  _MyHomePageState createState() => _MyHomePageState();
}

class _MyHomePageState extends State<MyHomePage> {

  List<Position> positions = [ ];
  Position position;

  savedAlert(BuildContext context, saveFlag) {
    AlertDialog alert = AlertDialog(
      title: Text("Saved"),
      content: Text(saveFlag ? "Successfully saved the location." : "Unable to save the location."),
    );
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return alert;
      },
    );
  }

  void savePositions(String positionsString) async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    bool isStored = await prefs.setString('Positions', positionsString);
    if(isStored) {
      savedAlert(context, true);
    } else {
      savedAlert(context, false);
    }
  }

  void loadPositions() async {
    SharedPreferences perfs = await SharedPreferences.getInstance();
    String positionsString = perfs.getString('Positions');
    List<Position> loadedPosList = [];
    for(var position in jsonDecode(positionsString)) {
      loadedPosList.add(Position.fromMap(position));
    }
    setState(() {
      positions = loadedPosList;
    });
  }

  void checkLocationPerms() async {
    GeolocationStatus geolocationStatus  = await Geolocator().checkGeolocationPermissionStatus();
    if(geolocationStatus == GeolocationStatus.granted) {
      return;
    } else {
      await PermissionsPlugin.requestPermissions([
        Permission.ACCESS_FINE_LOCATION,
        Permission.ACCESS_COARSE_LOCATION
      ]);
      checkLocationPerms();
    }
  }

  void _getUserPosition() async {
    checkLocationPerms();
    Position userLocation = await Geolocator().getCurrentPosition(desiredAccuracy: LocationAccuracy.high);
    setState(() {
      position = userLocation;
      positions.add(position); // Add this to top of stack.
    });
    savePositions(jsonEncode(this.positions));
  }

  void removePosition(int index) async {
    this.positions.removeAt(index);
    setState(() {
      positions = this.positions;
    });
  }

  void chooseNetwork(bool flag) {
    if(flag) {
      WiFiForIoTPlugin.isEnabled().then((val) {
        if(!val) {
          WiFiForIoTPlugin.setEnabled(true);
        }
      });
    } else {
      WiFiForIoTPlugin.isEnabled().then((val) {
        if(val) {
          WiFiForIoTPlugin.setEnabled(false);
        }
      });
    }
  }

  void getUserPosition() async {
    bool flag = false;
    List<double> distances = [ ];
    checkLocationPerms();
    Position userLocation = await Geolocator().getCurrentPosition(desiredAccuracy: LocationAccuracy.high);
    for(var position in this.positions) {
      double distance = await Geolocator().distanceBetween(position.latitude, position.longitude, userLocation.latitude, userLocation.longitude);
      distances.add(distance);
    }
    for(var distance in distances) {
      if(distance < 10) {
        flag = true;
        break;
      }
    }
    chooseNetwork(flag);
  }

  void checkLocation() async {
    Timer.periodic(Duration(seconds: 5), (timer) {
      getUserPosition();
    });
  }

  @override
  void initState() {
    super.initState();
    this.loadPositions();
    this.checkLocation();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.title),
        actions: <Widget> [
            IconButton(
              icon: Icon(Icons.location_on),
              tooltip: 'Get current location',
              onPressed: () {
                _getUserPosition();
              },
            )
        ]
      ),
      body: new ListView.builder(
        itemCount: this.positions.length,
        itemBuilder: (BuildContext ctxt, int index) {
          return new ListTile(
            title: Text(this.positions[index].toString()),
            trailing: IconButton(icon: Icon(Icons.close), onPressed: () {
              removePosition(index);
            }),
          );
        }
      )
    );
  }
}
