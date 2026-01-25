import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../models/building.dart';
import '../../providers/projects_provider.dart';

class EditTab extends ConsumerStatefulWidget {
  final Building building;
  final int index;

  const EditTab({
    Key? key,
    required this.building,
    required this.index,
  }) : super(key: key);

  @override
  ConsumerState<EditTab> createState() => _EditTabState();
}

class _EditTabState extends ConsumerState<EditTab> {
  late final TextEditingController _nameController;
  late final TextEditingController _addressController;
  late final TextEditingController _postalController;
  late final TextEditingController _cityController;
  late final TextEditingController _typeController;
  late final TextEditingController _bgfController;

  late final TextEditingController _constructionYearController;
  late final TextEditingController _renovationsController;
  bool _protectedMonument = false;
  late final TextEditingController _unitsController;

  @override
  void initState() {
    super.initState();

    // Initiale Befüllung der Controller
    _nameController = TextEditingController(text: widget.building.name);
    _addressController = TextEditingController(text: widget.building.address);
    _postalController = TextEditingController(text: widget.building.postalCode);
    _cityController = TextEditingController(text: widget.building.city);
    _typeController = TextEditingController(text: widget.building.type);
    _bgfController = TextEditingController(
      text: widget.building.bgf != 0.0 ? widget.building.bgf.toString() : '',
    );

    _constructionYearController = TextEditingController(
      text: widget.building.constructionYear != 0
          ? widget.building.constructionYear.toString()
          : '',
    );
    _renovationsController = TextEditingController(
      text: widget.building.renovationYears.isNotEmpty
          ? widget.building.renovationYears.join(', ')
          : '',
    );
    _protectedMonument = widget.building.protectedMonument;
    _unitsController = TextEditingController(
      text: widget.building.units != 0 ? widget.building.units.toString() : '',
    );
  }

  @override
  void didUpdateWidget(EditTab oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.building.id != widget.building.id) {
      _nameController.text = widget.building.name;
      _addressController.text = widget.building.address;
      _postalController.text = widget.building.postalCode;
      _cityController.text = widget.building.city;
      _typeController.text = widget.building.type;
      _bgfController.text =
      widget.building.bgf != 0.0 ? widget.building.bgf.toString() : '';

      _constructionYearController.text =
      widget.building.constructionYear != 0
          ? widget.building.constructionYear.toString()
          : '';
      _renovationsController.text = widget.building.renovationYears.isNotEmpty
          ? widget.building.renovationYears.join(', ')
          : '';
      _protectedMonument = widget.building.protectedMonument;
      _unitsController.text =
      widget.building.units != 0 ? widget.building.units.toString() : '';
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    _addressController.dispose();
    _postalController.dispose();
    _cityController.dispose();
    _typeController.dispose();
    _bgfController.dispose();
    _constructionYearController.dispose();
    _renovationsController.dispose();
    _unitsController.dispose();
    super.dispose();
  }

  InputDecoration _buildDecoration({
    required String label,
    required IconData icon,
    required String example,
  }) =>
      InputDecoration(
        labelText: label,
        hintText: example,
        prefixIcon: Icon(icon, color: Colors.blueGrey),
        filled: true,
        fillColor: Colors.grey.shade50,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide.none,
        ),
      );

  Future<void> _updateBuilding() async {
    await ref.read(projectsProvider.notifier).updateBuilding(widget.building);
  }

  @override
  Widget build(BuildContext context) {
    const spacing = SizedBox(height: 16);

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
      child: SingleChildScrollView(
        child: Column(
          children: [
            // Name
            TextField(
              controller: _nameController,
              decoration: _buildDecoration(
                label: 'Gebäudename',
                icon: Icons.home_work,
                example: 'z. B. Verwaltungsgebäude A',
              ),
              textInputAction: TextInputAction.next,
              onChanged: (val) {
                widget.building.name = val.trim();
                _updateBuilding();
              },
            ),
            spacing,

            // Adresse
            TextField(
              controller: _addressController,
              decoration: _buildDecoration(
                label: 'Straße & Hausnummer',
                icon: Icons.location_on,
                example: 'z. B. Hauptstraße 123',
              ),
              textInputAction: TextInputAction.next,
              onChanged: (val) {
                widget.building.address = val.trim();
                _updateBuilding();
              },
            ),
            spacing,

            // PLZ
            TextField(
              controller: _postalController,
              decoration: _buildDecoration(
                label: 'Postleitzahl',
                icon: Icons.mail,
                example: 'z. B. 10115',
              ),
              keyboardType: TextInputType.number,
              textInputAction: TextInputAction.next,
              onChanged: (val) {
                widget.building.postalCode = val.trim();
                _updateBuilding();
              },
            ),
            spacing,

            // Stadt
            TextField(
              controller: _cityController,
              decoration: _buildDecoration(
                label: 'Stadt',
                icon: Icons.location_city,
                example: 'z. B. Berlin',
              ),
              textInputAction: TextInputAction.next,
              onChanged: (val) {
                widget.building.city = val.trim();
                _updateBuilding();
              },
            ),
            spacing,

            // Typ
            TextField(
              controller: _typeController,
              decoration: _buildDecoration(
                label: 'Gebäude-Typ',
                icon: Icons.apartment,
                example: 'z. B. Gewerbegebäude',
              ),
              textInputAction: TextInputAction.next,
              onChanged: (val) {
                widget.building.type = val.trim();
                _updateBuilding();
              },
            ),
            spacing,

            // BGF (m²)
            TextField(
              controller: _bgfController,
              decoration: _buildDecoration(
                label: 'Brutto-Grundfläche (m²)',
                icon: Icons.square_foot,
                example: 'z. B. 1250,50',
              ),
              keyboardType: TextInputType.numberWithOptions(decimal: true),
              textInputAction: TextInputAction.next,
              onChanged: (val) {
                final parsed = double.tryParse(val.replaceAll(',', '.'));
                if (parsed != null) {
                  widget.building.bgf = parsed;
                  _updateBuilding();
                }
              },
            ),
            spacing,

            // Baujahr
            TextField(
              controller: _constructionYearController,
              decoration: _buildDecoration(
                label: 'Baujahr',
                icon: Icons.calendar_today,
                example: 'z. B. 1995',
              ),
              keyboardType: TextInputType.number,
              textInputAction: TextInputAction.next,
              onChanged: (val) {
                final parsed = int.tryParse(val.trim());
                if (parsed != null) {
                  widget.building.constructionYear = parsed;
                  _updateBuilding();
                }
              },
            ),
            spacing,

            // Sanierungen (komma-getrennt)
            TextField(
              controller: _renovationsController,
              decoration: _buildDecoration(
                label: 'Sanierungen (Jahre, komma-getrennt)',
                icon: Icons.build,
                example: 'z. B. 2005, 2018',
              ),
              textInputAction: TextInputAction.next,
              onChanged: (val) {
                final parts = val.split(',');
                final years = parts
                    .map((s) => int.tryParse(s.trim()))
                    .whereType<int>()
                    .toList();
                widget.building.renovationYears = years;
                _updateBuilding();
              },
            ),
            spacing,

            // Denkmalschutz
            Row(
              children: [
                Checkbox(
                  value: _protectedMonument,
                  onChanged: (val) {
                    setState(() {
                      _protectedMonument = val ?? false;
                      widget.building.protectedMonument = _protectedMonument;
                    });
                    _updateBuilding();
                  },
                ),
                const SizedBox(width: 8),
                const Text('Denkmalschutz'),
              ],
            ),
            spacing,

            // Einheiten
            TextField(
              controller: _unitsController,
              decoration: _buildDecoration(
                label: 'Einheiten (Anzahl)',
                icon: Icons.home,
                example: 'z. B. 10',
              ),
              keyboardType: TextInputType.number,
              textInputAction: TextInputAction.next,
              onChanged: (val) {
                final parsed = int.tryParse(val.trim());
                if (parsed != null) {
                  widget.building.units = parsed;
                  _updateBuilding();
                }
              },
            ),

            // Kein Speichern-Button mehr: Änderungen passieren automatisch
            const SizedBox(height: 40),
          ],
        ),
      ),
    );
  }
}
