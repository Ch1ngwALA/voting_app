# University Voting App

A comprehensive Flutter application for conducting secure, transparent university elections with real-time voting results and notifications.

## Features

### For Students
- **Account Registration**: Create accounts with university and department information
- **Secure Authentication**: Email/password login with Firebase Auth
- **Browse Elections**: View active and upcoming elections for your university/department
- **Cast Votes**: Participate in active elections with secure, anonymous voting
- **Real-time Results**: See live voting progress and results
- **Election Requests**: Submit requests for new elections via contact form
- **Notifications**: Receive updates when results are announced

### For Administrators
- **Election Management**: Create and manage elections with candidates
- **Candidate Profiles**: Add candidates with profiles and manifestos
- **Request Handling**: Review and approve election requests from students
- **Real-time Monitoring**: Monitor voting progress and results in real-time
- **Date Management**: Set election start and end dates with automatic expiration

## Technical Stack

- **Frontend**: Flutter (Dart)
- **Backend**: Firebase Firestore
- **Authentication**: Firebase Auth (Email/Password)
- **Real-time Updates**: Firestore real-time listeners
- **State Management**: Provider
- **Navigation**: GoRouter
- **UI Framework**: Material Design 3

## Project Structure

```
lib/
├── main.dart                 # App entry point
├── firebase_options.dart     # Firebase configuration
├── models/                   # Data models
│   ├── user.dart
│   ├── election.dart
│   ├── candidate.dart
│   └── vote.dart
├── services/                 # Business logic
│   ├── auth_service.dart
│   └── firestore_service.dart
├── screens/                  # UI screens
│   ├── home/
│   ├── auth/
│   ├── admin/
│   ├── student/
│   ├── elections/
│   └── contact/
└── utils/
    └── app_theme.dart
```

## Getting Started

### Prerequisites

1. **Flutter SDK**: Install Flutter from [flutter.dev](https://flutter.dev/docs/get-started/install)
2. **Firebase Project**: Create a new Firebase project at [console.firebase.google.com](https://console.firebase.google.com)
3. **VS Code Extensions**: Install Dart and Flutter extensions

### Setup Instructions

1. **Clone the repository**
   ```bash
   git clone <repository-url>
   cd voting_app
   ```

2. **Install dependencies**
   ```bash
   flutter pub get
   ```

3. **Configure Firebase**
   
   a. Install FlutterFire CLI:
   ```bash
   dart pub global activate flutterfire_cli
   ```
   
   b. Configure Firebase for your project:
   ```bash
   flutterfire configure
   ```
   
   c. Enable Authentication and Firestore in Firebase Console:
   - Go to Authentication > Sign-in method
   - Enable Email/Password provider
   - Go to Firestore Database
   - Create database in production mode

4. **Update Firebase Options**
   - Replace the placeholder values in `lib/firebase_options.dart` with your actual Firebase configuration

5. **Run the app**
   ```bash
   flutter run
   ```

## Firebase Setup Details

### Authentication
Enable Email/Password authentication in the Firebase Console:
1. Go to Authentication > Sign-in method
2. Click on Email/Password
3. Enable both Email/Password and Email link options
4. Save the configuration

### Firestore Database
Create the following collections in your Firestore database:

```
users/
├── {userId}/
│   ├── email: string
│   ├── name: string
│   ├── university: string
│   ├── department: string
│   ├── role: string
│   └── createdAt: timestamp

elections/
├── {electionId}/
│   ├── name: string
│   ├── description: string
│   ├── university: string
│   ├── department: string
│   ├── startDate: timestamp
│   ├── endDate: timestamp
│   ├── status: string
│   ├── createdBy: string
│   ├── candidateIds: array
│   └── votes: map

candidates/
├── {candidateId}/
│   ├── userId: string
│   ├── electionId: string
│   ├── name: string
│   ├── email: string
│   ├── university: string
│   ├── department: string
│   ├── manifesto: string
│   └── profileImageUrl: string

votes/
├── {voteId}/
│   ├── userId: string
│   ├── electionId: string
│   ├── candidateId: string
│   └── timestamp: timestamp

election_requests/
├── {requestId}/
│   ├── requesterId: string
│   ├── electionName: string
│   ├── description: string
│   ├── university: string
│   ├── department: string
│   ├── proposedStartDate: timestamp
│   ├── proposedEndDate: timestamp
│   ├── status: string
│   └── createdAt: timestamp
```

### Security Rules
Add these Firestore security rules:

```javascript
rules_version = '2';
service cloud.firestore {
  match /databases/{database}/documents {
    // Users can read and write their own user document
    match /users/{userId} {
      allow read, write: if request.auth != null && request.auth.uid == userId;
    }
    
    // Elections can be read by authenticated users, written by admins
    match /elections/{electionId} {
      allow read: if request.auth != null;
      allow write: if request.auth != null && 
        get(/databases/$(database)/documents/users/$(request.auth.uid)).data.role == 'UserRole.admin';
    }
    
    // Candidates can be read by authenticated users
    match /candidates/{candidateId} {
      allow read: if request.auth != null;
      allow write: if request.auth != null && 
        get(/databases/$(database)/documents/users/$(request.auth.uid)).data.role == 'UserRole.admin';
    }
    
    // Votes can only be created by the voting user, never read
    match /votes/{voteId} {
      allow create: if request.auth != null && 
        request.auth.uid == resource.data.userId;
      allow read, update, delete: if false;
    }
    
    // Election requests can be created by students, managed by admins
    match /election_requests/{requestId} {
      allow read: if request.auth != null;
      allow create: if request.auth != null && request.auth.uid == resource.data.requesterId;
      allow update: if request.auth != null && 
        get(/databases/$(database)/documents/users/$(request.auth.uid)).data.role == 'UserRole.admin';
    }
  }
}
```

## Key Features Implementation

### Real-time Voting Results
- Uses Firestore real-time listeners to show live vote counts
- Updates automatically as votes are cast
- Displays progress bars and percentages

### Secure Voting
- Each user can only vote once per election
- Votes are anonymous but tracked to prevent duplicate voting
- Election deadlines are automatically enforced

### Role-based Access
- Students can vote and request elections
- Admins can create elections and manage candidates
- Different dashboards based on user roles

### Election Lifecycle
- Elections have pending, active, completed, and cancelled states
- Automatic status updates based on start/end dates
- Vote counting stops automatically when elections end

## Development

### Running Tests
```bash
flutter test
```

### Building for Production
```bash
# Android
flutter build apk --release

# iOS
flutter build ios --release
```

## Contributing

1. Fork the repository
2. Create a feature branch
3. Make your changes
4. Add tests if applicable
5. Submit a pull request

## License

This project is licensed under the MIT License - see the LICENSE file for details.

## Support

For support and questions:
- Create an issue in this repository
- Contact the development team
- Check the documentation

## Roadmap

Future enhancements planned:
- [ ] Push notifications for election updates
- [ ] Email verification for account registration
- [ ] Advanced analytics and reporting
- [ ] Multi-language support
- [ ] Candidate image uploads
- [ ] Election templates
- [ ] Bulk candidate import
- [ ] Advanced security features