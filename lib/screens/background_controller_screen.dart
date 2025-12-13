import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../services/background_service.dart';

class BackgroundControllerScreen extends StatefulWidget {
  const BackgroundControllerScreen({super.key});

  @override
  State<BackgroundControllerScreen> createState() =>
      _BackgroundControllerScreenState();
}

class _BackgroundControllerScreenState
    extends State<BackgroundControllerScreen> {
  bool _running = false;
  bool _busy = false;

  @override
  void initState() {
    super.initState();
    _refreshStatus();
  }

  Future<void> _refreshStatus() async {
    final running = await BackgroundService.isRunning();
    if (mounted) setState(() => _running = running);
  }

  Future<void> _startPeriodic() async {
    setState(() => _busy = true);

    final prefs = await SharedPreferences.getInstance();
    final key = prefs.getString('gemini_api_key') ?? '';
    if (key.isEmpty) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Enter Gemini API key in Settings first')),
      );
      setState(() => _busy = false);
      return;
    }

    await BackgroundService.start();
    await _refreshStatus();
    if (mounted) setState(() => _busy = false);
  }

  Future<void> _stop() async {
    setState(() => _busy = true);
    await BackgroundService.stop();
    await _refreshStatus();
    if (mounted) setState(() => _busy = false);
  }

  Future<void> _runOnceNow() async {
    setState(() => _busy = true);

    final prefs = await SharedPreferences.getInstance();
    final key = prefs.getString('gemini_api_key') ?? '';
    if (key.isEmpty) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Enter Gemini API key in Settings first')),
      );
      setState(() => _busy = false);
      return;
    }

    await BackgroundService.triggerNow();

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Triggered one-time background run.')),
      );
    }

    if (mounted) setState(() => _busy = false);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Background Processor')),
      body: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          children: [
            Text(
              _running
                  ? 'Background service is RUNNING'
                  : 'Background service is STOPPED',
              style: TextStyle(
                fontSize: 18,
                color: _running ? Colors.green : Colors.red,
              ),
            ),
            const SizedBox(height: 24),
            ElevatedButton(
              onPressed: (_running || _busy) ? null : _startPeriodic,
              child: _busy && !_running
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Text('Start Periodic Service'),
            ),
            const SizedBox(height: 12),
            ElevatedButton(
              onPressed: _busy ? null : _runOnceNow,
              style: ElevatedButton.styleFrom(backgroundColor: Colors.blueGrey),
              child: _busy
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Text('Run Once Now'),
            ),
            const SizedBox(height: 12),
            ElevatedButton(
              onPressed: (!_running || _busy) ? null : _stop,
              style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
              child: _busy && _running
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Text('Stop Service'),
            ),
          ],
        ),
      ),
    );
  }
}
