# SIP Phone

A lightweight SIP-style softphone demo built with Flutter on the frontend and a Dart HTTP server on the backend. The app allows a user to sign in with a name, extension, email, and password, place a call, and view recent call activity from the backend.

## Features

- Modern softphone-style UI
- User sign-in flow with token-based authentication
- Call logging to a local backend API
- Recent call history retrieval
- Mobile and desktop responsive layout
- Local development setup for frontend and backend

## Tech Stack

- Frontend: Flutter
- Backend: Dart
- API communication: HTTP
- State management: built into the app using standard Flutter widgets and controllers

## Prerequisites

Before running the project, make sure you have the following installed:

- Flutter SDK
- Dart SDK
- A supported IDE such as VS Code or Android Studio

## Project Setup

1. Clone the repository
2. Open the project in your editor
3. Make sure Flutter is installed and configured correctly

## Run the Backend

From the project root, run:

```bash
cd backend
dart run server.dart
