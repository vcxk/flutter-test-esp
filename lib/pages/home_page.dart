import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_blue_plus/flutter_blue_plus.dart';
import 'package:blue_esp/global/util.dart';
import 'dev_op_page.dart';
import 'mqtt_page.dart';
import 'package:dio/dio.dart';

class HomePage extends StatefulWidget {
  const HomePage({Key? key}) : super(key: key);

  @override
  _HomePageState createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {

  List<BluetoothDevice> devs = [];
  BluetoothState state = BluetoothState.unknown;
  bool isScaning = false;

  @override
  void initState() {
    // TODO: implement initState
    super.initState();
    // this.scan();

    FlutterBluePlus.instance.state.listen((event) {
      setState(() {
        this.state = event;
      });
    });
    FlutterBluePlus.instance.isScanning.listen((event) {
      setState(() {
        this.isScaning = event;
      });
    });
    this.scan();

  }
  var f = 0;
  scan() async  {
    setState(() {
      this.devs = [];
    });
    f += 1;
    final flag = f;
    FlutterBluePlus.instance.scan(timeout: Duration(seconds: 4)).listen((event) {
      print("${flag} scan listen");
      if (event.device.name.length == 0) { return; }
      final idx = this.devs.indexWhere((element) => element.id == event.device.id);
      if (idx >= 0) {
        this.devs[idx] = event.device;
      } else {
        this.devs.add(event.device);
      }
      setState(() {

      });
    });
  }


  Widget makeRow(String title,String value) {
    return Container(
      height: 44,
      child: Row(
        children: [
          Text(title),
          Spacer(),
          Text(value)
        ],
      ),
    );
  }

  tapDev(BluetoothDevice dev) async {
    print("click dev ${dev.name}");

    await dev.connect();
    final page = DevOpPage(dev: dev);
    await Util.nextPage(context, page);
    dev.disconnect();
    this.scan();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: CupertinoNavigationBar(
        trailing: GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: () {
            this.scan();
          },
          child: Container(
            child: Icon(CupertinoIcons.refresh_circled,size: 24,),
          ),
        ),
        leading: GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: () {
            Util.nextPage(context, MqttClientPage());
          },
          child: Container(
            child: Icon(CupertinoIcons.news,size: 24,),
          ),
        ),
      ),
      body: Container(
        padding: EdgeInsets.all(16),
        child: Column(
          children: [
            Container(
              child:Column(
                children: [
                  makeRow("状态", "${state}"),
                  makeRow("扫描中", "${isScaning}"),
                ],
              )
            ),
            Divider(),
            Expanded(child: ListView.builder(
              itemCount: devs.length,
              itemBuilder: (ctx,idx) {
                final dev = this.devs[idx];
                return GestureDetector(
                  behavior: HitTestBehavior.opaque,
                  child: makeRow(dev.name, ""),
                  onTap: () {
                    tapDev(dev);
                  },
                );
              },
            ))
          ],
        ),
      ),
    );
  }
}
