import 'package:flutter/material.dart';
import '../services/database_service.dart';
import '../models/role.dart';
import 'role_details_screen.dart';
import 'add_role_screen.dart';
import 'gmail_test_screen.dart'; // Import Gmail test screen

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final db = DatabaseService();
  List<Role> roles = [];

  @override
  void initState() {
    super.initState();
    _loadRoles();
  }

  Future<void> _loadRoles() async {
    try {
      final data = await db.getAllRoles();
      if (!mounted) return;
      setState(() {
        roles = data;
      });
    } catch (e, st) {
      debugPrint("❌ Error loading roles: $e\n$st");
      if (!mounted) return;
      setState(() {
        roles = [];
      });
    }
  }

  Color _statusColor(Role role) {
    if (role.isRejected) return Colors.red.shade200;
    if (role.isInterested) return Colors.green.shade200;
    return Colors.yellow.shade200; // new/not decided
  }

  String _deadlineText(Role role) {
    String formatDateTime(DateTime dt) {
      return "${dt.toLocal().toString().split(' ')[0]} "
          "${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}";
    }

    List<String> deadlines = [];

    if (role.pptDate != null) {
      deadlines.add("PPT: ${formatDateTime(role.pptDate!)}");
    }
    if (role.testDate != null) {
      deadlines.add("Test: ${formatDateTime(role.testDate!)}");
    }
    if (role.applicationDeadline != null) {
      deadlines.add(
        "Application Deadline: ${formatDateTime(role.applicationDeadline!)}",
      );
    }

    if (deadlines.isEmpty) return "No deadlines yet";

    return deadlines.join(" | ");
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Placement Tracker"),
        actions: [
          IconButton(
            icon: const Icon(Icons.email),
            tooltip: 'Gmail Test',
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const GmailTestScreen()),
              ).then((_) => _loadRoles());
            },
          ),
        ],
      ),
      body: roles.isEmpty
          ? const Center(child: Text("No roles added yet"))
          : ListView.builder(
              itemCount: roles.length,
              itemBuilder: (context, index) {
                final role = roles[index];
                return Card(
                  color: _statusColor(role),
                  margin: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 6,
                  ),
                  child: ListTile(
                    title: Text(
                      "${role.companyName} — ${role.roleName}",
                      style: const TextStyle(fontWeight: FontWeight.bold),
                    ),
                    subtitle: Text(_deadlineText(role)),
                    onTap: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => RoleDetailsScreen(role: role),
                        ),
                      ).then((_) => _loadRoles());
                    },
                  ),
                );
              },
            ),
      floatingActionButton: FloatingActionButton(
        child: const Icon(Icons.add),
        onPressed: () async {
          try {
            final added = await Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const AddRoleScreen()),
            );
            if (added == true) {
              _loadRoles(); // refresh after new role added
            }
          } catch (e, st) {
            debugPrint("❌ Error opening AddRoleScreen: $e\n$st");
          }
        },
      ),
    );
  }
}
