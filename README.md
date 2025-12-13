# flutter_application_1

A new Flutter project.

## Getting Started

This project is a starting point for a Flutter application.

A few resources to get you started if this is your first Flutter project:

- [Lab: Write your first Flutter app](https://docs.flutter.dev/get-started/codelab)
- [Cookbook: Useful Flutter samples](https://docs.flutter.dev/cookbook)

For help getting started with Flutter development, view the
[online documentation](https://docs.flutter.dev/), which offers tutorials,
samples, guidance on mobile development, and a full API reference.

## Known Issues

- [ ] Currently using `gemma-3-27b-it`. It's support might be removed in future. Need to maintain this. Also this model doesn't support instruction based chat.
- [ ] Handle `permission expiration` in background tasks. It generates error in background as we cant trigger UI actions in background.
- [ ] Need to `log whole background process`, so I can see whether it is working or not.

## debug filter

!EGL_emulation, !Choreographer, !RemoteInputConnectionImpl, !ImeTracker, !OpenGLRenderer, !TextInputPlugin, !InsetsController, !InputMethodManager