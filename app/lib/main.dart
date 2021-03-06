import 'dart:io';
import 'dart:async';
import 'package:mlkit/mlkit.dart';
import 'package:flutter/material.dart';
import 'UI/confirmModal.dart';
import 'newDrinkModal.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bluetooth_serial/flutter_bluetooth_serial.dart';
import 'UI/drinkCard.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:image_picker/image_picker.dart';
import 'listAllDrinks.dart';

// WORK DONE USING VISUAL STUDIO CODE,
// USING LIVE SHARE, SO IT WILL SHOW AS COMMIT DONE BY SAUL FOR NOW
// WILL START USING DIFFRERNT MACHINES AND DO COMMITS INDIVIDUALLY AFTER MILESTONE 1
// PUT COMMENTS SHOWING WHO WORKED ON WHAT FOR NOW
void main() => runApp(MyApp());

class MyApp extends StatelessWidget {
  // This widget is the root of your application.
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'smartMix',
      theme: ThemeData(
        primarySwatch: Colors.blue,
      ),
      home: MyHomePage(title: 'smartMix'),
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
  // ---------- WORK DONE BY SAUL ----------------
  FlutterBluetoothSerial bluetooth = FlutterBluetoothSerial.instance;
  Firestore db = Firestore.instance;

  List<BluetoothDevice> _devices = [];
  BluetoothDevice _device;
  bool _connected = false;
  bool _pressed = false;
  bool ofAge = false;
  File _file;
  FirebaseVisionTextDetector textDetector = FirebaseVisionTextDetector.instance;
  static final TextEditingController _message = new TextEditingController();
  static final TextEditingController _text = new TextEditingController();

  @override
  void initState() {
    super.initState();
    initPlatformState();
  }

  Future<void> initPlatformState() async {
    List<BluetoothDevice> devices = [];

    try {
      devices = await bluetooth.getBondedDevices();
    } on PlatformException {}

    bluetooth.onStateChanged().listen((state) {
      switch (state) {
        case FlutterBluetoothSerial.CONNECTED:
          setState(() {
            _connected = true;
            _pressed = false;
          });
          break;
        case FlutterBluetoothSerial.DISCONNECTED:
          setState(() {
            _connected = false;
            _pressed = false;
          });
          break;
        default:
          print(state);
          break;
      }
    });

    bluetooth.onRead().listen((msg) {
      setState(() {
        print('Read: $msg');
        _text.text += msg;
      });
    });

    if (!mounted) return;
    setState(() {
      _devices = devices;
    });
  }

  List<DropdownMenuItem<BluetoothDevice>> _getDeviceItems() {
    List<DropdownMenuItem<BluetoothDevice>> items = [];
    if (_devices.isEmpty) {
      items.add(DropdownMenuItem(
        child: Text('NONE'),
      ));
    } else {
      _devices.forEach((device) {
        items.add(DropdownMenuItem(
          child: Text(device.name),
          value: device,
        ));
      });
    }
    return items;
  }

  void _connect() {
    if (_device == null) {
      show('No device selected.');
    } else {
      bluetooth.isConnected.then((isConnected) {
        if (!isConnected) {
          bluetooth.connect(_device).catchError((error) {
            setState(() => _pressed = false);
          });
          setState(() => _pressed = true);
        }
      });
    }
  }

  void _disconnect() {
    bluetooth.disconnect();
    setState(() => _pressed = true);
  }

  void _writeTest() {
    bluetooth.isConnected.then((isConnected) {
      if (isConnected) {
        bluetooth.write(_message.text);
      }
    });
  }

  Future show(
    String message, {
    Duration duration: const Duration(seconds: 3),
  }) async {
    await new Future.delayed(new Duration(milliseconds: 100));
    Scaffold.of(context).showSnackBar(
      new SnackBar(
        content: new Text(
          message,
          style: new TextStyle(
            color: Colors.white,
          ),
        ),
        duration: duration,
      ),
    );
  }

  Future<void> openCamera() async {
    var file = await ImagePicker.pickImage(source: ImageSource.camera);
    setState(() {
      _file = file;
    });
  }

  void confirmModal(bool check) {
    Navigator.of(context).push(
      PageRouteBuilder(
        opaque: false,
        pageBuilder: (BuildContext context, _, __) => ConfirmModal(
              valid: check,
            ),
      ),
    );
  }

  Future<void> scanID() async {
    var labels = await textDetector.detectFromPath(_file.path);

    labels.forEach((res) {
      if (res.text.contains('AGE')) {
        var temp = res.text.split(" ");
        if (int.parse(temp.last) < 2019) {
          setState(() {
            ofAge = true;
          });
          confirmModal(true);
        } else {
          confirmModal(false);
        }
      } else if (res.text.contains('DOB')) {
        var temp = res.text.split("/");
        temp = temp.last.split("\n");
        if (int.parse(temp[0]) < 1998) {
          setState(() {
            ofAge = true;
          });
          confirmModal(true);
        } else {
          confirmModal(false);
        }
      }
    });
  }

  Future<bool> verifyID() async {
    bool result = false;

    await openCamera();
    if (_file != null) {
      await scanID();
      setState(() {
        _file = null;
      });

      return ofAge;
    }
    return result;
  }

  Widget cardData(title, tap, age) {
    return Padding(
      padding: EdgeInsets.only(left: 10),
      child: InkWell(
        onTap: () {
          showDialog(
              context: context,
              builder: (context) {
                return age == true
                    ? AlertDialog(
                        title: Text('Age Restriction'),
                        content: Container(
                          height: 100,
                          child: SingleChildScrollView(
                            child: Center(
                              child: Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                crossAxisAlignment: CrossAxisAlignment.center,
                                children: <Widget>[
                                  SizedBox(
                                    height: 10,
                                  ),
                                  Icon(Icons.error, size: 50),
                                  Text(
                                      'Must be 21 years or older to pour this drink. Verify age using ID.')
                                ],
                              ),
                            ),
                          ),
                        ),
                        actions: <Widget>[
                          FlatButton(
                            child: Text("Verify"),
                            onPressed: () async {
                              Navigator.of(context).pop();
                              bool result = await verifyID();

                              if (result) {
                                _message.text = tap;
                                _writeTest();
                              }
                              setState(() {
                                ofAge = false;
                              });
                            },
                          ),
                          FlatButton(
                            child: Text('Cancel'),
                            onPressed: () {
                              Navigator.pop(context);
                            },
                          )
                        ],
                      )
                    : AlertDialog(
                        title: Text("Pour Order"),
                        content: SingleChildScrollView(
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            crossAxisAlignment: CrossAxisAlignment.center,
                            children: <Widget>[
                              Text('Drink 1: ' + tap[0] + ' Oz'),
                              SizedBox(
                                width: 5,
                              ),
                              Text('Drink 2: ' + tap[1] + ' Oz'),
                              SizedBox(
                                width: 5,
                              ),
                              Text('Drink 3: ' + tap[2] + ' Oz')
                            ],
                          ),
                        ),
                        actions: <Widget>[
                          FlatButton(
                            child: Text("Pour"),
                            onPressed: () {
                              _message.text = tap;
                              _writeTest();
                              Navigator.pop(context);
                            },
                          ),
                          FlatButton(
                            child: Text('Cancel'),
                            onPressed: () {
                              Navigator.pop(context);
                            },
                          )
                        ],
                      );
              });
        },
        child: DrinkCard(
          title: title,
        ),
      ),
    );
  }
// ------------- END OF WORK BY SAUL ---------------

// ------------- WORK DONE BY Dong --------------
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.title),
        actions: <Widget>[
          IconButton(
            icon: Icon(Icons.add),
            onPressed: () async {
              Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (BuildContext context) {
                      return AddNewDrink();
                    },
                    fullscreenDialog: true,
                  ));
            },
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(10.0, 10.0, 10.0, 0.0),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: <Widget>[],
            ),
          ),
        ],
      ),
      drawer: Drawer(
        child: Column(children: <Widget>[
          UserAccountsDrawerHeader(
            accountName: Text('Test User'),
            currentAccountPicture: CircleAvatar(
              backgroundImage: NetworkImage(
                  'https://images.unsplash.com/photo-1518806118471-f28b20a1d79d?ixlib=rb-1.2.1&ixid=eyJhcHBfaWQiOjEyMDd9&w=1000&q=80'),
            ),
            accountEmail: Text('test@test.com'),
            decoration: BoxDecoration(
                image: DecorationImage(
                    fit: BoxFit.cover,
                    image: NetworkImage(
                      'http://sfwallpaper.com/images/technology-background-5.jpg',
                    ))),
          ),
          ListTile(
            title: Text('Home'),
            leading: Icon(Icons.home),
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => MyHomePage(title: 'smartMix'),
                ),
              );
            },
          ),
          ListTile(
            title: Text('Create Mix'),
            leading: Icon(Icons.list),
            onTap: () {},
          ),
          ListTile(
            title: Text('All Drinks'),
            leading: Icon(Icons.star), // ----------- END OF WORK DONE BY SAUL
            onTap: () {
              Navigator.push(context,
                  MaterialPageRoute(builder: (context) => ListDrinks()));
            },
          ),
        ]),
      ),
      body: SingleChildScrollView(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.start,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Row(mainAxisAlignment: MainAxisAlignment.spaceAround, children: [
              Text('Device: '),
              DropdownButton(
                items: _getDeviceItems(),
                onChanged: (value) => setState(() => _device = value),
                value: _device,
              ),
              IconButton(
                  onPressed:
                      _pressed ? null : _connected ? _disconnect : _connect,
                  icon: _connected ? Icon(Icons.close) : Icon(Icons.check)),
            ]),
            Padding(
              padding: EdgeInsets.all(15.0),
              child: Text(
                'Most Used Mix',
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 30,
                ),
              ),
            ),
            Padding(
              padding: EdgeInsets.all(10.0),
              child: InkWell(
                onTap: () {
                  _message.text = '0';
                  _writeTest();
                  print(_message.text);
                },
                child: Card(
                  shape: BeveledRectangleBorder(
                      borderRadius: BorderRadius.circular(20)),
                  child: Container(
                    width: MediaQuery.of(context).size.width,
                    height: MediaQuery.of(context).size.width / 2,
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(20),
                      boxShadow: [
                        BoxShadow(
                            color: Colors.black87,
                            blurRadius: 10,
                            offset: Offset(0, 0))
                      ],
                      image: DecorationImage(
                          fit: BoxFit.cover,
                          image: NetworkImage(
                            'https://static.independent.co.uk/s3fs-public/thumbnails/image/2018/05/22/13/gin-cocktails.jpg?w968h681',
                          )),
                    ),
                    child: Container(
                      decoration: BoxDecoration(
                          color: Color.fromRGBO(0, 0, 0, .3),
                          borderRadius: BorderRadius.circular(20)),
                      child: Center(
                        child: Text(
                          'Le Drink',
                          style: TextStyle(
                            fontSize: 40,
                            color: Colors.white,
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
            Padding(
              padding: EdgeInsets.all(15.0),
              child: Text(
                'Preset',
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 30,
                ),
              ),
            ),
            Container(
              height: 240,
              width: MediaQuery.of(context).size.width,
              child: ListView(
                scrollDirection: Axis.horizontal,
                children: <Widget>[
                  SizedBox(
                    width: 10,
                  ),
                  InkWell(
                    onTap: () {
                      _message.text = '101';
                      _writeTest();
                      print(_message.text);
                    },
                    child: DrinkCard(title: 'Drink 1'),
                  ),
                  SizedBox(
                    width: 10,
                  ),
                  InkWell(
                    onTap: () {
                      _message.text = '202';
                      print(_message.text);
                      _writeTest();
                    },
                    child: DrinkCard(title: 'Drink 2'),
                  ),
                  SizedBox(
                    width: 10,
                  ),
                  InkWell(
                    onTap: () {
                      _message.text = '303';
                      _writeTest();
                      print(_message.text);
                    },
                    child: DrinkCard(title: 'Drink 3'),
                  ),
                  SizedBox(
                    width: 10,
                  ),
                ],
              ),
            ),
            Padding(
              padding: EdgeInsets.all(15.0),
              child: Text(
                'Custom',
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 30,
                ),
              ),
            ),
            Container(
              height: 240,
              width: MediaQuery.of(context).size.width,
              child: StreamBuilder(
                stream: db
                    .collection('drinks')
                    .where('uid', isEqualTo: 'aaa')
                    .orderBy('createdAt', descending: true)
                    .snapshots(),
                builder: (context, snap) {
                  if (!snap.hasData) {
                    return Center(child: CircularProgressIndicator());
                  } else {
                    var data = snap.data.documents;
                    return data.length == 0
                        ? Center(
                            child: Text(
                              'No custom drinks. Create one.',
                              style: TextStyle(
                                  fontSize: 16, fontWeight: FontWeight.bold),
                            ),
                          )
                        : ListView.builder(
                            scrollDirection: Axis.horizontal,
                            itemCount: data.length,
                            itemBuilder: (context, index) {
                              return cardData(data[index]['title'],
                                  data[index]['tag'], data[index]['restrict']);
                            },
                          );
                  }
                },
              ),
            ),
            SizedBox(
              height: 15,
            ),
          ],
        ),
      ),
    );
  }

// ---------- END OF WORK DONE BY DONG

}
