import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'screens/login_page.dart';
import 'screens/dashboard_photographer.dart';
import 'screens/booking_requests.dart';
import 'screens/scheduled_bookings.dart';
import 'screens/manage_portfolio.dart';
import 'screens/edit_profile.dart';
import 'screens/chat_with_clients.dart';
import 'screens/add_service.dart';
import 'screens/completed_bookings.dart';
import 'screens/chat_screen.dart';
import 'screens/my_bookings.dart';
import 'screens/register_page.dart';
import 'screens/dashboard_admin.dart';
import 'screens/dashboard_client.dart';
import 'screens/chat_with_photographers.dart';
import 'screens/book_session.dart';
import 'screens/calendar_bookings.dart';
import 'screens/browse_photographers.dart';
import 'screens/photographer_profile.dart';
import 'screens/payment_proof_upload.dart';
import 'screens/admin_payment_approvals.dart';
import 'screens/payment_screen.dart';
import 'screens/paypal_payment_screen.dart';
import 'screens/compare_photographers_screen.dart';
import 'screens/favorites_screen.dart';
import 'screens/add_review_screen.dart';
import 'screens/payment_success_screen.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp();
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'SnapSpot',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(primarySwatch: Colors.deepPurple, useMaterial3: true),
      home: const LoginPage(),
      routes: {
        '/register': (context) => const RegisterPage(),
        '/client_dashboard': (context) => const DashboardClient(),
        '/photographer_dashboard': (context) => const DashboardPhotographer(),
        '/admin_dashboard': (context) => const DashboardAdmin(),
        '/dashboard_photographer': (context) => const DashboardPhotographer(),
        '/booking_requests': (context) => const BookingRequestsScreen(),
        '/scheduled_bookings': (context) => const ScheduledBookingsScreen(),
        '/manage_portfolio': (context) => const ManagePortfolioScreen(),
        '/edit_profile': (context) => const EditProfilePage(),
        '/chat_with_clients': (context) => const ChatWithClientsScreen(),
        '/add_service': (context) => const AddServiceScreen(),
        '/completed_bookings': (context) => const CompletedBookingsScreen(),
        '/my_bookings': (context) => const MyBookingsScreen(),
        '/chat_with_photographers': (context) => ChatWithPhotographersScreen(),
        '/book_session': (context) {
          final args = ModalRoute.of(context)?.settings.arguments;
          if (args is String) {
            return BookSessionPage(photographerId: args);
          } else {
            return const Scaffold(
              body: Center(child: Text('Error: photographerId not provided')),
            );
          }
        },
        '/calendar_bookings': (context) => const CalendarBookingsScreen(),
        '/payment_success': (context) => const PaymentSuccessScreen(),
        '/browse_photographers': (context) => const BrowsePhotographersScreen(),
        '/admin_payment_approvals': (context) =>
            const AdminPaymentApprovalsPage(),
        '/payment_proof': (context) {
          final args =
              ModalRoute.of(context)!.settings.arguments
                  as Map<String, dynamic>;
          return PaymentProofUploadPage(
            bookingId: args['bookingId'],
            photographerId: args['photographerId'],
          );
        },
        '/paypal_payment': (context) {
          final args =
              ModalRoute.of(context)!.settings.arguments
                  as Map<String, dynamic>;
          return PaypalPaymentScreen(userId: args['userId']);
        },
        '/photographer_profile': (context) {
          final id = ModalRoute.of(context)!.settings.arguments as String;
          return PhotographerProfileScreen(photographerId: id);
        },
        '/favorites': (context) => const FavoritesScreen(),
        '/add_review': (context) {
          final args =
              ModalRoute.of(context)!.settings.arguments
                  as Map<String, dynamic>;
          return AddReviewScreen(
            photographerId: args['photographerId'],
            photographerName: args['photographerName'],
            bookingId: args['bookingId'],
          );
        },
      },
      onGenerateRoute: (settings) {
        if (settings.name == '/compare_photographers') {
          final photographerIds = settings.arguments as List<String>;
          return MaterialPageRoute(
            builder: (_) =>
                ComparePhotographersScreen(photographerIds: photographerIds),
          );
        }
        return null;
      },
    );
  }
}
