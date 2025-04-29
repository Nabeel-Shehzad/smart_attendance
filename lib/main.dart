import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:provider/provider.dart';
import 'firebase_options.dart';
import 'screens/home_page.dart';
import 'screens/login_page.dart';
import 'screens/student/register_student_page.dart';
import 'screens/student/student_dashboard.dart';
import 'screens/student/student_courses_page.dart';
import 'screens/student/student_attendance_page.dart';
import 'screens/teacher/register_instructor_page.dart';
import 'screens/teacher/instructor_dashboard.dart';
import 'screens/teacher/attendance_sessions_page.dart';
import 'screens/teacher/add_student_page.dart';
import 'providers/auth_provider.dart';
import 'providers/course_provider.dart';
import 'providers/attendance_provider.dart';
import 'providers/face_recognition_provider.dart';
import 'providers/notification_provider.dart';
import 'providers/wifi_provider.dart';  // Added WiFi provider

// Handle background messages when app is terminated or in background
@pragma('vm:entry-point')
Future<void> _firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
  print('Background message received: ${message.messageId}');
  // We don't need to do anything else here - the notification will be shown
  // by the system tray, and when user taps it, they'll be taken to the app
}

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
  
  // Set up background message handler
  FirebaseMessaging.onBackgroundMessage(_firebaseMessagingBackgroundHandler);
  
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => AuthProvider()),
        ChangeNotifierProvider(create: (_) => CourseProvider()),
        ChangeNotifierProvider(create: (_) => AttendanceProvider()),
        ChangeNotifierProvider(create: (_) => FaceRecognitionProvider()),
        ChangeNotifierProvider(create: (_) => NotificationProvider()),
        ChangeNotifierProvider(create: (_) => WifiProvider()),  // Added WiFi provider
      ],
      child: MaterialApp(
        debugShowCheckedModeBanner: false,
        title: 'Smart Attendance',
        theme: ThemeData(
          colorScheme: ColorScheme.fromSeed(seedColor: const Color(0xFF3F51B5)),
          useMaterial3: true,
        ),
        initialRoute: '/',
        routes: {
          '/': (context) => const HomePage(),
          '/login/student': (context) => const LoginPage(userType: 'Student'),
          '/login/instructor': (context) => const LoginPage(userType: 'Instructor'),
          '/student/register': (context) => const RegisterStudentPage(),
          '/student/dashboard': (context) => const StudentDashboard(),
          '/student/courses': (context) => const StudentCoursesPage(),
          '/student/attendance': (context) => const StudentAttendancePage(),
          '/instructor/register': (context) => const RegisterInstructorPage(),
          '/instructor/dashboard': (context) => const InstructorDashboard(),
        },
        onGenerateRoute: (settings) {
          // Handle routes with parameters
          if (settings.name == '/instructor/attendance') {
            final args = settings.arguments as Map<String, dynamic>?;
            if (args != null) {
              return MaterialPageRoute(
                builder: (context) => AttendanceSessionsPage(
                  courseId: args['courseId'],
                  courseName: args['courseName'],
                ),
              );
            }
          } else if (settings.name == '/instructor/add-student') {
            final args = settings.arguments as Map<String, dynamic>?;
            if (args != null) {
              return MaterialPageRoute(
                builder: (context) => AddStudentPage(
                  courseId: args['courseId'],
                  courseName: args['courseName'],
                ),
              );
            }
          }
          // Return null to let the routes table handle routes without parameters
          return null;
        },
      ),
    );
  }
}
