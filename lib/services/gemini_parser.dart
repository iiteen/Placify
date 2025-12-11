import 'package:google_generative_ai/google_generative_ai.dart';

class GeminiParser {
  late final GenerativeModel _model;

  GeminiParser(String apiKey) {
    _model = GenerativeModel(
      model: "gemma-3-27b-it",
      apiKey: apiKey,
      // systemInstruction: Content.system(_systemPrompt),
    );
  }

  static const String _systemPrompt = """
You are an advanced parser for IIT placement cell emails.

Your task is to extract structured placement information from extremely inconsistent email formats.

IMPORTANT:
- The email was received at the datetime provided in the 'EMAIL RECEIVED DATETIME' field.
- Use this as reference to interpret relative date terms in the email, such as 'tomorrow', 'next Monday', 'yesterday', 'in 3 days', etc.
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
RULES & EXTRACTION LOGIC
=====================================

1. COMPANY NAME
- Extract from any part of the email.
- Prefer the most formal and complete mention.
- Ignore names that appear only in signatures.

2. ROLES
- Identify roles from labels such as:
  "Profile", "Profiles", "Role", "Position", "Job Description".
- Add every detected role to the roles array.
- If a role has no associated tests, return "tests": [].

3. APPLICATION DEADLINE
- Match phrases such as:
  "Deadline", "Last Date", "Last date to apply", "Application Deadline".
- Extract the nearest datetime to these phrases.

4. PPT (PRE-PLACEMENT TALK)
- Detect using:
  "PPT", "Pre Placement Talk", "Pre-Placement Talk", "Corporate Presentation".
- Only one PPT object exists.
- PPT applies to all roles.

5. TESTS (ROLE-SPECIFIC LOGIC)
- Test indicators include:
  "Test", "Aptitude", "Coding Round", "Online Assessment", "Exam", "Assessment".
- A test is assigned to a role only if:
    a) It appears near that role, OR
    b) It explicitly mentions that role, OR
    c) Different roles have different test timings.
- If a test applies to multiple roles and only one test is mentioned:
    → Assign the same test to ALL roles.

6. DATE & TIME FORMATTING
- Accept ANY date/time format found in the email.
- Use the 'EMAIL RECEIVED DATETIME' to interpret relative dates like 'tomorrow', 'next Monday', 'yesterday'.
- OUTPUT must always be absolute ISO 8601 (YYYY-MM-DDTHH:MM).
- If only a date is provided (no time):
      → Output YYYY-MM-DDT00:00.
- If no valid datetime is found:
      → Return null.

7. JSON STRICTNESS
- Always output valid JSON.
- Do not include trailing commas.
- Missing values must be null.

8. TBD (TO BE DECIDED) RULE — VERY IMPORTANT
- If a field (deadline, PPT time, test time) contains:
    "TBD", "To be decided", "To be determined", or "Yet to be decided":
      → Output null for that field.
- If BOTH a date/time AND a TBD indicator appear for the same field:
      → Treat the datetime as invalid.
      → Output null.
- The presence of TBD always overrides any conflicting datetime.
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
