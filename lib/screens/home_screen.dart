import 'package:flutter/material.dart';
import '../services/database_service.dart';
import '../models/role.dart';
import 'role_details_screen.dart';
import 'add_role_screen.dart';
import 'gmail_test_screen.dart';
import 'background_controller_screen.dart';
import 'settings_screen.dart';
import '../services/permission_service.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen>
    with SingleTickerProviderStateMixin {
  final db = DatabaseService();
  late final TabController _tabController;

  List<Role> activeRoles = [];
  List<Role> rejectedRoles = [];

  // Refresh flags
  bool refreshActive = true;
  bool refreshRejected = true;

  @override
  void initState() {
    super.initState();

    _tabController = TabController(length: 2, vsync: this);

    // App just opened -> force both tabs to refresh once
    refreshActive = true;
    refreshRejected = true;

    // Active tab is visible initially → reload now
    _loadActiveRoles().then((_) {
      refreshActive = false; // we used up the refresh
    });

    _tabController.addListener(() {
      if (_tabController.indexIsChanging) {
        return;
      }

      if (_tabController.index == 0) {
        if (refreshActive) {
          _loadActiveRoles();
          refreshActive = false;
        }
      } else if (_tabController.index == 1) {
        if (refreshRejected) {
          _loadRejectedRoles();
          refreshRejected = false;
        }
      }
    });

    _initPermissions();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  // ---------------------------
  // LOADERS
  // ---------------------------

  Future<void> _initPermissions() async {
    await PermissionService.ensurePermissions();
  }

  Future<void> _loadActiveRoles() async {
    try {
      final all = await db.getAllRoles();

      if (!mounted) {
        return;
      }

      setState(() {
        activeRoles = all.where((r) => !r.isRejected).toList();
      });
    } catch (e, st) {
      debugPrint("❌ Error loading active roles: $e\n$st");
    }
  }

  Future<void> _loadRejectedRoles() async {
    try {
      final all = await db.getAllRoles();

      if (!mounted) {
        return;
      }

      setState(() {
        rejectedRoles = all.where((r) => r.isRejected).toList();
      });
    } catch (e, st) {
      debugPrint("❌ Error loading rejected roles: $e\n$st");
    }
  }

  // ---------------------------
  // UI HELPERS
  // ---------------------------

  Color _statusColor(Role role) {
    if (role.isRejected) {
      return Colors.red.shade100;
    }

    if (role.isInterested) {
      return Colors.green.shade100;
    }

    return Colors.yellow.shade100;
  }

  String _deadlineText(Role role) {
    String formatDateTime(DateTime dt) {
      return "${dt.toLocal().toString().split(' ')[0]} "
          "${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}";
    }

    List<String> out = [];

    if (role.pptDate != null) {
      out.add("PPT: ${formatDateTime(role.pptDate!)}");
    }

    if (role.testDate != null) {
      out.add("Test: ${formatDateTime(role.testDate!)}");
    }

    if (role.applicationDeadline != null) {
      out.add("Deadline: ${formatDateTime(role.applicationDeadline!)}");
    }

    if (out.isEmpty) {
      return "No deadlines yet";
    }

    return out.join(" • ");
  }

  Widget _buildRoleList(List<Role> roles) {
    if (roles.isEmpty) {
      return const Center(
        child: Text("No roles in this section", style: TextStyle(fontSize: 16)),
      );
    }

    return ListView.builder(
      itemCount: roles.length,
      itemBuilder: (context, index) {
        final role = roles[index];
        return Card(
          margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
          color: _statusColor(role),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          elevation: 2,
          child: ListTile(
            title: Text(
              "${role.companyName} — ${role.roleName}",
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
            subtitle: Text(_deadlineText(role)),
            trailing: const Icon(Icons.arrow_forward_ios, size: 16),
            onTap: () {
              Navigator.push<bool>(
                    context,
                    MaterialPageRoute(
                      builder: (_) => RoleDetailsScreen(role: role),
                    ),
                  )
                  .then((changed) async {
                    try {
                      if (changed == true) {
                        // mark both tabs for refresh
                        refreshActive = true;
                        refreshRejected = true;

                        // Immediately reload the visible tab so user sees updates
                        if (_tabController.index == 0) {
                          await _loadActiveRoles();
                          refreshActive = false;
                        } else if (_tabController.index == 1) {
                          await _loadRejectedRoles();
                          refreshRejected = false;
                        }
                      }
                    } catch (e, st) {
                      debugPrint(
                        "❌ Error handling return from RoleDetails: $e\n$st",
                      );
                    }
                  })
                  .catchError((err, st) {
                    debugPrint(
                      "❌ Navigation error to RoleDetailsScreen: $err\n$st",
                    );
                  });
            },
          ),
        );
      },
    );
  }

  // ---------------------------
  // MAIN BUILD
  // ---------------------------

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Placement Tracker"),
        actions: [
          IconButton(
            icon: const Icon(Icons.email),
            tooltip: "Gmail Test",
            onPressed: () {
              Navigator.push<bool>(
                    context,
                    MaterialPageRoute(builder: (_) => const GmailTestScreen()),
                  )
                  .then((changed) async {
                    try {
                      if (changed == true) {
                        refreshActive = true;
                        refreshRejected = true;

                        // reload current visible tab immediately
                        if (_tabController.index == 0) {
                          await _loadActiveRoles();
                          refreshActive = false;
                        } else if (_tabController.index == 1) {
                          await _loadRejectedRoles();
                          refreshRejected = false;
                        }
                      }
                    } catch (e, st) {
                      debugPrint(
                        "❌ Error handling return from GmailTestScreen: $e\n$st",
                      );
                    }
                  })
                  .catchError((err, st) {
                    debugPrint("❌ Gmail navigation error: $err\n$st");
                  });
            },
          ),
          // --------------------------
          // NEW: Background Controller
          // --------------------------
          IconButton(
            icon: const Icon(Icons.sync),
            tooltip: "Background Processor",
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => const BackgroundControllerScreen(),
                ),
              );
            },
          ),

          // --------------------------
          // NEW: Settings Screen
          // --------------------------
          IconButton(
            icon: const Icon(Icons.settings),
            tooltip: "Settings",
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const SettingsScreen()),
              );
            },
          ),
        ],
        bottom: TabBar(
          controller: _tabController,
          tabs: const [
            Tab(text: "Active Roles"),
            Tab(text: "Rejected Roles"),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [_buildRoleList(activeRoles), _buildRoleList(rejectedRoles)],
      ),
      floatingActionButton: FloatingActionButton(
        child: const Icon(Icons.add),
        onPressed: () async {
          try {
            final added = await Navigator.push<bool>(
              context,
              MaterialPageRoute(builder: (_) => const AddRoleScreen()),
            );

            if (added == true) {
              refreshActive = true;
              refreshRejected = true;

              // reload the visible tab immediately
              if (_tabController.index == 0) {
                await _loadActiveRoles();
                refreshActive = false;
              } else if (_tabController.index == 1) {
                await _loadRejectedRoles();
                refreshRejected = false;
              }
            }
          } catch (e, st) {
            debugPrint("❌ Error opening AddRoleScreen: $e\n$st");
          }
        },
      ),
    );
  }
}
