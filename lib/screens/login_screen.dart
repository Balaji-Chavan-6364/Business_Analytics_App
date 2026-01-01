import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'dart:convert';
import '../services/auth_service.dart';
import '../services/user_service.dart';
import '../models/user_model.dart';
import 'package:firebase_auth/firebase_auth.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  _LoginScreenState createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final AuthService _auth = AuthService();
  final UserService _userService = UserService();
  final _formKey = GlobalKey<FormState>();
  
  bool isLogin = true;
  bool isLoading = false;
  bool isCompletingGoogleProfile = false;

  String email = '';
  String password = '';
  String firstName = '';
  String lastName = '';
  String mobileNumber = '';
  String businessName = '';
  File? _image;
  String? _googleUid;

  Future<void> _pickImage() async {
    final pickedFile = await ImagePicker().pickImage(source: ImageSource.gallery, imageQuality: 25);
    if (pickedFile != null) {
      setState(() => _image = File(pickedFile.path));
    }
  }

  void _showSnackBar(String message, {bool isError = false}) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: isError ? Colors.red : Colors.green,
        behavior: SnackBarBehavior.floating,
        duration: const Duration(seconds: 3),
      ),
    );
  }

  void _submit() async {
    if (!_formKey.currentState!.validate()) return;
    _formKey.currentState!.save();

    setState(() => isLoading = true);

    try {
      String? uid;
      String? userEmail;

      if (isLogin && !isCompletingGoogleProfile) {
        await _auth.signIn(email, password);
        _showSnackBar("Login successful!");
        return; 
      } else if (isCompletingGoogleProfile) {
        uid = _googleUid;
        userEmail = email;
      } else {
        final credential = await _auth.signUp(email, password);
        uid = credential?.user?.uid;
        userEmail = email;
      }

      if (uid != null) {
        String base64Image = '';
        if (_image != null) {
          try {
            base64Image = await _userService.convertImageToBase64(_image!);
          } catch (e) {
            debugPrint("Image upload failed: $e");
          }
        }

        final newUser = UserModel(
          uid: uid,
          firstName: firstName,
          lastName: lastName,
          email: userEmail!,
          mobileNumber: mobileNumber,
          businessName: businessName,
          profileImageUrl: base64Image,
        );
        await _userService.createUserProfile(newUser);
        _showSnackBar(isCompletingGoogleProfile ? "Profile setup complete!" : "Account registered successfully!");
      }
    } catch (e) {
      _showSnackBar(e.toString().replaceAll(RegExp(r'\[.*?\]'), '').trim(), isError: true);
    } finally {
      if (mounted) setState(() => isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: isLoading 
        ? const Center(child: CircularProgressIndicator())
        : Center(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(24.0),
              child: Form(
                key: _formKey,
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Icon(Icons.analytics, size: 80, color: Colors.lightBlueAccent),
                    Text(
                      isLogin ? "Welcome Back" : (isCompletingGoogleProfile ? "Complete Profile" : "Register Business"),
                      style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: Colors.lightBlueAccent),
                    ),
                    const SizedBox(height: 30),
                    
                    if (!isLogin) ...[
                      GestureDetector(
                        onTap: _pickImage,
                        child: CircleAvatar(
                          radius: 45,
                          backgroundColor: Colors.grey.shade200,
                          backgroundImage: _image != null ? FileImage(_image!) : null,
                          child: _image == null ? const Icon(Icons.camera_alt, size: 30, color: Colors.grey) : null,
                        ),
                      ),
                      const SizedBox(height: 20),
                      TextFormField(
                        initialValue: firstName,
                        decoration: const InputDecoration(labelText: "First Name", border: OutlineInputBorder()),
                        validator: (val) => val!.isEmpty ? 'Required' : null,
                        onSaved: (val) => firstName = val!,
                      ),
                      const SizedBox(height: 15),
                      TextFormField(
                        initialValue: lastName,
                        decoration: const InputDecoration(labelText: "Last Name", border: OutlineInputBorder()),
                        validator: (val) => val!.isEmpty ? 'Required' : null,
                        onSaved: (val) => lastName = val!,
                      ),
                      const SizedBox(height: 15),
                      TextFormField(
                        initialValue: businessName,
                        decoration: const InputDecoration(labelText: "Business Name", border: OutlineInputBorder()),
                        validator: (val) => val!.isEmpty ? 'Required' : null,
                        onSaved: (val) => businessName = val!,
                      ),
                      const SizedBox(height: 15),
                      TextFormField(
                        decoration: const InputDecoration(labelText: "Mobile Number", border: OutlineInputBorder()),
                        keyboardType: TextInputType.phone,
                        validator: (val) => val!.isEmpty ? 'Required' : null,
                        onSaved: (val) => mobileNumber = val!,
                      ),
                      const SizedBox(height: 15),
                    ],

                    if (!isCompletingGoogleProfile) ...[
                      TextFormField(
                        initialValue: email,
                        decoration: const InputDecoration(labelText: "Email", border: OutlineInputBorder(), prefixIcon: Icon(Icons.email)),
                        validator: (val) => val!.isEmpty ? 'Enter email' : null,
                        onSaved: (val) => email = val!,
                      ),
                      const SizedBox(height: 15),
                      TextFormField(
                        decoration: InputDecoration(
                          labelText: isLogin ? "Password" : "Create Password", 
                          border: const OutlineInputBorder(), 
                          prefixIcon: const Icon(Icons.lock)
                        ),
                        obscureText: true,
                        validator: (val) => val!.length < 6 ? '6+ characters' : null,
                        onSaved: (val) => password = val!,
                      ),
                      const SizedBox(height: 25),
                    ],
                    
                    ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.lightBlueAccent,
                        minimumSize: const Size(double.infinity, 55),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                      onPressed: _submit,
                      child: Text(isLogin ? "Login" : (isCompletingGoogleProfile ? "Finish Setup" : "Register"), style: const TextStyle(color: Colors.white, fontSize: 18)),
                    ),

                    TextButton(
                      child: Text(isLogin ? "No account? Register now" : "Back to Login"),
                      onPressed: () => setState(() { isLogin = !isLogin; isCompletingGoogleProfile = false; }),
                    )
                  ],
                ),
              ),
            ),
          ),
    );
  }
}
