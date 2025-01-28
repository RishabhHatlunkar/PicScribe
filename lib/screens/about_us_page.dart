import 'package:flutter/material.dart';
import 'package:pixelsheet/widgets/custom_app_bar.dart';


class AboutUsPage extends StatelessWidget {
  const AboutUsPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: const CustomAppBar(title: "About Us"),
      body: Stack(
        children: [
          const Column(
            children: [
              Text(""),//About application
              Text("--Developed By Rishabh Hatlunkar and Atharva Jagtap", style: TextStyle(fontSize: 15),)
            ],
          ),
          Positioned(child: IconButton(icon:  const Icon(Icons.arrow_back_ios, color: Colors.blue,), onPressed: () {
            Navigator.pop(context);
          },),
            top: 10,
            left: 10,
          )
        ],
      ),
    );
  }
}
