import 'package:flutter/material.dart';

class ProjectFormPage extends StatefulWidget {
  final String? initialName;
  final String? initialDescription;
  final String? initialCustomer;

  const ProjectFormPage({
    Key? key,
    this.initialName,
    this.initialDescription,
    this.initialCustomer,
  }) : super(key: key);

  @override
  _ProjectFormPageState createState() => _ProjectFormPageState();
}

class _ProjectFormPageState extends State<ProjectFormPage> {
  late TextEditingController _nameController;
  late TextEditingController _descriptionController;
  late TextEditingController _customerController;

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController(text: widget.initialName ?? '');
    _descriptionController =
        TextEditingController(text: widget.initialDescription ?? '');
    _customerController =
        TextEditingController(text: widget.initialCustomer ?? '');
  }

  @override
  void dispose() {
    _nameController.dispose();
    _descriptionController.dispose();
    _customerController.dispose();
    super.dispose();
  }

  void _onSave() {
    final name = _nameController.text.trim();
    final description = _descriptionController.text.trim();
    final customer = _customerController.text.trim();

    if (name.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Der Projektname darf nicht leer sein.')),
      );
      return;
    }

    Navigator.of(context).pop({
      'name': name,
      'description': description,
      'customer': customer,
    });
  }

  @override
  Widget build(BuildContext context) {
    final isEditMode = widget.initialName != null;

    return Scaffold(
      appBar: AppBar(
        title: Text(isEditMode ? 'Projekt bearbeiten' : 'Neues Projekt'),
        elevation: 0,
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 24),
          child: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // Name
                TextField(
                  controller: _nameController,
                  decoration: const InputDecoration(
                    labelText: 'Name',
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 16),
                // Beschreibung
                TextField(
                  controller: _descriptionController,
                  decoration: const InputDecoration(
                    labelText: 'Beschreibung',
                    border: OutlineInputBorder(),
                  ),
                  maxLines: 3,
                ),
                const SizedBox(height: 16),
                // Kunde
                TextField(
                  controller: _customerController,
                  decoration: const InputDecoration(
                    labelText: 'Kunde',
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 32),
                // Speichern-Button
                ElevatedButton(
                  onPressed: _onSave,
                  child: const Text('Speichern'),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
