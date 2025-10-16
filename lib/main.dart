import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:provider/provider.dart';
import 'package:go_router/go_router.dart';

import 'firebase_options.dart';
// auth_service already imported above via services/auth_service.dart in providers
import 'services/firestore_service.dart';
import 'screens/auth/login_screen.dart';
import 'screens/auth/register_screen.dart';
import 'screens/home/home_screen.dart';
import 'screens/admin/admin_dashboard_screen.dart';
import 'screens/admin/election_requests_screen.dart';
import 'models/user.dart';
import 'services/auth_service.dart';
import 'screens/student/student_dashboard_screen.dart';
import 'screens/student/my_votes_screen.dart';
import 'screens/elections/election_list_screen.dart';
import 'screens/elections/election_details_screen.dart';
import 'screens/elections/voting_screen.dart';
import 'screens/contact/contact_screen.dart';
import 'screens/debug/firebase_test_screen.dart';
import 'screens/debug/quick_firebase_check.dart';
import 'utils/app_theme.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );
  runApp(MyApp());
}

class MyApp extends StatelessWidget {
  MyApp({super.key});

  final GoRouter _router = GoRouter(
    initialLocation: '/',
    errorBuilder: (context, state) => Scaffold(
      appBar: AppBar(title: const Text('Not Found')),
      body: Center(child: Text('Page not found: ${state.uri}')),
    ),
    routes: [
      GoRoute(
        path: '/',
        builder: (context, state) => const HomeScreen(),
      ),
      GoRoute(
        path: '/login',
        builder: (context, state) => const LoginScreen(),
      ),
      GoRoute(
        path: '/register',
        builder: (context, state) => const RegisterScreen(),
      ),
      GoRoute(
        path: '/admin-dashboard',
        builder: (context, state) => const AdminDashboardScreen(),
      ),
      GoRoute(
        path: '/admin/requests',
        builder: (context, state) {
          final authService = Provider.of<AuthService>(context, listen: false);
          final user = authService.currentUser;
          if (user == null || user.role != UserRole.admin) {
            return Scaffold(
              appBar: AppBar(title: const Text('Not Authorized')),
              body: const Center(child: Text('You must be an admin to view this page')),
            );
          }

          return const ElectionRequestsScreen();
        },
      ),
      GoRoute(
        path: '/student-dashboard',
        builder: (context, state) => const StudentDashboardScreen(),
      ),
      GoRoute(
        path: '/my-votes',
        builder: (context, state) => const MyVotesScreen(),
      ),
      GoRoute(
        path: '/elections',
        builder: (context, state) => const ElectionListScreen(),
      ),
      GoRoute(
        path: '/election/:id',
        builder: (context, state) {
          final electionId = state.pathParameters['id']!;
          return ElectionDetailsScreen(electionId: electionId);
        },
      ),
      GoRoute(
        path: '/vote/:id',
        builder: (context, state) {
          final electionId = state.pathParameters['id']!;
          return VotingScreen(electionId: electionId);
        },
      ),
      GoRoute(
        path: '/contact',
        builder: (context, state) => const ContactScreen(),
      ),
      GoRoute(
        path: '/firebase-test',
        builder: (context, state) => const FirebaseTestScreen(),
      ),
      GoRoute(
        path: '/check-firebase',
        builder: (context, state) => const QuickFirebaseCheckScreen(),
      ),
    ],
  );

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => AuthService()),
        Provider(create: (_) => FirestoreService()),
      ],
      child: MaterialApp.router(
        title: 'University Voting App',
        theme: AppTheme.lightTheme,
        darkTheme: AppTheme.darkTheme,
        themeMode: ThemeMode.system,
        routerConfig: _router,
      ),
    );
  }
}