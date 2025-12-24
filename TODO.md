## For Devs
### Known Issues
- [ ] Currently using `gemma-3-27b-it`. It's support might be removed in future by google as new models come into use. Need to maintain this. Also this model doesn't support instruction based chat.
- [ ] Handle `permission expiration` in background tasks. It generates error in background as we cant trigger UI actions in background.
- [ ] I need to check about this GMAIL api. It would be user based or beared by dev.

## TODO
- [x] Need to `log whole background process`, so I can test see whether it is working or not, on end-devices.
- [x] explicit refresh option when swipping up for interested and non-interested screen.
- [x] To increase the scope of GMAIL query, we can ignore big tables and process all emails from channeli (pic), (currently only emails with subject submission of bio data are being processsed). Also we can insure each new line is in next line.
- [x] GMAIL token expiry handling.


### Improvements which can be done
- [ ] Improve GMAIL search query.
- [ ] Improve gemini system prompt. `prompt engineering`
- [ ] Current project can only handle 1 test per role.
    - This could be improved by changing the schema of local db.
- [ ] How would users know that, which mails are already processed by this app? Background tasks trigger in every 1 hour (hardcoded). But due to android restrictions this periodicity is not uniform. although app would not miss any email in any window.