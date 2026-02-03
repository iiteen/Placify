# ![Logo](assets\icon\readme_icon.png) Placify

**Placify** is a Flutter-based application that helps students effortlessly track **placement and internship opportunities** by automatically monitoring important emails and setting timely reminders.

The app scans official placement-related emails, extracts key details such as **PPTs, tests, and application deadlines**, and creates corresponding **calendar events** so you never miss an important update.

## Features

- Reads placement-related emails from **Channeli**
- Automatically creates **calendar reminders** for deadlines and events
- Uses **Gemini AI** to intelligently parse email content
- Option to ignore or reject specific companies or roles
- Runs as a **background service** for continuous tracking

## Demo Video

Watch the full demo here:  
**YouTube:**  
[![Placify Demo](https://img.youtube.com/vi/bgKUzG64VU8/0.jpg)](https://www.youtube.com/watch?v=bgKUzG64VU8)

## Getting Started

Follow these steps to set up Placify on your device:

### 1. Channeli Configuration
- Enable **email notifications** on Channeli:
  - PIC **Noticeboard** (required)
  - PIC **Portal** (optional)

### 2. Login
- Sign in using your **IITR email ID**  
  *(Required to access Channeli emails)*

### 3. Permissions
- Grant permission to:
  - **Read & edit your calendar**
  - **Read emails** (only placement-related)

### 4. Gemini API Key
- Provide a **Gemini API key** (free tier is sufficient)
- Billing **should be disabled** for safety
- Used only to parse email content, not for storage

Get your API key here:  
https://aistudio.google.com/api-keys

### 5. Start Background Service
- Enable the background service from the app to allow continuous tracking.

## App Behavior & Controls

- If the app tracks a **company or role you’re not interested in**, mark it as **Rejected**.
  - Future emails for that company/role will be ignored.
- You may delete tracked entries, but:
  - If new emails arrive for the same role/company, they will be re-added automatically.

## Privacy & Security

- Emails are accessed **only** to extract placement-related information.
- No email content is stored or shared externally.
- Gemini API is used strictly for **text parsing**.
- User data remains on the device.

## Debug Log Filters

Useful filters while debugging:  
```bash
!EGL_emulation, !Choreographer, !RemoteInputConnectionImpl, !ImeTracker, !OpenGLRenderer, !TextInputPlugin, !InsetsController, !InputMethodManager
```

## Developer Utilities

Helpful commands for development and debugging:

```bash
# Pull app logs
adb pull /storage/emulated/0/Android/data/com.iiteens.placify/files/app.log ./app.log

# Wireless debugging
adb pair IP_ADDRESS:PORT
adb connect IP_ADDRESS:PORT

# Generate launcher icons
flutter pub run flutter_launcher_icons
```