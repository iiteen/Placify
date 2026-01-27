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
- [ ] Now test the workflow on some real devices.

## Edge cases
- [x] company: null (no need to process further)
- [x] roles: (if empty then skip)
    - but if roles: [{name: null, tests:[]}] (info of application_deadline, ppt, and roles should be updated for each role.)
    - also if roles: [{name: null, tests:[]}] (is point of loss of info as per current algo.)
    - <details>
      <summary>JSON return from gemini</summary>

      ```json
      {
        "company": string or null,
        "application_deadline": string or null,
        "ppt": {
          "datetime": string or null,
          "venue": string or null
        },
        "roles": [
          {
            "name": string or null,
            "tests": [
              {
                "name": string or null,
                "datetime": string or null
              }
            ]
          }
        ]
      }
      ```
      </details>

- [x] ignoring all emails with subject "shortlist for interviews"

## some more errors while background tasks.
- [x] error when token limit exceeded
    - prompt too large, error 500 (trim in half, wait & retry).
    - model overloaded / rate limit, error 503 (wait & retry).
    - <details>
      <summary>error</summary>

      ```log
      [2026-01-22T12:52:36.124427] ❌ Error processing 19bdfd046260b08e: GenerativeAIException: Server Error [503]: {
        "error": {
          "code": 503,
          "message": "The model is overloaded. Please try again later.",
          "status": "UNAVAILABLE"
        }
      }

      #0      HttpApiClient.makeRequest (package:google_generative_ai/src/client.dart:66:7)
      <asynchronous suspension>
      #1      parseGenerateContentResponse (package:google_generative_ai/src/api.dart:581:1)
      <asynchronous suspension>
      #2      GeminiParser.parseEmail (package:flutter_application_1/services/gemini_parser.dart:361:22)
      <asynchronous suspension>
      #3      callbackDispatcher.<anonymous closure> (package:flutter_application_1/services/background_service.dart:182:29)
      <asynchronous suspension>
      #4      _WorkmanagerFlutterApiImpl.executeTask (package:workmanager/src/workmanager_impl.dart:326:20)
      <asynchronous suspension>
      #5      WorkmanagerFlutterApi.setUp.<anonymous closure> (package:workmanager_platform_interface/src/pigeon/workmanager_api.g.dart:903:33)
      <asynchronous suspension>
      #6      BasicMessageChannel.setMessageHandler.<anonymous closure> (package:flutter/src/services/platform_channel.dart:259:36)
      <asynchronous suspension>
      #7      _DefaultBinaryMessenger.setMessageHandler.<anonymous closure> (package:flutter/src/services/binding.dart:665:22)
      <asynchronous suspension>
      ```
      </details>

- [x] error when internet disconnected
    - handled using workmanager constraints
    - <details>
      <summary>error</summary>

      ```log
      [2026-01-23T03:56:25.656449] ❌ Gmail background sign-in failed.
      tion(channel-error, Unable to establish connection on channel: "dev.flutter.pigeon.google_sign_in_android.GoogleSignInApi.signIn"., null, null)
      #0      GoogleSignInApi.signIn (package:google_sign_in_android/src/messages.g.dart:253:7)
      <asynchronous suspension>
      #1      GoogleSignInAndroid._signInUserDataFromChannelData (package:google_sign_in_android/google_sign_in_android.dart:114:3)
      <asynchronous suspension>
      #2      GoogleSignIn._callMethod (package:google_sign_in/google_sign_in.dart:282:30)
      <asynchronous suspension>
      #3      GoogleSignIn.signIn.isCanceled (package:google_sign_in/google_sign_in.dart:436:5)
      <asynchronous suspension>
      ```
      </details>

## Improvements which can be done
- [ ] Improve GMAIL search query.
- [ ] Improve gemini system prompt. `prompt engineering`
- [ ] Current project can only handle 1 test per role.
    - This could be improved by changing the schema of local db.
- [ ] How would users know that, which mails are already processed by this app? Background tasks trigger in every 1 hour (hardcoded). But due to android restrictions this periodicity is not uniform. although app would not miss any email in any window.
- [x] RoleNames can be null, (company came for ppt before announcing any roles).