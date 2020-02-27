import 'package:archiver/home.dart';
import "package:flutter/material.dart";

void main() {
  runApp(
    MaterialApp(
      debugShowCheckedModeBanner: false,
      title: "Archiver",
      theme: ThemeData(
        brightness: Brightness.dark,
        primaryColor: Colors.yellow,
        buttonColor: Colors.yellow,
        accentColor: Colors.yellow,
        backgroundColor: Colors.blueGrey[900],
      ),
      home: Home(),
    ),
  );
}
