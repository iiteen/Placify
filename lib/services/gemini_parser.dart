import 'package:google_generative_ai/google_generative_ai.dart';
import 'package:shared_preferences/shared_preferences.dart';

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
You are an advanced parser for IIT placement cell emails.

Your task is to extract structured placement information from extremely inconsistent email formats.

IMPORTANT:
- The email was received at the datetime provided in the 'EMAIL RECEIVED DATETIME' field.
- Use this as reference to interpret relative date terms.
- Always convert all dates/times to absolute ISO 8601 format (YYYY-MM-DDTHH:MM) in your output.

OUTPUT REQUIREMENTS:
- Return ONLY valid JSON.
- No explanation, no comments, no extra text.
- Every value must be either a string or null.
- All datetime values must be ISO 8601: YYYY-MM-DDTHH:MM.

FINAL JSON STRUCTURE:
{
  "company": string or null,
  "application_deadline": string or null,
  "ppt": {
    "datetime": string or null,
    "venue": string or null
  },
  "roles": [
    {
      "name": string,
      "tests": [
        {
          "name": string or null,
          "datetime": string or null
        }
      ]
    }
  ]
}

=====================================
CRITICAL EXTRACTION EXAMPLES (FEW-SHOT)
=====================================
Input Line: "PPT Date & 15 December 2025 at 11:44: 16th December 2025, 11 AM"
Correction: Ignore "15 December 2025 at 11:44". Extract only "16th December 2025, 11 AM".
Output: "2025-12-16T11:00"

Input Line: "Test Date & 01 Jan 2025 at 09:00: 05 Jan 2025, 5 PM"
Correction: Ignore "01 Jan...". Extract "05 Jan 2025, 5 PM".
Output: "2025-01-05T17:00"

Input Line: "Profile: Software Engineer\nEligibility:\nB.Tech. (Computer Science)\nB.Tech. (Electrical Engineering)\nM.Tech. (V.L.S.I)"
Correction: "Software Engineer" IS a role. The B.Tech/M.Tech lines are ELIGIBILITY. Do not extract branches as roles.
Output Roles: [{"name": "Software Engineer", "tests": []}]

=====================================
RULES & EXTRACTION LOGIC
=====================================

1. COMPANY NAME
- Extract from any part of the email.
- Prefer the most formal and complete mention.

2. ROLES (STRICT BLOCKLIST)
- Identify roles from labels: "Profile", "Role", "Position", "Designation".
- **CRITICAL NEGATIVE CONSTRAINTS (WHAT IS NOT A ROLE)**:
    - NEVER extract academic degrees or branches as roles.
    - IF A LINE CONTAINS: "B.Tech", "M.Tech", "B.Arch", "B.Des", "Dual Degree", "M.Sc", "PhD", "BS-MS", "Integrated M.Tech" -> **DISCARD IT IMMEDIATELY**.
    - IF A LINE CONTAINS: "Civil Engineering", "Computer Science", "Electrical Engineering", "Mechanical", "Production" -> **DISCARD IT IMMEDIATELY** (unless explicitly preceded by 'Profile:').
    - Do NOT extract "Eligible Branches", "Streams", "Departments" as roles.
- Example: "Profile: SDE (CSE/ECE)" -> Role is "SDE".
- Example: "B.Tech (CSE)" appearing in a list -> IGNORE completely.
- If a role has no associated tests, return "tests": [].

3. APPLICATION DEADLINE
- Match phrases: "Deadline", "Last Date", "Application Deadline".

4. PPT (PRE-PLACEMENT TALK)
- Detect using: "PPT", "Pre-Placement Talk", "Corporate Presentation".
- Only one PPT object exists.

5. TESTS (STRICT DEFINITION)
- Test indicators: "Test", "Aptitude", "Coding Round", "Online Assessment", "Exam", "OA".
- NEGATIVE CONSTRAINTS (WHAT IS NOT A TEST):
    - STRICTLY IGNORE "Interviews", "Personal Interview", "PI", "Technical Interview", "HR Round".
    - STRICTLY IGNORE "Resume-Based Shortlisting", "Resume Shortlisting", "Shortlisting", "CV Selection".
    - STRICTLY IGNORE "Group Discussion", "GD".
    - Do NOT add these to the 'tests' array. If an event falls into these categories, discard it.
- A test is assigned to a role only if:
    a) It appears near that role, OR
    b) It explicitly mentions that role.
- If a test line is generic, assign it to ALL roles.

6. DATE & TIME CLEANING (STRICT)
- CORRUPTED DATA PATTERN: "Label & [Garbage Date] : [Correct Date]"
- RULE: If a line contains the symbol '&' followed by a date/time, and then a colon ':', you must IGNORE everything before the colon.
- The text between '&' and ':' is a system update timestamp and MUST be discarded.
- ONLY extract the date and time found to the RIGHT of the colon.
- Example: "Test Date & 15 Dec at 10:00 : 18 Dec at 2 PM" -> Result must be 18th Dec at 2 PM.

7. JSON STRICTNESS
- No trailing commas. Missing values must be null.

8. TBD RULE
- If a field says "TBD", "To be decided", or "Later" -> Output null.
""";

  Future<String> parseEmail({
    required String subject,
    required String body,
    required String emailReceivedDateTime,
  }) async {
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
}
