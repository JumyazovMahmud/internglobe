import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:flutter/material.dart';
import 'home_screen.dart';
import 'profile_screen.dart';
import 'auth/login_screen.dart';

class RootScreen extends StatelessWidget {
  const RootScreen({super.key});

  Future<bool> _isProfileComplete(String uid) async {
    final ref = FirebaseDatabase.instance.ref('users/$uid');
    final snapshot = await ref.get();

    if (!snapshot.exists) return false;

    final data = Map<String, dynamic>.from(snapshot.value as Map);
    final name = data['name']?.toString().trim() ?? '';
    final favorites = data['favorites'] as List? ?? [];
    final filledFavorites = favorites.where((e) => e.toString().trim().isNotEmpty).length;

    return name.isNotEmpty && filledFavorites >= 3;
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<User?>(
      stream: FirebaseAuth.instance.authStateChanges(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Scaffold(body: Center(child: CircularProgressIndicator()));
        }

        if (snapshot.hasError || !snapshot.hasData || snapshot.data == null) {
          return const LoginScreen();
        }

        final user = snapshot.data!;

        return FutureBuilder<bool>(
          future: _isProfileComplete(user.uid),
          builder: (context, profileSnapshot) {
            if (profileSnapshot.connectionState == ConnectionState.waiting) {
              return const Scaffold(body: Center(child: CircularProgressIndicator()));
            }

            final isComplete = profileSnapshot.data ?? false;

            if (isComplete) {
              return const HomeScreen();
            } else {
              return const ProfileScreen(forceComplete: true);
            }
          },
        );
      },
    );
  }
}