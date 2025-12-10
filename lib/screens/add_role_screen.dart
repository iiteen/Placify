import 'package:flutter/material.dart';
import '../models/role.dart';
import '../services/database_service.dart';
import '../services/calendar_service.dart';

class AddRoleScreen extends StatefulWidget {
  const AddRoleScreen({super.key});

  @override
  State<AddRoleScreen> createState() => _AddRoleScreenState();
}

class _AddRoleScreenState extends State<AddRoleScreen> {
  final _formKey = GlobalKey<FormState>();
  final companyController = TextEditingController();
  final roleController = TextEditingController();

  DateTime? pptDate;
  DateTime? testDate;
  DateTime? interviewDate;

  final db = DatabaseService();
  final calendar = CalendarService();

  Future<void> _pickDateTime(
    Function(DateTime?) setter,
    DateTime? initial,
  ) async {
    DateTime now = initial ?? DateTime.now();

    final pickedDate = await showDatePicker(
      context: context,
      initialDate: now,
      firstDate: DateTime(now.year - 1),
      lastDate: DateTime(now.year + 3),
    );
    if (!mounted) return;
    if (pickedDate == null) return;

    final pickedTime = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.fromDateTime(now),
    );
    if (!mounted) return;
    if (pickedTime == null) return;

    final dt = DateTime(
      pickedDate.year,
      pickedDate.month,
      pickedDate.day,
      pickedTime.hour,
      pickedTime.minute,
    );

    if (!mounted) return;
    setState(() => setter(dt));
  }

  Widget _dateRow(
    String label,
    DateTime? dt,
    Function(DateTime?) setter,
    VoidCallback onClear,
  ) {
    String text = 'Not set';
    if (dt != null) {
      text =
          "${dt.toLocal().toString().split(' ')[0]} ${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}";
    }

    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Flexible(
          child: Text("$label: $text", style: const TextStyle(fontSize: 16)),
        ),
        Row(
          children: [
            ElevatedButton(
              onPressed: () => _pickDateTime(setter, dt),
              child: const Text('Set'),
            ),
            const SizedBox(width: 8),
            ElevatedButton(
              onPressed: onClear,
              style: ElevatedButton.styleFrom(backgroundColor: Colors.grey),
              child: const Text('Clear'),
            ),
          ],
        ),
      ],
    );
  }

  Future<void> _saveRole() async {
    if (!_formKey.currentState!.validate()) return;

    final role = Role(
      companyName: companyController.text.trim(),
      roleName: roleController.text.trim(),
      pptDate: pptDate,
      testDate: testDate,
      interviewDate: interviewDate,
      isInterested: false,
      isRejected: false,
    );

    // insert -> sets role.id
    await db.insertRole(role);

    // sync calendar (will create events and set eventIds on role)
    await calendar.syncRoleEvents(role);

    // persist event IDs back to DB
    await db.updateRole(role);

    if (!mounted) return;
    Navigator.pop(context, true);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Add New Role')),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Form(
          key: _formKey,
          child: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                TextFormField(
                  controller: companyController,
                  decoration: const InputDecoration(labelText: 'Company Name'),
                  validator: (v) => v == null || v.trim().isEmpty
                      ? 'Enter company name'
                      : null,
                ),
                const SizedBox(height: 16),
                TextFormField(
                  controller: roleController,
                  decoration: const InputDecoration(labelText: 'Role Name'),
                  validator: (v) =>
                      v == null || v.trim().isEmpty ? 'Enter role name' : null,
                ),
                const SizedBox(height: 24),
                _dateRow(
                  'PPT Date',
                  pptDate,
                  (d) => setState(() => pptDate = d),
                  () => setState(() => pptDate = null),
                ),
                const SizedBox(height: 12),
                _dateRow(
                  'Test Date',
                  testDate,
                  (d) => setState(() => testDate = d),
                  () => setState(() => testDate = null),
                ),
                const SizedBox(height: 12),
                _dateRow(
                  'Interview Date',
                  interviewDate,
                  (d) => setState(() => interviewDate = d),
                  () => setState(() => interviewDate = null),
                ),
                const SizedBox(height: 30),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: _saveRole,
                    child: const Text('Add Role'),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
