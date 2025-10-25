CustomCraft App
CustomCraft App is a comprehensive Flutter-based management application designed for carpentry, construction, and contracting businesses. It provides a full suite of tools for administrators and employees to manage the entire lifecycle of a project, from initial quotation to final payroll calculation.

The app is built on a modern, cloud-first architecture using Firebase for real-time data synchronization, authentication, and configuration, ensuring that all users have up-to-the-minute information whether they are in the office or on the job site.

Key Features
For Administrators
Admin Dashboard: A central app to view all ongoing, on-hold, and completed projects.

Project Management: Create new projects, assign workers, designate project leaders, and link projects to quotations.

User Management: A dedicated screen to view, edit, and manage all users in the system, including the ability to grant or revoke administrator privileges.

Financial Insights: A financial dashboard providing a clear overview of each project's budget, total payouts, and profit/loss, as well as a summary for the entire business.

Payroll Calculation: A streamlined process for entering a total project budget for completed projects, which automatically calculates and distributes payouts to each worker based on their logged attendance.

Attendance Viewer: A global attendance viewer to see who was present or absent on any given day across all active projects.

Company Settings: A secure page to update company-wide information like name and contact details, which are then reflected across the app (e.g., in PDF quotations).

For All Users (Employees & Leaders)
Role-Based Dashboards: Users see a dashboard tailored to their role, showing only the projects they are assigned to.

Attendance Tracking: Project leaders can easily mark attendance for team members (present or absent) for each day.

Offline Support: Attendance can be marked even without an internet connection. The app saves the data locally and automatically syncs it to the cloud once a connection is available.

Payout Transparency: Employees can see their final calculated payout for each completed project directly on their dashboard.

Personal Registers: A private, secure space for users to manage their own small side-projects and track attendance for personal contacts, completely separate from company data.

Quotation Management: Create detailed, multi-category quotations, save them to the cloud, and share them as professional PDF documents or plain text.

Technical Setup
1. Prerequisites
Flutter SDK (version 3.x or higher)

A Firebase project.

2. Firebase Configuration
This project is configured to work with Firebase. You will need to:

Create a new Firebase project in the Firebase Console.

Enable the following services:

Authentication: Enable the Email/Password sign-in method.

Firestore Database: Create a new database.

Firebase Storage: Create a new storage bucket.

Register your application (iOS, Android, Web) with the Firebase project and download the respective configuration files (google-services.json for Android, etc.). Place these files in the correct directories as per the Firebase documentation.

Update the lib/firebase_options.dart file with the configuration keys from your Firebase project.

3. Firestore Security Rules
For the app to function securely, you must update your Firestore security rules. Copy the entire contents of the firestore.rules file in the project root into your Firestore Database > Rules editor in the Firebase Console and publish the changes.

4. Running the App
Clone the repository.

Ensure you have the necessary Firebase configuration files in place.

Run the following commands in your terminal:

# Install all project dependencies
flutter pub get

# Generate the necessary code for the local database (Drift)
flutter pub run build_runner build

Run the app on your desired device or simulator:

flutter run
