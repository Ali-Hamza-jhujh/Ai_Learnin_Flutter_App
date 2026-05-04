import 'package:flutter/material.dart';

AppBar customAppBar(String title) {
  return AppBar(
    elevation: 0,
    backgroundColor: Colors.white,
    centerTitle: true,

    title: Text(
      title,
      style: TextStyle(color: Colors.black, fontWeight: FontWeight.bold),
    ),

    iconTheme: IconThemeData(color: Colors.black),
  );
}
