import 'package:firebase_auth/firebase_auth.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'account_service.dart';

class AuthService {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final GoogleSignIn _googleSignIn = GoogleSignIn();
  final AccountService _accountService = AccountService();

  Stream<User?> get user => _auth.authStateChanges();

  Future<UserCredential?> signIn(String email, String password) async {
    try {
      final credential = await _auth.signInWithEmailAndPassword(
          email: email, password: password);
      if (credential.user != null) {
        await _accountService.saveAccount(email, password);
      }
      return credential;
    } on FirebaseAuthException catch (e) {
      throw e.message ?? "An error occurred during sign in.";
    } catch (e) {
      throw e.toString();
    }
  }

  Future<UserCredential?> signUp(String email, String password) async {
    try {
      final credential = await _auth.createUserWithEmailAndPassword(
          email: email, password: password);
      if (credential.user != null) {
        await _accountService.saveAccount(email, password);
      }
      return credential;
    } on FirebaseAuthException catch (e) {
      throw e.message ?? "An error occurred during sign up.";
    } catch (e) {
      throw e.toString();
    }
  }

  Future<UserCredential?> signInWithGoogle() async {
    try {
      final GoogleSignInAccount? googleUser = await _googleSignIn.signIn();
      if (googleUser == null) return null;

      final GoogleSignInAuthentication googleAuth = await googleUser.authentication;
      final AuthCredential credential = GoogleAuthProvider.credential(
        accessToken: googleAuth.accessToken,
        idToken: googleAuth.idToken,
      );

      final userCredential = await _auth.signInWithCredential(credential);
      return userCredential;
    } on FirebaseAuthException catch (e) {
      throw e.message ?? "An error occurred during Google sign in.";
    } catch (e) {
      throw e.toString();
    }
  }

  Future<void> signOut() async {
    await _googleSignIn.signOut();
    await _auth.signOut();
  }
}
