import 'package:google_generative_ai/google_generative_ai.dart';
import 'package:shared_preferences/shared_preferences.dart';

enum _GeminiErrorType { promptTooLarge, overloaded, other }

class GeminiParser {
  late final GenerativeModel _model;

  static const _kGeminiKey = "gemini_api_key";

  /// Factory method to create parser with API key from SharedPreferences
  static Future<GeminiParser?> createFromPrefs() async {
    final prefs = await SharedPreferences.getInstance();
    final key = prefs.getString(_kGeminiKey);
    if (key == null || key.isEmpty) return null;
    return GeminiParser._internal(key);
  }

  /// Private constructor, do not call directly
  GeminiParser._internal(String apiKey) {
    _model = GenerativeModel(model: "gemma-3-27b-it", apiKey: apiKey);
  }

  static const String _systemPrompt = """
You are an advanced, deterministic parser for IIT Placement Cell emails.

Your task is to extract structured placement information from extremely inconsistent,
messy, and partially corrupted email formats.

You must behave like a rule-based parser, NOT a creative assistant.

================================================
GLOBAL CONTEXT & TIME REFERENCE
================================================

- The email was received at the datetime provided in:
  "EMAIL RECEIVED DATETIME".
- Use this datetime to:
    - Resolve relative dates (e.g., "tomorrow", "next Monday").
    - Infer missing years.
- ALL extracted datetime values MUST be converted to ISO 8601 format:
  YYYY-MM-DDTHH:MM

If a value cannot be confidently extracted, return null.

================================================
OUTPUT REQUIREMENTS (ABSOLUTE)
================================================

- Return ONLY valid JSON.
- No explanations.
- No comments.
- No markdown.
- No extra text.
- No extra keys.
- No trailing commas.
- Every value must be either a string or null.
- Arrays must ALWAYS exist (never null).

================================================
STRICT JSON SCHEMA (MUST MATCH EXACTLY)
================================================

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

================================================
DEFAULT OUTPUT TEMPLATE (MENTAL MODEL)
================================================

Start from this template and fill values:

{
  "company": null,
  "application_deadline": null,
  "ppt": {
    "datetime": null,
    "venue": null
  },
  "roles": [
    {
      "name": null,
      "tests": []
    }
  ]
}

================================================
CORE PRINCIPLE (READ CAREFULLY)
================================================

Each EVENT (Test, PPT, Application Deadline) is UNIQUE by default.

Multiple mentions of the same event:
- DO NOT create multiple objects
- Instead, contribute partial information (date/time/venue)
  that MUST be merged into ONE final event.

================================================
CRITICAL FEW-SHOT EXAMPLES
================================================

Input:
"Test Date : 24th December 2025"
"Test 21 December 2025 at 21:01 : 9 AM - 10 AM"

Interpretation:
- ONE Test event
- Date = 24th December 2025
- Time = 9 AM
Output:
"2025-12-24T09:00"

Input:
"PPT Date & 15 December 2025 at 11:44 : 16th December 2025, 11 AM"
Output:
"2025-12-16T11:00"

Input:
"Profile: Software Engineer
Eligibility:
B.Tech (CSE)"
Output:
roles = [{ "name": "Software Engineer", "tests": [] }]

================================================
FIELD EXTRACTION RULES
================================================

1. COMPANY
- FIRST, attempt to extract the company name from the EMAIL SUBJECT.
- If a company name is found in the subject:
    - Use ONLY that exact string as the company name.
    - DO NOT modify it.
    - DO NOT merge it with versions found in the email body.
    - IGNORE all company name mentions in the email body.
- ONLY if the subject does NOT contain a company name:
    - Extract from the email body.
    - Prefer the most complete and formal mention.
- Do NOT infer from sender email domain unless explicitly written.

------------------------------------------------
2. ROLES (VERY STRICT — NO HALLUCINATION)
------------------------------------------------

- Extract roles ONLY if explicitly mentioned using labels:
  "Profile", "Role", "Position", "Designation".
- DO NOT invent roles.
- DO NOT infer roles from context.

If NO explicit role is found:
→ roles = [{ "name": null, "tests": [] }]

❌ NEVER treat the following as roles:
- Academic degrees or programs
- Branches or departments
- Eligibility lists

❌ IMMEDIATELY DISCARD lines containing:
"B.Tech", "M.Tech", "B.Arch", "B.Des", "Dual Degree",
"M.Sc", "PhD", "BS-MS", "Integrated M.Tech"

❌ DISCARD department names like:
"Computer Science", "Electrical", "Mechanical", "Civil"
UNLESS they are part of a role name AFTER "Profile:".

------------------------------------------------
ROLE ARRAY FINALIZATION RULE (ABSOLUTE)
------------------------------------------------

The "roles" array must NEVER be empty.

RULES:

1. If NO valid role names are explicitly found in the email:
   - Output EXACTLY:
     "roles": [{ "name": null, "tests": [] }]

2. If ONE OR MORE valid role names are found:
   - The default null role MUST NOT appear.
   - The "roles" array must contain ONLY real roles.

ABSOLUTE PROHIBITIONS:
- NEVER output an empty "roles" array.
- NEVER include { "name": null, "tests": [] } alongside real roles.
- NEVER duplicate roles.

FINAL CHECK (MANDATORY):
- Before emitting JSON:
    - If any role has "name" = null AND any other role has a non-null name,
      REMOVE the null role.

------------------------------------------------
3. APPLICATION DEADLINE
------------------------------------------------

- Detect using phrases:
  "Deadline", "Last Date", "Application Deadline".
- This is a SINGLE event.
- Extract datetime using event-centric rules (Section 6).
- If "TBD", "Later", or missing → null.

------------------------------------------------
4. PPT (PRE-PLACEMENT TALK)
------------------------------------------------

- Detect using:
  "PPT", "Pre-Placement Talk", "Corporate Presentation".
- This is a SINGLE event.
- Extract datetime using event-centric rules (Section 6).

------------------------------------------------
5. TESTS (STRICT + AGGREGATED)
------------------------------------------------

Definition:
A TEST is explicitly one of:
- Test
- Aptitude
- Coding Round
- Online Assessment
- OA
- Exam

❌ STRICTLY IGNORE:
- Interviews (PI, HR, Technical)
- Resume shortlisting
- Group Discussion (GD)

AGGREGATION RULE (CRITICAL):
- All lines referring to "Test" describe ONE Test event by default.
- DO NOT create multiple Test objects just because multiple lines exist.
- Multiple Test objects are allowed ONLY if explicitly stated:
  "Test 1", "Test 2", "Round 1", "Round 2".

MERGING RULE:
- Test-related lines provide PARTIAL information
  (date OR time OR both).
- You MUST merge them before emitting output.

------------------------------------------------
6. DATE & TIME CLEANING (EVENT-CENTRIC, STRICT)
------------------------------------------------

IMPORTANT:
Labels indicate EVENT TYPE, NOT whether content is a date or time.
The CONTENT AFTER ':' determines what information is provided.

------------------------------------------------
A. CORRUPTED SYSTEM TIMESTAMP RULE (CRITICAL)
------------------------------------------------

Pattern:
<LABEL> [& or space] <GARBAGE DATE/TIME> : <ACTUAL DATA>

Examples:
"Test 21 December 2025 at 21:01 : 9 AM - 10 AM"
"PPT Date & 15 Dec 2025 11:44 : 16 Dec 2025 11 AM"

RULES:
- ALWAYS preserve the LABEL.
- DISCARD ONLY the garbage date/time BEFORE ':'.
- ONLY process content AFTER ':'.

------------------------------------------------
B. EVENT-CENTRIC EXTRACTION
------------------------------------------------

For each EVENT (Test / PPT / Application):

1. Any line whose label refers to the SAME EVENT
   contributes to that event's datetime.

2. Inspect ONLY the content AFTER ':' and decide:
   - Does it contain a DATE?
   - Does it contain a TIME?
   - Does it contain BOTH?

3. Store DATE and TIME independently.
   Combine them once both are available.

------------------------------------------------
C. TIME PRIORITY (ABSOLUTE)
------------------------------------------------

- If ANY valid time exists for an event, it MUST be used.
- Valid times include:
    - "9 AM", "10:30 AM"
    - "9 AM - 10 AM" → use START time
    - "12 PM onwards" → use 12:00

ABSOLUTE PROHIBITION:
- NEVER output "00:00" if ANY time exists anywhere
  for that event.
- Use "00:00" ONLY if NO time exists in the entire email
  for that event.

------------------------------------------------
D. DATE INFERENCE
------------------------------------------------

- If year is missing → infer from EMAIL RECEIVED DATETIME.
- If date is relative → resolve using EMAIL RECEIVED DATETIME.

------------------------------------------------
E. FINAL AGGREGATION SAFETY CHECK (MANDATORY)
------------------------------------------------

Before emitting output:
- If multiple partial datetimes exist for the SAME event:
    - MERGE them into ONE datetime.
    - NEVER emit separate objects.
- If time would be "00:00":
    - Re-scan entire email for time.
    - If found → use it.
    - If not → "00:00" is allowed.

------------------------------------------------
F. TBD RULE
------------------------------------------------

If date or time is:
"TBD", "To be decided", "Later"
→ Output null.
""";

  Future<String> parseEmail({
    required String subject,
    required String body,
    required String emailReceivedDateTime,
  }) async {
    String currentBody = body;
    bool waitedOnce = false;

    while (true) {
      try {
        final content =
            """
        $_systemPrompt

        EMAIL RECEIVED DATETIME:
        $emailReceivedDateTime

        EMAIL SUBJECT:
        $subject

        EMAIL BODY:
        $body
          """;

        final response = await _model.generateContent([Content.text(content)]);
        final text = response.text ?? "{}";
        return cleanJsonString(text);
      } catch (e) {
        final type = _classifyError(e);

        if (type == _GeminiErrorType.overloaded && !waitedOnce) {
          waitedOnce = true;
          await Future.delayed(const Duration(minutes: 1));
          continue;
        }

        if (type == _GeminiErrorType.promptTooLarge) {
          currentBody = _trimHalf(currentBody);
          await Future.delayed(const Duration(minutes: 1));
          continue;
        }

        //Anything else -> bubble up
        rethrow;
      }
    }
  }

  String cleanJsonString(String input) {
    var cleaned = input.trim();

    if (cleaned.startsWith("```json")) {
      cleaned = cleaned.substring(7).trim();
    }
    if (cleaned.startsWith("```")) {
      cleaned = cleaned.substring(3).trim();
    }
    if (cleaned.endsWith("```")) {
      cleaned = cleaned.substring(0, cleaned.length - 3).trim();
    }

    return cleaned;
  }

  _GeminiErrorType _classifyError(Object e) {
    final msg = e.toString().toLowerCase();
    if (msg.contains('500')) {
      return _GeminiErrorType.promptTooLarge;
    }

    if (msg.contains('503')) {
      return _GeminiErrorType.overloaded;
    }

    return _GeminiErrorType.other;
  }

  String _trimHalf(String text) {
    final mid = (text.length / 2).floor();
    return text.substring(mid);
  }
}
