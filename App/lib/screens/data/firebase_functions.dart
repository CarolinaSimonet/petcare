import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';

class Auth {
  final FirebaseAuth _firebaseAuth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  User? get user => _firebaseAuth.currentUser;

  Stream<User?> get authStateChanges => _firebaseAuth.authStateChanges();
  String? getCurrentUserId() {
    final User? user = _firebaseAuth.currentUser;
    return user?.uid; // This will be null if no user is logged in
  }

  Future<void> signInWithEmailAndPassword(String email, String password) async {
    try {
      await _firebaseAuth.signInWithEmailAndPassword(
        email: email,
        password: password,
      );
    } on FirebaseAuthException catch (e) {
      // Handle specific Firebase Auth errors here

      print(e.code);
      rethrow;
    } catch (e) {
      // Handle other errors, such as network issues
      print(e);
      rethrow;
    }
  }

  Future<void> createUserWithEmailAndPassword(
      String email, String password, String username) async {
    try {
      UserCredential userCredential =
          await _firebaseAuth.createUserWithEmailAndPassword(
        email: email,
        password: password,
      );
      if (user != null) {
        String userId = userCredential.user!.uid;

        // Set user data in Firestore
        await _firestore.collection('users').doc(userId).set({
          'name': username,
          'email': email,
          // Default role for self-registration
        });
      } else {
        print("user is null");
      }
    } on FirebaseAuthException catch (e) {
      // Handle specific Firebase Auth errors here
      print(e.code);
      rethrow;
    } catch (e) {
      // Handle other errors, such as network issues
      print(e);
      rethrow;
    }

    //await _firebaseAuth.signOut();
  }

  Future signOut() async {
    await _firebaseAuth.signOut();
  }
}

Future<void> saveImageMetadata(
    String imageUrl, String userId, DateTime dateTaken) async {
  try {
    print('Saving image metadata...');
    FirebaseFirestore firestore = FirebaseFirestore.instance;
    await firestore.collection('images').add({
      'imageUrl': imageUrl,
      'userId': userId,
      'dateTaken': dateTaken,
    });
  } catch (e) {
    print('Error saving image metadata: $e');
  }
}

Future<void> addActivity(
    {required String imageUrl,
    required String userId,
    String? description,
    DateTime? date,
    double? distance}) async {
  FirebaseFirestore firestore = FirebaseFirestore.instance;

  try {
    await firestore.collection('activities').add({
      'imageUrl': imageUrl,
      'userId': userId,
      'description': description ?? 'No description provided.',
      'date': date ?? DateTime.now(),
      'distance': distance, // default to (0,0) if no location is provided
      'createdAt': FieldValue.serverTimestamp(), // server-side timestamp
    });
    print("Activity successfully added!");
  } catch (e) {
    print("Error adding activity: $e");
    throw Exception("Failed to add activity");
  }
}

Future<void> addPet({
  required String name,
  required String gender,
  required String type,
  required String breed,
  required String weight,
  required String diet,
  required String portions,
  required String killometers,
  required String grams
}) async {
  FirebaseFirestore firestore = FirebaseFirestore.instance;



  try {
    await firestore.collection('pets').add({
      'name': name,
      'gender': gender,
      'type': type,
      'breed': breed,
      'actualKmWalk': '0',
      'actualPortionsFood': '0',
      'dietType': diet,
      "gramsFood": grams,
      "kmWalk": killometers,
      "portionsFood": portions,
      "weight": weight,
      'createdAt': FieldValue.serverTimestamp(), // server-side timestamp
    });
    print("New Pet successfully added!");
  } catch (e) {
    print("Error adding Pet: $e");
    throw Exception("Failed to add Pet");
  }
}


class AuthService {
  final FirebaseAuth _firebaseAuth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  Future<String?> getCurrentUserId() async {
    final User? user = _firebaseAuth.currentUser;
    return user?.uid; // This will be null if no user is logged in
  }

  Future<String> getCurrentUserRole() async {
    final User? user = _firebaseAuth.currentUser;
    if (user != null) {
      DocumentSnapshot userData =
          await _firestore.collection('users').doc(user!.uid).get();
      return userData['role'];
    } else {
      print('error :user null');
      return '';
    }
    // This will be null if no user is logged in
  }
}
