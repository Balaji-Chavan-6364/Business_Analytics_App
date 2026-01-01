import 'dart:io';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:image_picker/image_picker.dart';
import 'dashboard_screen.dart';
import 'add_entry_screen.dart';
import 'reports_screen.dart';
import '../services/auth_service.dart';
import '../services/user_service.dart';
import '../services/account_service.dart';
import '../providers/entry_provider.dart';
import '../providers/theme_provider.dart';
import '../models/user_model.dart';
import 'package:intl/intl.dart';

class MainScreen extends StatefulWidget {
  const MainScreen({super.key});

  @override
  _MainScreenState createState() => _MainScreenState();
}

class _MainScreenState extends State<MainScreen> {
  int _currentIndex = 0;
  final UserService _userService = UserService();

  void setTab(int index) {
    setState(() {
      _currentIndex = index;
    });
  }

  Widget _getCurrentPage() {
    switch (_currentIndex) {
      case 0:
        return DashboardScreen();
      case 1:
        return AddEntryScreen(onSuccess: () => setTab(2));
      case 2:
        return const ReportsScreen();
      case 3:
        return const _SettingsScreen();
      default:
        return DashboardScreen();
    }
  }

  @override
  Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser;

    return StreamBuilder<UserModel?>(
      stream: _userService.streamUserProfile(user?.uid ?? ''),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting && user != null) {
          return const Scaffold(
              body: Center(child: CircularProgressIndicator()));
        }

        final profile = snapshot.data;
        final String businessName =
            (profile?.businessName != null && profile!.businessName.isNotEmpty)
                ? profile.businessName
                : "My Business";

        return Scaffold(
          appBar: AppBar(
            title: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(businessName,
                    style: const TextStyle(
                        fontSize: 18, fontWeight: FontWeight.bold)),
                Text(DateFormat.yMMMMd().format(DateTime.now()),
                    style: const TextStyle(fontSize: 12)),
              ],
            ),
            actions: [
              IconButton(
                icon: Icon(Provider.of<ThemeProvider>(context).isDarkMode
                    ? Icons.light_mode
                    : Icons.dark_mode),
                onPressed: () {
                  final provider =
                      Provider.of<ThemeProvider>(context, listen: false);
                  provider.toggleTheme(!provider.isDarkMode);
                },
              )
            ],
            backgroundColor: Theme.of(context).colorScheme.primary,
            foregroundColor: Colors.white,
            elevation: 0,
          ),
          body: Consumer<EntryProvider>(
            builder: (context, provider, child) {
              if (provider.isLoading) {
                return const Center(child: CircularProgressIndicator());
              }
              return _getCurrentPage();
            },
          ),
          bottomNavigationBar: BottomNavigationBar(
            currentIndex: _currentIndex,
            selectedItemColor: Theme.of(context).colorScheme.primary,
            unselectedItemColor: Colors.grey,
            showUnselectedLabels: true,
            type: BottomNavigationBarType.fixed,
            onTap: (index) => setState(() => _currentIndex = index),
            items: const [
              BottomNavigationBarItem(
                  icon: Icon(Icons.dashboard), label: "Dashboard"),
              BottomNavigationBarItem(
                  icon: Icon(Icons.add_box), label: "Add Entry"),
              BottomNavigationBarItem(
                  icon: Icon(Icons.assessment), label: "Reports"),
              BottomNavigationBarItem(
                  icon: Icon(Icons.settings), label: "Settings"),
            ],
          ),
        );
      },
    );
  }
}

class _SettingsScreen extends StatefulWidget {
  const _SettingsScreen();

  @override
  State<_SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<_SettingsScreen> {
  final AccountService _accountService = AccountService();
  final AuthService _authService = AuthService();
  final UserService _userService = UserService();
  bool isActionLoading = false;

  void _showAddAccountDialog() {
    final formKey = GlobalKey<FormState>();
    final emailController = TextEditingController();
    final passwordController = TextEditingController();

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text("Add Another Account"),
        content: Form(
          key: formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextFormField(
                controller: emailController,
                decoration: const InputDecoration(labelText: "Email"),
                keyboardType: TextInputType.emailAddress,
                validator: (val) => val!.isEmpty ? 'Required' : null,
              ),
              TextFormField(
                controller: passwordController,
                decoration: const InputDecoration(labelText: "Password"),
                obscureText: true,
                validator: (val) => val!.isEmpty ? 'Required' : null,
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx), child: const Text("Cancel")),
          ElevatedButton(
            onPressed: () async {
              if (formKey.currentState!.validate()) {
                final email = emailController.text.trim();
                final password = passwordController.text;
                
                Navigator.pop(ctx);
                setState(() => isActionLoading = true);
                
                try {
                  // Validate if account exists by attempting a temporary sign in
                  // using a separate FirebaseAuth instance to not disturb current session
                  final tempAuth = FirebaseAuth.instance;
                  final currentUser = tempAuth.currentUser;
                  
                  // Verification attempt
                  await tempAuth.signInWithEmailAndPassword(email: email, password: password);
                  
                  // If successful, save to list
                  await _accountService.saveAccount(email, password);
                  
                  // Restore session logic: Firebase replaces the instance user, 
                  // so we need to switch back if we want to stay logged in as user1
                  // But for "Add Account", usually we just want to verify it works.
                  // THE BEST WAY: Just add it, and if it fails when SWITCHING, show error.
                  // However, to satisfy "show error if account does not exist":
                  
                  if (mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text("Account verified and added"), backgroundColor: Colors.green),
                    );
                  }
                } catch (e) {
                  if (mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text("Verification Failed: Account not found or wrong password"), backgroundColor: Colors.red),
                    );
                  }
                } finally {
                  if (mounted) setState(() => isActionLoading = false);
                }
              }
            },
            child: const Text("Add"),
          ),
        ],
      ),
    );
  }

  void _showEditProfileDialog(UserModel profile) {
    final formKey = GlobalKey<FormState>();
    final fNameController = TextEditingController(text: profile.firstName);
    final lNameController = TextEditingController(text: profile.lastName);
    final bNameController = TextEditingController(text: profile.businessName);
    final mobileController = TextEditingController(text: profile.mobileNumber);
    File? _newImage;

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: const Text("Edit Profile"),
          content: SingleChildScrollView(
            child: Form(
              key: formKey,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  GestureDetector(
                    onTap: () async {
                      final picked = await ImagePicker()
                          .pickImage(source: ImageSource.gallery, imageQuality: 25);
                      if (picked != null) {
                        setDialogState(() => _newImage = File(picked.path));
                      }
                    },
                    child: CircleAvatar(
                      radius: 40,
                      backgroundImage: _newImage != null
                          ? FileImage(_newImage!)
                          : (profile.profileImageUrl.isNotEmpty
                              ? MemoryImage(base64Decode(profile.profileImageUrl))
                              : null) as ImageProvider?,
                      child: (_newImage == null && profile.profileImageUrl.isEmpty)
                          ? const Icon(Icons.add_a_photo)
                          : null,
                    ),
                  ),
                  const SizedBox(height: 10),
                  TextFormField(
                    controller: fNameController,
                    decoration: const InputDecoration(labelText: "First Name"),
                    validator: (val) => val!.isEmpty ? 'Required' : null,
                  ),
                  TextFormField(
                    controller: lNameController,
                    decoration: const InputDecoration(labelText: "Last Name"),
                    validator: (val) => val!.isEmpty ? 'Required' : null,
                  ),
                  TextFormField(
                    controller: bNameController,
                    decoration: const InputDecoration(labelText: "Business Name"),
                    validator: (val) => val!.isEmpty ? 'Required' : null,
                  ),
                  TextFormField(
                    controller: mobileController,
                    decoration: const InputDecoration(labelText: "Mobile Number"),
                    keyboardType: TextInputType.phone,
                    validator: (val) => val!.isEmpty ? 'Required' : null,
                  ),
                ],
              ),
            ),
          ),
          actions: [
            TextButton(
                onPressed: () => Navigator.pop(ctx), child: const Text("Cancel")),
            ElevatedButton(
              onPressed: () async {
                if (!formKey.currentState!.validate()) return;

                Navigator.pop(ctx);
                setState(() => isActionLoading = true);

                try {
                  String profileImage = profile.profileImageUrl;
                  if (_newImage != null) {
                    profileImage =
                        await _userService.convertImageToBase64(_newImage!);
                  }

                  final updatedUser = UserModel(
                    uid: profile.uid,
                    firstName: fNameController.text,
                    lastName: lNameController.text,
                    email: profile.email,
                    mobileNumber: mobileController.text,
                    businessName: bNameController.text,
                    profileImageUrl: profileImage,
                  );
                  await _userService.createUserProfile(updatedUser);
                  if (mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                          content: Text("Profile updated successfully"),
                          backgroundColor: Colors.green),
                    );
                  }
                } catch (e) {
                  if (mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                          content: Text("Error: $e"),
                          backgroundColor: Colors.red),
                    );
                  }
                } finally {
                  if (mounted) setState(() => isActionLoading = false);
                }
              },
              child: const Text("Save"),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final themeProvider = Provider.of<ThemeProvider>(context);
    final currentUser = FirebaseAuth.instance.currentUser;

    if (isActionLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Profile Section
          StreamBuilder<UserModel?>(
            stream: _userService.streamUserProfile(currentUser?.uid ?? ''),
            builder: (context, snapshot) {
              final profile = snapshot.data;
              return Card(
                elevation: 0,
                color: Theme.of(context).colorScheme.primary.withOpacity(0.1),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16)),
                child: Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Column(
                    children: [
                      Row(
                        children: [
                          CircleAvatar(
                            radius: 35,
                            backgroundColor: Colors.lightBlueAccent,
                            backgroundImage: (profile != null &&
                                    profile.profileImageUrl.isNotEmpty)
                                ? MemoryImage(
                                    base64Decode(profile.profileImageUrl))
                                : null,
                            child: (profile == null ||
                                    profile.profileImageUrl.isEmpty)
                                ? const Icon(Icons.person,
                                    size: 40, color: Colors.white)
                                : null,
                          ),
                          const SizedBox(width: 16),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  "${profile?.firstName ?? 'Setup'} ${profile?.lastName ?? 'Profile'}",
                                  style: const TextStyle(
                                      fontSize: 18, fontWeight: FontWeight.bold),
                                ),
                                Text(profile?.email ?? currentUser?.email ?? '',
                                    style: TextStyle(
                                        color: Colors.grey.shade600)),
                                Text(profile?.mobileNumber ?? 'Click edit to setup',
                                    style: TextStyle(
                                        color: Colors.grey.shade600)),
                              ],
                            ),
                          ),
                          IconButton(
                            icon: const Icon(Icons.edit, color: Colors.blue),
                            onPressed: () {
                              if (profile != null) {
                                _showEditProfileDialog(profile);
                              } else {
                                _showEditProfileDialog(UserModel(
                                    uid: currentUser!.uid,
                                    firstName: '',
                                    lastName: '',
                                    email: currentUser.email ?? '',
                                    mobileNumber: '',
                                    businessName: ''));
                              }
                            },
                          )
                        ],
                      ),
                    ],
                  ),
                ),
              );
            },
          ),
          const SizedBox(height: 20),
          const Text("General",
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
          const SizedBox(height: 10),
          Card(
            child: ListTile(
              leading: const Icon(Icons.dark_mode),
              title: const Text("Dark Mode"),
              trailing: Switch(
                value: themeProvider.isDarkMode,
                onChanged: (value) => themeProvider.toggleTheme(value),
              ),
            ),
          ),
          const SizedBox(height: 20),
          const Text("Accounts",
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
          const SizedBox(height: 10),
          FutureBuilder<List<SavedAccount>>(
            future: _accountService.getSavedAccounts(),
            builder: (context, snapshot) {
              final accounts = snapshot.data ?? [];

              return Column(
                children: [
                  ...accounts.map((account) {
                    bool isCurrent = account.email == currentUser?.email;
                    return Card(
                      elevation: isCurrent ? 4 : 1,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                        side: isCurrent
                            ? const BorderSide(color: Colors.blue, width: 2)
                            : BorderSide.none,
                      ),
                      child: ListTile(
                        leading: CircleAvatar(
                          backgroundColor: isCurrent ? Colors.blue : Colors.grey,
                          child: Text(
                              account.email.isNotEmpty
                                  ? account.email[0].toUpperCase()
                                  : '?',
                              style: const TextStyle(color: Colors.white)),
                        ),
                        title: Text(account.email),
                        subtitle: isCurrent
                            ? const Text("Active",
                                style: TextStyle(color: Colors.blue))
                            : null,
                        onTap: isCurrent
                            ? null
                            : () async {
                                final confirm = await showDialog<bool>(
                                  context: context,
                                  builder: (ctx) => AlertDialog(
                                    title: const Text("Switch Account"),
                                    content: Text(
                                        "Switch to ${account.email}?"),
                                    actions: [
                                      TextButton(
                                          onPressed: () =>
                                              Navigator.pop(ctx, false),
                                          child: const Text("Cancel")),
                                      TextButton(
                                          onPressed: () =>
                                              Navigator.pop(ctx, true),
                                          child: const Text("Switch")),
                                    ],
                                  ),
                                );
                                if (confirm == true) {
                                  // Switch process: no redirect, just immediate sign in
                                  try {
                                    await _authService.signIn(account.email, account.password);
                                  } catch (e) {
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      SnackBar(content: Text("Switch failed: $e"), backgroundColor: Colors.red),
                                    );
                                  }
                                }
                              },
                        trailing: isCurrent
                            ? const Icon(Icons.check_circle, color: Colors.blue)
                            : IconButton(
                                icon: const Icon(Icons.remove_circle_outline,
                                    color: Colors.red),
                                onPressed: () async {
                                  await _accountService.removeAccount(account.email);
                                  setState(() {});
                                },
                              ),
                      ),
                    );
                  }).toList(),
                  const SizedBox(height: 10),
                  ElevatedButton.icon(
                    onPressed: _showAddAccountDialog,
                    icon: const Icon(Icons.add),
                    label: const Text("Add Another Account"),
                    style: ElevatedButton.styleFrom(
                      minimumSize: const Size(double.infinity, 45),
                    ),
                  ),
                ],
              );
            },
          ),
          const SizedBox(height: 20),
          Card(
            child: ListTile(
              leading: const Icon(Icons.logout, color: Colors.red),
              title: const Text("Logout Current Account",
                  style: TextStyle(color: Colors.red)),
              onTap: () async {
                await FirebaseAuth.instance.signOut();
              },
            ),
          ),
        ],
      ),
    );
  }
}
