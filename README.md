# Smart Attendance System

A Flutter-based mobile application for managing student attendance using face recognition technology.

## Features

- Face Recognition based attendance
- Student and Instructor portals
- Course management
- Real-time attendance tracking
- Firebase integration for data storage and authentication

## Technologies Used

- Flutter
- Firebase (Authentication, Firestore, Storage)
- Face Recognition
- Provider State Management

## Setup Instructions

1. Clone the repository:
   ```bash
   git clone https://github.com/Nabeel-Shehzad/smart_attendance.git
   ```

2. Install dependencies:
   ```bash
   flutter pub get
   ```

3. Configure Firebase:
   - Make sure you have firebase_options.dart file in the lib directory
   - Ensure google-services.json is present in android/app/
   - Verify GoogleService-Info.plist is in ios/Runner/

4. Run the application:
   ```bash
   flutter run
   ```

## Project Structure

- `lib/screens/` - Contains all the UI screens
- `lib/providers/` - State management using Provider
- `lib/models/` - Data models
- `lib/services/` - Business logic and API services

## Contributing

Feel free to submit issues and enhancement requests.

## License

This project is licensed under the MIT License.
