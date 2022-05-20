import 'dart:async';
import 'dart:convert';

import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_blue_plus/flutter_blue_plus.dart';

import 'package:flutter_easyloading/flutter_easyloading.dart';

class DevOpPage extends StatefulWidget {

  const DevOpPage({Key? key,required this.dev}) : super(key: key);

  final BluetoothDevice dev;

  @override
  _DevOpPageState createState() => _DevOpPageState();
}

class _DevOpPageState extends State<DevOpPage> {

  var tc_wifi_ssid = TextEditingController(text: "");
  var tc_wifi_pwd = TextEditingController(text: "");
  var tc_mqtt_uri = TextEditingController(text: "");
  var tc_mqtt_user = TextEditingController(text: "");
  var tc_mqtt_pwd = TextEditingController(text: "");
  var tc_device_sn = TextEditingController(text: "");

  late BluetoothCharacteristic rw_ch;

  StreamSubscription? notifysub;

  List<int> rcvData = [];

  @override
  void initState() {
    // TODO: implement initState
    super.initState();

    this.widget.dev.discoverServices().then((services) {
      for (final s in services) {
        print("${s}");
        for (final c in s.characteristics) {
          if (c.properties.read && c.properties.write && c.properties.notify) {
            print("get read write ch ${c}");
            this.rw_ch = c;
            c.setNotifyValue(true);
            this.notifysub = c.value.listen((event) {
              this.rcvData.addAll(event);
              var l = List<int>.from(this.rcvData);
              if (l.length == 0 || (l.last != 0 && l.last != 10)) { return; }
              this.rcvData = [];
              if(l.last == 0) { l.removeLast(); }
              if (l.last == 10) {l.removeLast(); }
              var str =utf8.decode(l);
              final index = str.indexOf(":");
              if (index < 0) { return; }
              final flag = int.parse(str.substring(0,index),onError: (err) => 0);
              final comp = this.repos.remove(flag);
              var value = str.substring(index + 1);
              comp?.complete(value);
            });
          }
        }
      }
    });
  }

  var f = 1;
  Map<int,Completer<String?>> repos = {};
  Future<String?> blue_cmd(String cmd, {String? value}) {
    var flag = f++;
    var command = value == null ? "${cmd}:${flag}\n" : "${cmd}:${flag}=${value}\n";
    this.rw_ch.write(utf8.encode(command));
    final comp = Completer<String?>();
    repos[flag] = comp;
    Future.delayed(Duration(seconds: 5)).then((value) => repos.remove(flag)?.complete(null));
    return comp.future;
  }

  @override
  void dispose() {
    // TODO: implement dispose
    super.dispose();
    this.notifysub?.cancel();
  }

  refreshValue() async {
    EasyLoading.show(maskType: EasyLoadingMaskType.clear);
    try {
      final cmds = ["wifi_ssid","wifi_pwd","mqtt_uri","mqtt_username","mqtt_password","device_sn"];
      List<Future<String?>> fs = [];
      for (final cmd in cmds) {
        fs.add(blue_cmd(cmd));
        await Future.delayed(Duration(milliseconds: 100));
      }
      final res = await Future.wait(fs);
      setState(() {
        print("${res[0]},${res[1]},${res[2]},${res[3]},${res[4]},${res[5]}");
        this.tc_wifi_ssid = TextEditingController(text: res[0] ?? "");
        this.tc_wifi_pwd = TextEditingController(text: res[1] ?? "");
        this.tc_mqtt_uri = TextEditingController(text: res[2] ?? "");
        this.tc_mqtt_user = TextEditingController(text: res[3] ?? "");
        this.tc_mqtt_pwd = TextEditingController(text: res[4] ?? "");
        this.tc_device_sn = TextEditingController(text: res[5] ?? "");
        print(tc_wifi_ssid.text);
      });
    }catch(err) {

    } finally {
      EasyLoading.dismiss();
    }
  }

  Widget makeRow(String label,TextEditingController tc,{String btnText = "设置",void Function()? click}) {
    return Container(
      // height: 64,
      margin: EdgeInsets.symmetric(vertical: 12),
      child: TextFormField(
        controller: tc,
        decoration: InputDecoration(
          label: Container(
            child: Text(label),
          ),
          suffixIcon: click == null ? null : TextButton(onPressed: click ?? (){}, child: Text(btnText))
        ),
      ),
    );
  }

  loadingSet(String cmd,String value) async {
    EasyLoading.show(maskType: EasyLoadingMaskType.clear);
    final r = await blue_cmd(cmd,value: value);
    EasyLoading.dismiss();
    showDialog(context: context, builder: (ctx){
      return CupertinoAlertDialog(
        title: Text(r ?? "timeout"),
      );
    });
  }


  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: CupertinoNavigationBar(
        middle: Text(widget.dev.name),
        trailing: GestureDetector(
          behavior: HitTestBehavior.opaque,
          child: Container(
            padding: EdgeInsets.all(3),
            child: Icon(CupertinoIcons.refresh_circled,size: 24,),
          ),
          onTap: () {
            this.refreshValue();
          },
        ),
      ),
      body: Container(
        padding: EdgeInsets.all(16),
        child: Column(
          children: [
            makeRow("device_sn", tc_device_sn, btnText: "Copy",click: () {
              Clipboard.setData(ClipboardData(text: tc_device_sn.text));
              showDialog(context: context, builder: (ctx) {
                return CupertinoAlertDialog(
                  title: Text("复制成功"),
                );
              });
            }),
            makeRow("wifi_ssid", tc_wifi_ssid,click: (){
              loadingSet("wifi_ssid", tc_wifi_ssid.text);
            }),
            makeRow("wifi_pwd", tc_wifi_pwd,click: (){
              loadingSet("wifi_pwd", tc_wifi_pwd.text);
            }),
            makeRow("mqtt_uri", tc_mqtt_uri,click: () {
              loadingSet("mqtt_uri", tc_mqtt_uri.text);
            }),
            makeRow("mqtt_user", tc_mqtt_user,click: () {
              loadingSet("mqtt_user", tc_mqtt_user.text);
            }),
            makeRow("mqtt_pwd", tc_mqtt_pwd,click: () {
              loadingSet("mqtt_pwd", tc_mqtt_pwd.text);
            }),
          ],
        ),
      ),
    );
  }
}
