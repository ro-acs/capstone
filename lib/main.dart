import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'dart:async';
import 'package:google_fonts/google_fonts.dart';

import 'screens/login_screen.dart';
import 'screens/dashboard_client.dart';
import 'screens/dashboard_photographer.dart';
import 'screens/dashboard_admin.dart';
import 'screens/manage_services.dart';
import 'screens/booking_requests_photographer.dart';
import 'screens/chat_with_clients.dart';
import 'screens/portfolio_upload.dart';
import 'screens/review_photographer.dart';
import 'screens/verify_profiles.dart';
import 'screens/user_reports.dart';
import 'screens/report_analytics.dart';
import 'screens/manage_reviews.dart';
import 'screens/dashboard_selector.dart';
import 'screens/calendar_view.dart';
import 'screens/payment_screen.dart';
import 'screens/gcash_webview_payment.dart';
import 'screens/invoice_screen.dart';
import 'screens/report_user.dart';
import 'screens/portfolio_likes.dart';
import 'screens/photographer_team.dart';
import 'screens/browse_photographers.dart';
import 'screens/booking_calendar_photographer.dart';
import 'screens/register/email_entry_screen.dart';
import 'screens/book_photographer.dart';
import 'screens/chat_with_photographers.dart';
import 'screens/my_booking_screen.dart';
import 'screens/make_payment_screen.dart';
import 'screens/payment_receipt_screen.dart';
import 'screens/payment_history_screen.dart';
import 'screens/confirm_payment_screen.dart';

import 'models/route_arguments.dart'; // ✅ import argument models

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp();
  runApp(const SnapSpotApp());
}

class SnapSpotApp extends StatelessWidget {
  const SnapSpotApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'SnapSpot',
      theme: ThemeData(primarySwatch: Colors.deepPurple),
      debugShowCheckedModeBanner: false,
      home: const SplashScreen(),
      onGenerateRoute: (settings) {
        if (settings.name == '/review_photographer') {
          final args = settings.arguments as Map<String, dynamic>;
          return MaterialPageRoute(
            builder: (_) => ReviewPhotographerScreen(
              photographerId: args['photographerId'],
            ),
          );
        }
        if (settings.name == '/book_photographer') {
          final photographerId = settings.arguments as String;
          return MaterialPageRoute(
            builder: (_) =>
                BookPhotographerScreen(photographerId: photographerId),
          );
        }
        switch (settings.name) {
          case '/make_payment':
            final args = settings.arguments;
            if (args is Map<String, dynamic> &&
                args['bookingId'] is String &&
                args['photographerId'] is String &&
                args['clientId'] is String &&
                (args['remaining'] is num || args['remaining'] is double)) {
              return MaterialPageRoute(
                builder: (_) => MakePaymentScreen(
                  bookingId: args['bookingId'],
                  remaining: (args['remaining'] as num).toDouble(),
                  photographerId: args['photographerId'],
                  clientId: args['clientId'],
                ),
              );
            }
            return _invalidArgsScreen();

          case '/payment_history':
            final args = settings.arguments as Map<String, dynamic>;
            return MaterialPageRoute(
              builder: (_) =>
                  PaymentHistoryScreen(bookingId: args['bookingId']),
            );

          case '/payment_receipt':
            final args = settings.arguments as Map<String, dynamic>;
            return MaterialPageRoute(
              builder: (_) => PaymentReceiptScreen(
                bookingId: args['bookingId'],
                index: args['index'],
              ),
            );
          case '/login':
            return MaterialPageRoute(builder: (_) => const LoginScreen());

          case '/dashboard_client':
            return MaterialPageRoute(builder: (_) => const DashboardClient());

          case '/dashboard_photographer':
            return MaterialPageRoute(
              builder: (_) => const DashboardPhotographer(),
            );

          case '/dashboard_admin':
            return MaterialPageRoute(builder: (_) => const DashboardAdmin());

          case '/manage_services':
            return MaterialPageRoute(
              builder: (_) => const ManageServicesScreen(),
            );

          case '/chat_with_photographers':
            return MaterialPageRoute(
              builder: (_) => const ChatWithPhotographers(),
            );

          case '/booking_requests_photographer':
            return MaterialPageRoute(
              builder: (_) => const BookingRequestsPhotographerScreen(),
            );

          case '/chat_with_clients':
            final args = settings.arguments as ChatWithClientsArgs;
            return MaterialPageRoute(
              builder: (_) => ChatWithClients(userType: args.userType),
            );

          case '/portfolio_upload':
            return MaterialPageRoute(builder: (_) => PortfolioUploadScreen());

          case 'my_booking_screen':
            return MaterialPageRoute(builder: (_) => MyBookingsScreen());

          case '/verify_profiles':
            return MaterialPageRoute(
              builder: (_) => const VerifyProfilesScreen(),
            );

          case '/user_reports':
            return MaterialPageRoute(builder: (_) => const UserReportsScreen());

          case '/report_analytics':
            return MaterialPageRoute(
              builder: (_) => const ReportAnalyticsScreen(),
            );

          case '/manage_reviews':
            return MaterialPageRoute(
              builder: (_) => const ManageReviewsScreen(),
            );

          case '/dashboard_selector':
            return MaterialPageRoute(builder: (_) => const DashboardSelector());

          case '/calendar':
            return MaterialPageRoute(
              builder: (_) => const CalendarViewScreen(),
            );

          case '/payment':
            final args = settings.arguments as PaymentScreenArgs;
            return MaterialPageRoute(
              builder: (_) => PaymentScreen(
                contextType: args.contextType,
                referenceId: args.referenceId,
              ),
            );

          case '/gcash_payment':
            final args = settings.arguments as GCashPaymentArgs;
            return MaterialPageRoute(
              builder: (_) => GCashWebViewPaymentScreen(
                paymentUrl: args.paymentUrl,
                contextType: args.contextType,
                referenceId: args.referenceId,
                amount: args.amount,
                note: args.note ?? '',
              ),
            );

          case '/invoice':
            final args = settings.arguments as InvoiceScreenArgs;
            return MaterialPageRoute(
              builder: (_) => InvoiceScreen(bookingId: args.bookingId),
            );

          case '/report_user':
            final args = settings.arguments as ReportUserArgs;
            return MaterialPageRoute(
              builder: (_) => ReportUserScreen(
                reportedUserId: args.reportedUserId,
                reportedUserName: args.reportedUserName,
              ),
            );

          case '/portfolio_likes':
            final args = settings.arguments as PortfolioLikesArgs;
            return MaterialPageRoute(
              builder: (_) =>
                  PortfolioLikesScreen(photographerId: args.photographerId),
            );

          case '/photographer_team':
            final args = settings.arguments as PhotographerTeamArgs;
            return MaterialPageRoute(
              builder: (_) => PhotographerTeamScreen(teamId: args.teamId),
            );

          case '/browse_photographers':
            return MaterialPageRoute(
              builder: (_) => const BrowsePhotographersScreen(),
            );

          case '/mail_entry_screen':
            return MaterialPageRoute(builder: (_) => const EmailEntryScreen());

          case '/booking_calendar_photographer':
            return MaterialPageRoute(
              builder: (_) => const BookingCalendarPhotographer(),
            );

          default:
            return MaterialPageRoute(
              builder: (_) =>
                  const Scaffold(body: Center(child: Text('Unknown route'))),
            );
        }
      },
    );
  }
}

MaterialPageRoute _invalidArgsScreen() {
  return MaterialPageRoute(
    builder: (_) => const Scaffold(
      body: Center(
        child: Text(
          '❌ Invalid or missing route arguments.',
          style: TextStyle(fontSize: 16, color: Colors.red),
        ),
      ),
    ),
  );
}

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> {
  @override
  void initState() {
    super.initState();
    Timer(const Duration(seconds: 2), () {
      final user = FirebaseAuth.instance.currentUser;
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(
          builder: (_) =>
              user == null ? const LoginScreen() : const DashboardSelector(),
        ),
      );
    });
  }

  @override
  Widget build(BuildContext context) {
    return const Scaffold(
      backgroundColor: Colors.deepPurple,
      body: Center(
        child: Text(
          'SnapSpot',
          style: TextStyle(
            fontSize: 36,
            color: Colors.white,
            fontWeight: FontWeight.bold,
          ),
        ),
      ),
    );
  }
}
