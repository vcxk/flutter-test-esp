import 'package:flutter/cupertino.dart';


class Util {

  static Future<dynamic> nextPage(BuildContext context,Widget page) {
    final route = CupertinoPageRoute(builder: (ctx) => page);
    return Navigator.push(context, route);
  }

  static Widget makeRow(String title,String value) {
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

}

