# flutter_application_1

This project is aimed to track your placement and internship companies ppt, test and application deadline.

It uses your gmail to read emails from channeli, and create events regarding that directly in your calendar to remind you.

## Getting Started
- Turn on email feature of channeli for PIC notifications (from channeli) and for PIC portal both (it's optional for portal).
- Use your iitr email for login. (So it can read emails from channeli)
- Give permission to edit your calendar.
- Give your gemini api key. (Ofcourse free one, we won't exhaust your limit. Still to be on safer side, provide key for which billing is turned off.) (It will be used to parse your emails, maybe you can design a better parser but not me😂.)
- By default, you will get a reminder x mins. before the event. This x is default in your calendar app. Set it as you want.
- If you see that this app tracks some companies/roles which you dont want to track then just mark them as rejected (then it would also ignore future mails from that company/role).
- Yeah you can delete those roles/companies also, but future mails regarding those roles/companies will again create those entries in case of deletion.

## For Devs
### Known Issues
- [ ] Currently using `gemma-3-27b-it`. It's support might be removed in future by google as new models come into use. Need to maintain this. Also this model doesn't support instruction based chat.
- [ ] Handle `permission expiration` in background tasks. It generates error in background as we cant trigger UI actions in background.
- [ ] Need to `log whole background process`, so I can test see whether it is working or not, on end-devices.
- [ ] I need to check about this GMAIL api. It would be user based or beared by dev.
- [ ] To increase the scope of GMAIL query, we can ignore big tables and process all emails from channeli (pic), (currently only emails with subject submission of bio data are being processsed). Also we can insure each new line is in next line. 

### Improvements
- [ ] explicit refresh option when swipping up for interested and non-interested screen.
- [ ] Improve GMAIL search query.
- [ ] Improve gemini system prompt.
- [ ] Current project can only handle 1 test per role.
    - This could be improved by changing the schema of local db.
- [ ] How would users know that, which mails are already processed by this app? Background tasks trigger in every 1 hour (hardcoded). But due to android restrictions this periodicity is not uniform. although app would not miss any email in any window.

## debug filter

!EGL_emulation, !Choreographer, !RemoteInputConnectionImpl, !ImeTracker, !OpenGLRenderer, !TextInputPlugin, !InsetsController, !InputMethodManager

## helper commands
- `adb pull /storage/emulated/0/Android/data/com.example.flutter_application_1/files/app.log ./app.log`
