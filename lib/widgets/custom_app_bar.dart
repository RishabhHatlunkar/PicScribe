import 'package:flutter/material.dart';

class CustomAppBar extends StatelessWidget implements PreferredSizeWidget {
  final String title;
  final bool showBackButton;
  final VoidCallback? onBackButtonPressed;

  const CustomAppBar({
    super.key,
    required this.title,
    this.showBackButton = false,
    this.onBackButtonPressed,
  });

  @override
  Size get preferredSize => const Size.fromHeight(kToolbarHeight);

  @override
  Widget build(BuildContext context) {
    return AppBar(
      title: Text(title),
      leading: showBackButton
          ? IconButton(
              icon: const Icon(Icons.arrow_back, color: Colors.blue),
              onPressed: onBackButtonPressed ?? () => Navigator.pop(context),
            )
          : null,
    );
  }
}