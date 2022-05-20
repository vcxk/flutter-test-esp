import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:mqtt_client/mqtt_client.dart';
import 'package:blue_esp/global/util.dart';
import 'package:mqtt_client/mqtt_server_client.dart';

import 'package:intl/intl.dart';

class MqttClientPage extends StatefulWidget {
  const MqttClientPage({Key? key}) : super(key: key);

  @override
  _MqttClientPageState createState() => _MqttClientPageState();
}

class _MqttRcvMsg {
  _MqttRcvMsg({required this.msg});
  final time = DateTime.now();
  final MqttReceivedMessage msg;
}

class _MqttClientPageState extends State<MqttClientPage> {

  MqttServerClient _client = MqttServerClient("hk.vcxk.fun", "");
  MqttServerClient get client { return _client; }
  void set client(MqttServerClient c) {
    _client.disconnect();
    this.subTopics = [];
    _client = c;
  }

  makeNewMqttClient() { this.client = MqttServerClient(this.host, ""); }

  var host = "hk.vcxk.fun";
  static var _sn = "";
  String get sn { return _MqttClientPageState._sn; }
  void set sn(String v) { _MqttClientPageState._sn = v; }

  String get t1 { return "/esp/on/" + this.sn; }
  String get t2 { return "/esp/ack/" + this.sn; }
  String get t3 { return "/esp/time/" + this.sn; }
  List get topics { return [t1,t2,t3]; }
  var connected = false;
  List subTopics = [];
  List<_MqttRcvMsg> rcvMsgs = [];

  @override
  void initState() {
    // TODO: implement initState
    super.initState();
    connectMqtt();
  }

  connectMqtt() async {
    makeNewMqttClient();
    client.setProtocolV311();
    client.logging(on: false);
    client.keepAlivePeriod = 60;
    client.autoReconnect = true;

    client.onConnected = () { setState(() { this.connected = true; this.toSubMqttTopics(); }); };
    client.onDisconnected = () { setState(() { this.connected = false; this.subTopics = []; }); };
    client.onSubscribed = (topic) { setState(() { this.subTopics.add(topic); });};
    client.onUnsubscribed = (topic) {
      setState(() {
        this.subTopics.remove(topic);
      });
    };

    final r = await client.connect();

    client.updates?.listen((event) {
      for (final msg in event) {
        MqttPublishMessage pmsg = msg.payload as MqttPublishMessage;
        final topic = msg.topic;
        final payload = utf8.decode(pmsg.payload.message);
        print("rcv mqtt msg ${topic} : ${payload}");
        this.rcvMsgs.insert(0,_MqttRcvMsg(msg: msg));
      }
      setState(() {});
    });
  }

  toSubMqttTopics() {
    for (final t in this.topics) {
      this.client.subscribe(t,MqttQos.exactlyOnce);
    }
  }
  toUnSubMqttTopics() {
    for (final t in this.subTopics) {
      this.client.unsubscribe(t);
    }
  }

  @override
  void dispose() {
    // TODO: implement dispose
    super.dispose();
    client.disconnect();
  }

  Future<String?> inputText(String title,{String? value = null}) async {
    final tc = TextEditingController(text: value);
    return await showDialog(context: context, builder: (ctx){
      return CupertinoAlertDialog(
        title: Text(title),
        content: Container(
          padding: EdgeInsets.symmetric(vertical: 16),
          child: CupertinoTextField(
            textAlign: TextAlign.center,
            controller: tc,
          ),
        ),
        actions: [
          CupertinoDialogAction(child: Text("Cancel"),onPressed: (){
            Navigator.of(ctx).pop();
          },),
          CupertinoDialogAction(child: Text("OK"),onPressed: (){
            Navigator.of(ctx).pop(tc.text);
          },)
        ],
      );
    });
  }

  @override
  Widget build(BuildContext context) {
    
    final df = DateFormat("HH:mm:ss");
    final list = ListView.builder(
      itemCount: this.rcvMsgs.length,
      itemBuilder: (ctx,idx) {
        final msg = this.rcvMsgs[idx].msg;
        MqttPublishMessage pmsg = msg.payload as MqttPublishMessage;
        final time = this.rcvMsgs[idx].time;
        final topic = msg.topic;
        var payload = utf8.decode(pmsg.payload.message);
        // final sn = topic.split("/").last;
        // final op = topic.split("/")[1];
        if (topic.contains("time")) {
          final ts = int.parse(payload);
          final dt = DateTime.fromMillisecondsSinceEpoch(ts);
          payload = "${payload} -> ${df.format(dt)}";
        }
        return Column(
          children: [
            Container(
              padding: EdgeInsets.all(8),
              margin: EdgeInsets.symmetric(vertical: 8),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.all(Radius.circular(8)),
                color: Colors.grey
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  SizedBox(height: 5,),
                  Row(
                    children: [
                      Text(msg.topic,style: TextStyle(fontWeight: FontWeight.bold),),
                      SizedBox(width: 5,),
                      Text("(${df.format(time)})",style: TextStyle(fontSize: 12),),
                      Spacer(),
                      Text(pmsg.header?.retain ?? false ? "retained" : "")
                    ],
                  ),
                  SizedBox(height: 10,),
                  Text(payload),
                  SizedBox(height: 5,),
                ],
              ),
            )
          ],
        );
      },
    );

    return Scaffold(
      appBar: CupertinoNavigationBar(
        middle: Text("mqtt"),
      ),
      body: Container(
        padding: EdgeInsets.all(16),
        color: Colors.white12,
        child: Column(
          children: [
            Container(
              child: Row(
                children: [
                  Text("MQTT 服务"),
                  Spacer(),
                  SizedBox(
                    width: 175,
                    child: OutlinedButton(onPressed: (){
                      inputText("MQTT 服务器",value: this.host).then((value) => setState((){
                        if (value == null) { return; }
                        this.host = value;
                        this.connectMqtt();
                      }));
                    }, child: Text("${host}")),
                  ),
                  SizedBox(
                    width: 40,
                    child: connected ? Icon(CupertinoIcons.check_mark_circled,color: Colors.green,) : Icon(CupertinoIcons.xmark_circle,color: Colors.redAccent,),
                  )
                ],
              ),
            ),
            Container(
              child: Row(
                children: [
                  Text("设备 SN"),
                  Spacer(),
                  SizedBox(
                    width: 175,
                    child: OutlinedButton(onPressed: (){
                      inputText("设备 SN",value: this.sn).then((value) => setState((){
                        if (value == null) { return; }
                        this.sn = value;
                        this.toUnSubMqttTopics();
                        this.toSubMqttTopics();
                      }));
                    }, child: Text(sn)),
                  ),
                  SizedBox(
                    width: 40,
                    child: this.subTopics.length == this.topics.length ? Icon(CupertinoIcons.check_mark_circled,color: Colors.green,) : Icon(CupertinoIcons.xmark_circle,color: Colors.redAccent,),
                  )
                ],
              ),
            ),
            Row(
              children: [
                ElevatedButton(onPressed: (){
                  final time = DateTime.now().millisecondsSinceEpoch;
                  final bufferBuilder = MqttClientPayloadBuilder()
                    ..addString("time:90=${time}\n");
                  this.client.publishMessage("/esp/act/${sn}", MqttQos.exactlyOnce, bufferBuilder.payload!);
                }, child: Text("设定时间"))
              ],
            ),
            Divider(),
            Expanded(child: list)
          ],
        ),
      ),
    );
  }
}
