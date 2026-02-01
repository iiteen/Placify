import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:url_launcher/url_launcher.dart';

import '../services/background_logic_test.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  final _controller = TextEditingController();
  bool _saving = false;
  bool _running = false;

  static const _kGeminiKey = "gemini_api_key";

  @override
  void initState() {
    super.initState();
    _loadKey();
  }

  Future<void> _loadKey() async {
    final prefs = await SharedPreferences.getInstance();
    _controller.text = prefs.getString(_kGeminiKey) ?? '';
  }

  Future<void> _saveKey() async {
    setState(() => _saving = true);

    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_kGeminiKey, _controller.text.trim());

    setState(() => _saving = false);

    if (!mounted) return;
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(const SnackBar(content: Text("Gemini API key saved.")));
  }

  /// 🔥 RUN EMAIL PROCESSOR DIRECTLY (NO WORKMANAGER)
  Future<void> _runNow() async {
    setState(() => _running = true);

    try {
      final prefs = await SharedPreferences.getInstance();
      final key = prefs.getString(_kGeminiKey) ?? '';

      if (key.isEmpty) {
        throw Exception("Gemini API key not set");
      }

      await runEmailProcessingOnceForDebug();

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Email processor finished successfully")),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text("Error: $e")));
    } finally {
      if (mounted) setState(() => _running = false);
    }
  }

  Future<void> _openGithub() async {
    final Uri url = Uri.parse('https://github.com/iiteen/Placify');

    // Capture context safely before any async gap
    final ctx = context;

    try {
      // Launch in external browser (async)
      final launched = await launchUrl(
        url,
        mode: LaunchMode.externalApplication,
      );

      // Only use context after async if ctx.mounted
      if (!launched && ctx.mounted) {
        ScaffoldMessenger.of(ctx).showSnackBar(
          const SnackBar(content: Text("Could not open GitHub link")),
        );
      }
    } catch (e) {
      if (ctx.mounted) {
        ScaffoldMessenger.of(
          ctx,
        ).showSnackBar(SnackBar(content: Text("Error launching URL: $e")));
      }
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("Settings")),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ---------- API KEY ----------
            TextField(
              controller: _controller,
              decoration: const InputDecoration(
                labelText: 'Gemini API Key',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 12),

            // ---------- SAVE ----------
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: _saving ? null : _saveKey,
                child: _saving
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Text('Save'),
              ),
            ),

            const SizedBox(height: 12),

            // ---------- RUN NOW ----------
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                icon: const Icon(Icons.play_arrow),
                style: ElevatedButton.styleFrom(backgroundColor: Colors.green),
                onPressed: _running ? null : _runNow,
                label: _running
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Colors.white,
                        ),
                      )
                    : const Text("Run Email Processor Now"),
              ),
            ),

            const Spacer(),
            // ---------- GITHUB ----------
            // GitHub link
            Center(
              child: GestureDetector(
                onTap: _openGithub,
                child: const Text(
                  "View on GitHub • FAQ • Issues • Help",
                  style: TextStyle(
                    color: Colors.blue,
                    decoration: TextDecoration.underline,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
