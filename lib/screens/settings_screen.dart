import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  final _controller = TextEditingController();
  bool _loading = false;

  static const _kGeminiKey = "gemini_api_key";

  @override
  void initState() {
    super.initState();
    _loadKey();
  }

  /// Load saved Gemini API key
  Future<void> _loadKey() async {
    final prefs = await SharedPreferences.getInstance();
    final k = prefs.getString(_kGeminiKey) ?? '';
    _controller.text = k;
  }

  /// Save Gemini API key
  Future<void> _saveKey() async {
    setState(() => _loading = true);

    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_kGeminiKey, _controller.text.trim());

    setState(() => _loading = false);

    if (!mounted) return;

    ScaffoldMessenger.of(
      context,
    ).showSnackBar(const SnackBar(content: Text("Gemini API key saved.")));
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
            TextField(
              controller: _controller,
              decoration: const InputDecoration(
                labelText: 'Gemini API Key',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 12),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: _loading ? null : _saveKey,
                child: _loading
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Text('Save'),
              ),
            ),
            const SizedBox(height: 8),
            const Text(
              'The background processor will use this key to parse emails with Gemini.',
              style: TextStyle(fontSize: 12),
            ),
          ],
        ),
      ),
    );
  }
}
