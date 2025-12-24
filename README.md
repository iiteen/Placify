# flutter_application_1

This project is aimed to track your placement and internship companies ppt, test and application deadline.

It uses your gmail to read emails from channeli, and create events regarding that directly in your calendar to remind you.

## Getting Started
- Turn on email feature of channeli for PIC notifications (noticeboard) and for PIC portal both (it's optional for portal).
- Use your iitr email for login. (So it can read emails from channeli)
- Give permission to edit your calendar.
- Give your gemini api key. (Ofcourse free one, we won't exhaust your limit. Still to be on safer side, provide key for which billing is turned off.) (It will be used to parse your emails, maybe you can design a better parser but not me😂.)
- By default, you will get a reminder x mins. before the event. This x is default in your calendar app. Set it as you want.
- If you see that this app tracks some companies/roles which you dont want to track then just mark them as rejected (then it would also ignore future mails from that company/role).
- Yeah you can delete those roles/companies also, but future mails regarding those roles/companies will again create those entries in case of deletion.

## debug filter

!EGL_emulation, !Choreographer, !RemoteInputConnectionImpl, !ImeTracker, !OpenGLRenderer, !TextInputPlugin, !InsetsController, !InputMethodManager

## helper commands
- `adb pull /storage/emulated/0/Android/data/com.example.flutter_application_1/files/app.log ./app.log`
