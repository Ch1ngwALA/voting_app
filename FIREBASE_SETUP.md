# Firebase Setup Guide for Voting App

## Step 1: Firebase Console Setup

### 1. Go to Firebase Console
Visit: https://console.firebase.google.com

### 2. Select Your Project
- Find and select your "dangoteadmin" project
- If you don't see it, you may need to create a new project

### 3. Enable Authentication

**Navigate to Authentication:**
1. In the left sidebar, click on "Build" → "Authentication"
2. Click "Get Started" if you haven't set it up yet
3. Go to the "Sign-in method" tab

**Enable Email/Password:**
1. Click on "Email/Password" in the list of providers
2. Toggle the first switch to **Enable**
3. You can leave "Email link (passwordless sign-in)" disabled for now
4. Click **Save**

### 4. Enable Firestore Database

**Navigate to Firestore:**
1. In the left sidebar, click on "Build" → "Firestore Database"
2. Click "Create database"
3. Choose "Start in test mode" (we'll add security rules later)
4. Select a location (choose one close to your users)
5. Click "Enable"

**Important:** Test mode rules allow anyone to read/write for 30 days. We'll add proper security rules later.

### 5. Verify Your App Registration

**Check Android App:**
1. Go to Project Settings (gear icon near "Project Overview")
2. Scroll down to "Your apps"
3. You should see an Android app registered
4. The package name should be: `com.voting.app.voting_app`
5. Make sure the `google-services.json` file is downloaded

**If Android app is not registered:**
1. Click "Add app" → Select Android icon
2. Enter package name: `com.voting.app.voting_app`
3. Enter a nickname: "Voting App"
4. Leave SHA-1 blank for now (used for Google Sign-In)
5. Click "Register app"
6. Download the `google-services.json` file
7. Place it in: `/Users/amazingeveryday/Downloads/voting_app/android/app/`

## Step 2: Verify Local Configuration

### 1. Check google-services.json
Make sure this file exists:
```
android/app/google-services.json
```

### 2. Verify firebase_options.dart
The file `lib/firebase_options.dart` should have valid configuration values (not placeholders).

## Step 3: Restart the App

After enabling Authentication in Firebase Console:

1. Stop the current app (press `q` in the terminal)
2. Run: `flutter clean`
3. Run: `flutter pub get`
4. Run: `flutter run -d emulator-5554`

## Step 4: Test the App

1. **Register a New Account:**
   - Open the app on the emulator
   - Click "Get Started"
   - Click "Register" 
   - Fill in the form with:
     - Name: Test Student
     - Email: student@test.com
     - Password: test123456
     - University: Test University
     - Department: Computer Science
     - Role: Select "Student"
   - Click "Register"

2. **If registration succeeds:**
   - You'll be redirected to the Student Dashboard
   - You can browse elections (none will exist yet)

3. **Create an Admin Account:**
   - Log out
   - Register again with:
     - Email: admin@test.com
     - Password: admin123456
     - Role: Select "Admin"
   - As admin, you can create elections and add candidates

## Common Issues & Solutions

### Issue: "CONFIGURATION_NOT_FOUND"
**Solution:** Email/Password authentication is not enabled in Firebase Console
- Go to Firebase Console → Authentication → Sign-in method
- Enable Email/Password provider

### Issue: "No Firebase App"
**Solution:** `google-services.json` is missing or misconfigured
- Download the file from Firebase Console → Project Settings
- Place it in `android/app/google-services.json`
- Run `flutter clean && flutter pub get`

### Issue: "Network Error" or "Permission Denied"
**Solution:** Firestore is not enabled or has wrong rules
- Enable Firestore in Firebase Console
- Start in test mode (allows all read/write for testing)

## Step 5: Add Security Rules (After Testing)

Once you've tested the app and everything works, add proper security rules:

### Firestore Security Rules
1. Go to Firebase Console → Firestore Database
2. Click on "Rules" tab
3. Replace the content with:

```javascript
rules_version = '2';
service cloud.firestore {
  match /databases/{database}/documents {
    // Helper function to check if user is authenticated
    function isSignedIn() {
      return request.auth != null;
    }
    
    // Helper function to check if user is admin
    function isAdmin() {
      return isSignedIn() && 
        get(/databases/$(database)/documents/users/$(request.auth.uid)).data.role == 'UserRole.admin';
    }
    
    // Users can read and write their own user document
    match /users/{userId} {
      allow read: if isSignedIn() && request.auth.uid == userId;
      allow create: if isSignedIn() && request.auth.uid == userId;
      allow update: if isSignedIn() && request.auth.uid == userId;
    }
    
    // Elections can be read by authenticated users, written by admins
    match /elections/{electionId} {
      allow read: if isSignedIn();
      allow create, update, delete: if isAdmin();
    }
    
    // Candidates can be read by authenticated users, written by admins
    match /candidates/{candidateId} {
      allow read: if isSignedIn();
      allow create, update, delete: if isAdmin();
    }
    
    // Votes can only be created by the voting user, never read
    match /votes/{voteId} {
      allow create: if isSignedIn() && request.auth.uid == request.resource.data.userId;
      allow read, update, delete: if false;
    }
    
    // Election requests can be created by students, read by all, updated by admins
    match /election_requests/{requestId} {
      allow read: if isSignedIn();
      allow create: if isSignedIn();
      allow update: if isAdmin();
    }
  }
}
```

4. Click "Publish"

## Step 6: Next Steps

After successful setup:

1. **Create Test Elections** (as admin):
   - Log in as admin@test.com
   - Go to Admin Dashboard
   - Create a new election with start/end dates
   - Add 2-3 candidates

2. **Test Voting** (as student):
   - Log in as student@test.com
   - Browse elections
   - Vote for a candidate
   - See real-time results

3. **Test Real-time Updates**:
   - Open the app on multiple devices/emulators
   - Vote from one device
   - See results update in real-time on the other

## Support

If you encounter any issues:
1. Check the console logs in your terminal
2. Check the Android Logcat in the emulator
3. Verify all Firebase services are enabled
4. Make sure your internet connection is working
5. Try `flutter clean && flutter pub get && flutter run`

## Useful Commands

```bash
# Clean project
flutter clean

# Get dependencies
flutter pub get

# Run on Android
flutter run -d emulator-5554

# Hot reload (while app is running)
press 'r'

# Hot restart (while app is running)
press 'R'

# View logs
flutter logs
```
