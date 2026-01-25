import 'package:flutter/material.dart';
import 'package:uuid/uuid.dart';

/// Widget für direkte Anzeige im Tab (ohne Dialog)
class SchemaEditorWidget extends StatefulWidget {
  final List<Map<String, dynamic>> existingSchema;
  final ValueChanged<List<Map<String, dynamic>>> onSchemaChanged;
  final bool allowEditGlobal;
  
  const SchemaEditorWidget({
    Key? key,
    required this.existingSchema,
    required this.onSchemaChanged,
    this.allowEditGlobal = false,
  }) : super(key: key);

  @override
  _SchemaEditorWidgetState createState() => _SchemaEditorWidgetState();
}

class _SchemaEditorWidgetState extends State<SchemaEditorWidget> {
  late List<Map<String, dynamic>> schemaList;
  final _uuid = Uuid();

  @override
  void initState() {
    super.initState();
    schemaList = List.from(widget.existingSchema);
  }

  @override
  void didUpdateWidget(SchemaEditorWidget oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.existingSchema != widget.existingSchema) {
      schemaList = List.from(widget.existingSchema);
    }
  }

  void _notifyChange() {
    widget.onSchemaChanged(schemaList);
  }

  Future<void> _onAddField() async {
    final newField = await showModalBottomSheet<Map<String, dynamic>>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => AddSchemaFieldDialog(uuid: _uuid),
    );
    if (newField != null) {
      setState(() {
        schemaList.add(newField);
        _notifyChange();
      });
    }
  }

  Future<void> _onEditField(int index) async {
    final existingField = schemaList[index];
    final editedField = await showModalBottomSheet<Map<String, dynamic>>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => AddSchemaFieldDialog(
        uuid: _uuid,
        existingField: existingField,
      ),
    );
    if (editedField != null) {
      setState(() {
        schemaList[index] = editedField;
        _notifyChange();
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        // Header
        Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                Colors.blue.withOpacity(0.12),
                Colors.blue.withOpacity(0.06),
              ],
            ),
            border: Border(
              bottom: BorderSide(
                color: Colors.grey.withOpacity(0.15),
                width: 1,
              ),
            ),
          ),
          padding: const EdgeInsets.all(24),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [
                      Colors.blue[400]!,
                      Colors.blue[600]!,
                    ],
                  ),
                  borderRadius: BorderRadius.circular(14),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.blue.withOpacity(0.3),
                      blurRadius: 8,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
                child: const Icon(
                  Icons.schema,
                  color: Colors.white,
                  size: 26,
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      'Eingabefelder',
                      style: TextStyle(
                        fontSize: 22,
                        fontWeight: FontWeight.w700,
                        color: Colors.grey[900],
                        letterSpacing: -0.3,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Wrap(
                      spacing: 8,
                      runSpacing: 4,
                      crossAxisAlignment: WrapCrossAlignment.center,
                      children: [
                        Text(
                          '${schemaList.length} Feld${schemaList.length != 1 ? 'er' : ''} definiert',
                          style: TextStyle(
                            fontSize: 13,
                            color: Colors.grey[600],
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                        if (schemaList.length > 1)
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                            decoration: BoxDecoration(
                              color: Colors.blue.withOpacity(0.1),
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(
                                  Icons.drag_handle,
                                  size: 12,
                                  color: Colors.blue[700],
                                ),
                                const SizedBox(width: 3),
                                Text(
                                  'Verschieben',
                                  style: TextStyle(
                                    fontSize: 10,
                                    color: Colors.blue[700],
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ],
                            ),
                          ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        // Content
        Expanded(
          child: schemaList.isEmpty
              ? Center(
                  child: Padding(
                    padding: const EdgeInsets.all(32),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Container(
                          padding: const EdgeInsets.all(20),
                          decoration: BoxDecoration(
                            color: Colors.blue.withOpacity(0.1),
                            shape: BoxShape.circle,
                          ),
                          child: Icon(
                            Icons.schema_outlined,
                            size: 64,
                            color: Colors.blue[400],
                          ),
                        ),
                        const SizedBox(height: 24),
                        Text(
                          'Noch keine Felder',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.w600,
                            color: Colors.grey[800],
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          'Fügen Sie Felder hinzu, um das Schema zu definieren',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            fontSize: 14,
                            color: Colors.grey[600],
                          ),
                        ),
                      ],
                    ),
                  ),
                )
              : ReorderableListView(
                  padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
                  onReorder: (oldIndex, newIndex) {
                    setState(() {
                      if (newIndex > oldIndex) {
                        newIndex -= 1;
                      }
                      final item = schemaList.removeAt(oldIndex);
                      schemaList.insert(newIndex, item);
                      _notifyChange();
                    });
                  },
                  children: [
                    ...schemaList.asMap().entries.map((e) {
                      final index = e.key;
                      final field = e.value;
                      return Container(
                        key: ValueKey('${field['key']}_$index'),
                        margin: const EdgeInsets.only(bottom: 12),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(
                            color: Colors.grey.withOpacity(0.2),
                            width: 1.5,
                          ),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withOpacity(0.03),
                              blurRadius: 8,
                              offset: const Offset(0, 2),
                            ),
                          ],
                        ),
                        child: Material(
                          color: Colors.transparent,
                          child: InkWell(
                            borderRadius: BorderRadius.circular(16),
                            onTap: () => _onEditField(index),
                            child: Padding(
                              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
                              child: Row(
                                children: [
                                  Container(
                                    padding: const EdgeInsets.all(8),
                                    decoration: BoxDecoration(
                                      color: Colors.grey[100],
                                      borderRadius: BorderRadius.circular(8),
                                    ),
                                    child: Icon(
                                      Icons.drag_handle,
                                      color: Colors.grey[600],
                                      size: 20,
                                    ),
                                  ),
                                  const SizedBox(width: 12),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        Row(
                                          children: [
                                            Expanded(
                                              child: Text(
                                                field['label'],
                                                style: const TextStyle(
                                                  fontWeight: FontWeight.w600,
                                                  fontSize: 16,
                                                  letterSpacing: -0.2,
                                                  color: Colors.black87,
                                                ),
                                                maxLines: 2,
                                                overflow: TextOverflow.ellipsis,
                                              ),
                                            ),
                                            if (field['isGlobal'] == true)
                                              Container(
                                                margin: const EdgeInsets.only(left: 8),
                                                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                                decoration: BoxDecoration(
                                                  color: Colors.blue.withOpacity(0.1),
                                                  borderRadius: BorderRadius.circular(4),
                                                  border: Border.all(color: Colors.blue.withOpacity(0.2)),
                                                ),
                                                child: const Text(
                                                  'GLOBAL',
                                                  style: TextStyle(
                                                    fontSize: 9,
                                                    fontWeight: FontWeight.bold,
                                                    color: Colors.blue,
                                                  ),
                                                ),
                                              ),
                                          ],
                                        ),
                                        const SizedBox(height: 8),
                                        Row(
                                          children: [
                                            Container(
                                              padding: const EdgeInsets.symmetric(
                                                horizontal: 6,
                                                vertical: 4,
                                              ),
                                              decoration: BoxDecoration(
                                                color: field['type'] == 'int'
                                                    ? Colors.orange.withOpacity(0.15)
                                                    : Colors.green.withOpacity(0.15),
                                                borderRadius: BorderRadius.circular(8),
                                                border: Border.all(
                                                  color: field['type'] == 'int'
                                                      ? Colors.orange.withOpacity(0.3)
                                                      : Colors.green.withOpacity(0.3),
                                                ),
                                              ),
                                              child: Text(
                                                field['type'] == 'int' ? 'Zahl' : 'Text',
                                                style: TextStyle(
                                                  fontSize: 10,
                                                  color: field['type'] == 'int'
                                                      ? Colors.orange[800]
                                                      : Colors.green[800],
                                                  fontWeight: FontWeight.w600,
                                                ),
                                              ),
                                            ),
                                            const SizedBox(width: 6),
                                            Container(
                                              padding: const EdgeInsets.symmetric(
                                                horizontal: 6,
                                                vertical: 4,
                                              ),
                                              decoration: BoxDecoration(
                                                color: (field['editable'] ?? true)
                                                    ? Colors.blue.withOpacity(0.15)
                                                    : Colors.grey.withOpacity(0.15),
                                                borderRadius: BorderRadius.circular(8),
                                                border: Border.all(
                                                  color: (field['editable'] ?? true)
                                                      ? Colors.blue.withOpacity(0.3)
                                                      : Colors.grey.withOpacity(0.3),
                                                ),
                                              ),
                                              child: Text(
                                                (field['editable'] ?? true) ? 'Editierbar' : 'Gesperrt',
                                                style: TextStyle(
                                                  fontSize: 10,
                                                  color: (field['editable'] ?? true)
                                                      ? Colors.blue[800]
                                                      : Colors.grey[800],
                                                  fontWeight: FontWeight.w600,
                                                ),
                                              ),
                                            ),
                                          ],
                                        ),
                                      ],
                                    ),
                                  ),
                                  if (widget.allowEditGlobal || field['isGlobal'] != true)
                                    IconButton(
                                      icon: const Icon(Icons.edit_outlined),
                                      onPressed: () => _onEditField(index),
                                    ),
                                  if (widget.allowEditGlobal || field['isGlobal'] != true)
                                    IconButton(
                                      icon: const Icon(Icons.delete_outline, color: Colors.red),
                                      onPressed: () {
                                        setState(() {
                                          schemaList.removeAt(index);
                                          _notifyChange();
                                        });
                                      },
                                    ),
                                  if (!widget.allowEditGlobal && field['isGlobal'] == true)
                                    const Padding(
                                      padding: EdgeInsets.symmetric(horizontal: 12),
                                      child: Icon(Icons.lock_outline, color: Colors.grey, size: 20),
                                    ),
                                ],
                              ),
                            ),
                          ),
                        ),
                      );
                    }),
                  ],
                ),
        ),
        // Footer
        Container(
          padding: const EdgeInsets.fromLTRB(24, 20, 24, 24),
          decoration: BoxDecoration(
            color: Colors.white,
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.05),
                blurRadius: 10,
                offset: const Offset(0, -5),
              ),
            ],
            border: Border(top: BorderSide(color: Colors.grey.withOpacity(0.1))),
          ),
          child: SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              icon: const Icon(Icons.add_rounded),
              label: const Text(
                'Neues Feld hinzufügen',
                style: TextStyle(fontWeight: FontWeight.w600, fontSize: 16),
              ),
              onPressed: _onAddField,
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.blue[600],
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 16),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                elevation: 0,
              ),
            ),
          ),
        ),
      ],
    );
  }
}

/// Haupt-Dialog: Schema bearbeiten
class SchemaEditorDialog extends StatefulWidget {
  final List<Map<String, dynamic>> existingSchema;
  const SchemaEditorDialog({Key? key, required this.existingSchema}) : super(key: key);

  @override
  _SchemaEditorDialogState createState() => _SchemaEditorDialogState();
}

class _SchemaEditorDialogState extends State<SchemaEditorDialog> {
  late List<Map<String, dynamic>> schemaList;
  final _uuid = Uuid();

  @override
  void initState() {
    super.initState();
    schemaList = List.from(widget.existingSchema);
  }

  Future<void> _onAddField() async {
    final newField = await showModalBottomSheet<Map<String, dynamic>>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => AddSchemaFieldDialog(uuid: _uuid),
    );
    if (newField != null) {
      setState(() => schemaList.add(newField));
    }
  }

  Future<void> _onEditField(int index) async {
    final existingField = schemaList[index];
    final editedField = await showModalBottomSheet<Map<String, dynamic>>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => AddSchemaFieldDialog(
        uuid: _uuid,
        existingField: existingField,
      ),
    );
    if (editedField != null) {
      setState(() => schemaList[index] = editedField);
    }
  }

  @override
  Widget build(BuildContext context) {
    final maxHeight = MediaQuery.of(context).size.height * 0.9;
    
    return ClipRRect(
      borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
      child: ConstrainedBox(
        constraints: BoxConstraints(maxHeight: maxHeight),
        child: Container(
          color: Colors.white,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Header
              Container(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [
                      Colors.blue.withOpacity(0.12),
                      Colors.blue.withOpacity(0.06),
                    ],
                  ),
                  border: Border(
                    bottom: BorderSide(
                      color: Colors.grey.withOpacity(0.15),
                      width: 1,
                    ),
                  ),
                ),
                padding: const EdgeInsets.all(24),
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          colors: [
                            Colors.blue[400]!,
                            Colors.blue[600]!,
                          ],
                        ),
                        borderRadius: BorderRadius.circular(14),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.blue.withOpacity(0.3),
                            blurRadius: 8,
                            offset: const Offset(0, 2),
                          ),
                        ],
                      ),
                      child: const Icon(
                        Icons.schema,
                        color: Colors.white,
                        size: 26,
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            'Schema bearbeiten',
                            style: TextStyle(
                              fontSize: 22,
                              fontWeight: FontWeight.w700,
                              color: Colors.grey[900],
                              letterSpacing: -0.3,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Wrap(
                            spacing: 8,
                            runSpacing: 4,
                            crossAxisAlignment: WrapCrossAlignment.center,
                            children: [
                              Text(
                                '${schemaList.length} Feld${schemaList.length != 1 ? 'er' : ''} definiert',
                                style: TextStyle(
                                  fontSize: 13,
                                  color: Colors.grey[600],
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                              if (schemaList.length > 1)
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                  decoration: BoxDecoration(
                                    color: Colors.blue.withOpacity(0.1),
                                    borderRadius: BorderRadius.circular(6),
                                  ),
                                  child: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Icon(
                                        Icons.drag_handle,
                                        size: 12,
                                        color: Colors.blue[700],
                                      ),
                                      const SizedBox(width: 3),
                                      Text(
                                        'Verschieben',
                                        style: TextStyle(
                                          fontSize: 10,
                                          color: Colors.blue[700],
                                          fontWeight: FontWeight.w600,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              // Content
              Flexible(
                child: schemaList.isEmpty
                    ? Center(
                        child: Padding(
                          padding: const EdgeInsets.all(32),
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Container(
                                padding: const EdgeInsets.all(20),
                                decoration: BoxDecoration(
                                  color: Colors.blue.withOpacity(0.1),
                                  shape: BoxShape.circle,
                                ),
                                child: Icon(
                                  Icons.schema_outlined,
                                  size: 64,
                                  color: Colors.blue[400],
                                ),
                              ),
                              const SizedBox(height: 24),
                              Text(
                                'Noch keine Felder',
                                style: TextStyle(
                                  fontSize: 18,
                                  fontWeight: FontWeight.w600,
                                  color: Colors.grey[800],
                                ),
                              ),
                              const SizedBox(height: 8),
                              Text(
                                'Fügen Sie Felder hinzu, um das Schema zu definieren',
                                textAlign: TextAlign.center,
                                style: TextStyle(
                                  fontSize: 14,
                                  color: Colors.grey[600],
                                ),
                              ),
                            ],
                          ),
                        ),
                      )
                    : ReorderableListView(
                        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
                        onReorder: (oldIndex, newIndex) {
                          setState(() {
                            if (newIndex > oldIndex) {
                              newIndex -= 1;
                            }
                            final item = schemaList.removeAt(oldIndex);
                            schemaList.insert(newIndex, item);
                          });
                        },
                        children: [
                          ...schemaList.asMap().entries.map((e) {
                            final index = e.key;
                            final field = e.value;
                            return Container(
                              key: ValueKey('${field['key']}_$index'),
                              margin: const EdgeInsets.only(bottom: 12),
                              decoration: BoxDecoration(
                                color: Colors.white,
                                borderRadius: BorderRadius.circular(16),
                                border: Border.all(
                                  color: Colors.grey.withOpacity(0.2),
                                  width: 1.5,
                                ),
                                boxShadow: [
                                  BoxShadow(
                                    color: Colors.black.withOpacity(0.03),
                                    blurRadius: 8,
                                    offset: const Offset(0, 2),
                                  ),
                                ],
                              ),
                              child: Material(
                                color: Colors.transparent,
                                child: InkWell(
                                  borderRadius: BorderRadius.circular(16),
                                  onTap: () => _onEditField(index),
                                  child: Padding(
                                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
                                    child: Row(
                                      children: [
                                        Container(
                                          padding: const EdgeInsets.all(8),
                                          decoration: BoxDecoration(
                                            color: Colors.grey[100],
                                            borderRadius: BorderRadius.circular(8),
                                          ),
                                          child: Icon(
                                            Icons.drag_handle,
                                            color: Colors.grey[600],
                                            size: 20,
                                          ),
                                        ),
                                        const SizedBox(width: 12),
                                        Expanded(
                                          child: Column(
                                            crossAxisAlignment: CrossAxisAlignment.start,
                                            mainAxisSize: MainAxisSize.min,
                                            children: [
                                              Row(
                                                crossAxisAlignment: CrossAxisAlignment.start,
                                                children: [
                                                  Expanded(
                                                    child: Text(
                                                      field['label'],
                                                      style: const TextStyle(
                                                        fontWeight: FontWeight.w600,
                                                        fontSize: 16,
                                                        letterSpacing: -0.2,
                                                        color: Colors.black87,
                                                      ),
                                                      maxLines: 2,
                                                      overflow: TextOverflow.ellipsis,
                                                    ),
                                                  ),
                                                  const SizedBox(width: 8),
                                                  Container(
                                                    padding: const EdgeInsets.symmetric(
                                                      horizontal: 6,
                                                      vertical: 4,
                                                    ),
                                                    decoration: BoxDecoration(
                                                      color: field['type'] == 'int'
                                                          ? Colors.orange.withOpacity(0.15)
                                                          : Colors.green.withOpacity(0.15),
                                                      borderRadius: BorderRadius.circular(8),
                                                      border: Border.all(
                                                        color: field['type'] == 'int'
                                                            ? Colors.orange.withOpacity(0.3)
                                                            : Colors.green.withOpacity(0.3),
                                                      ),
                                                    ),
                                                    child: Text(
                                                      field['type'] == 'int' ? 'Zahl' : 'Text',
                                                      style: TextStyle(
                                                        fontSize: 10,
                                                        color: field['type'] == 'int'
                                                            ? Colors.orange[800]
                                                            : Colors.green[800],
                                                        fontWeight: FontWeight.w600,
                                                      ),
                                                    ),
                                                  ),
                                                  const SizedBox(width: 6),
                                                  Container(
                                                    padding: const EdgeInsets.symmetric(
                                                      horizontal: 6,
                                                      vertical: 4,
                                                    ),
                                                    decoration: BoxDecoration(
                                                      color: (field['editable'] ?? true)
                                                          ? Colors.blue.withOpacity(0.15)
                                                          : Colors.grey.withOpacity(0.15),
                                                      borderRadius: BorderRadius.circular(8),
                                                      border: Border.all(
                                                        color: (field['editable'] ?? true)
                                                            ? Colors.blue.withOpacity(0.3)
                                                            : Colors.grey.withOpacity(0.3),
                                                      ),
                                                    ),
                                                    child: Text(
                                                      (field['editable'] ?? true) ? 'Editierbar' : 'Gesperrt',
                                                      style: TextStyle(
                                                        fontSize: 10,
                                                        color: (field['editable'] ?? true)
                                                            ? Colors.blue[800]
                                                            : Colors.grey[800],
                                                        fontWeight: FontWeight.w600,
                                                      ),
                                                    ),
                                                  ),
                                                ],
                                              ),
                                            ],
                                          ),
                                        ),
                                        IconButton(
                                          icon: const Icon(Icons.edit_outlined),
                                          onPressed: () => _onEditField(index),
                                        ),
                                        IconButton(
                                          icon: const Icon(Icons.delete_outline, color: Colors.red),
                                          onPressed: () => setState(() => schemaList.removeAt(index)),
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                              ),
                            );
                          }),
                        ],
                      ),
              ),
              // Footer
              Container(
                padding: const EdgeInsets.fromLTRB(24, 20, 24, 24),
                decoration: BoxDecoration(
                  color: Colors.white,
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.05),
                      blurRadius: 10,
                      offset: const Offset(0, -5),
                    ),
                  ],
                  border: Border(top: BorderSide(color: Colors.grey.withOpacity(0.1))),
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton.icon(
                        icon: const Icon(Icons.add_rounded),
                        label: const Text(
                          'Neues Feld hinzufügen',
                          style: TextStyle(fontWeight: FontWeight.w600, fontSize: 16),
                        ),
                        onPressed: _onAddField,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.blue[600],
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 16),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                          elevation: 0,
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),
                    Row(
                      children: [
                        Expanded(
                          child: OutlinedButton(
                            onPressed: () => Navigator.of(context).pop(),
                            style: OutlinedButton.styleFrom(
                              padding: const EdgeInsets.symmetric(vertical: 14),
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                              side: BorderSide(color: Colors.grey[300]!),
                            ),
                            child: Text(
                              'Abbrechen',
                              style: TextStyle(color: Colors.grey[700], fontWeight: FontWeight.w600),
                            ),
                          ),
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          child: ElevatedButton(
                            onPressed: () => Navigator.of(context).pop(schemaList),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.grey[900],
                              foregroundColor: Colors.white,
                              padding: const EdgeInsets.symmetric(vertical: 14),
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                              elevation: 0,
                            ),
                            child: const Text(
                              'Speichern',
                              style: TextStyle(fontWeight: FontWeight.w600),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class AddSchemaFieldDialog extends StatefulWidget {
  final Uuid uuid;
  final Map<String, dynamic>? existingField;
  const AddSchemaFieldDialog({Key? key, required this.uuid, this.existingField}) : super(key: key);

  @override
  _AddSchemaFieldDialogState createState() => _AddSchemaFieldDialogState();
}

class _AddSchemaFieldDialogState extends State<AddSchemaFieldDialog> {
  late final TextEditingController labelCtrl;
  late String selectedType;
  late bool isEditable;

  @override
  void initState() {
    super.initState();
    labelCtrl = TextEditingController(text: widget.existingField?['label'] ?? '');
    final fieldType = widget.existingField?['type'] ?? 'string';
    // Konvertiere alte Typen zu neuen: 'text' -> 'string', 'number' -> 'int'
    if (fieldType == 'text') {
      selectedType = 'string';
    } else if (fieldType == 'number') {
      selectedType = 'int';
    } else {
      selectedType = (fieldType == 'string' || fieldType == 'int') ? fieldType : 'string';
    }
    isEditable = widget.existingField?['editable'] ?? true;
  }

  @override
  void dispose() {
    labelCtrl.dispose();
    super.dispose();
  }

  String _generateKey(String label) {
    final slug = label.toLowerCase().replaceAll(RegExp(r'[^a-z0-9]+'), '_').trim();
    return '${slug}_${widget.uuid.v4().substring(0, 4)}';
  }

  @override
  Widget build(BuildContext context) {
    final maxHeight = MediaQuery.of(context).size.height * 0.85;
    
    return ClipRRect(
      borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
      child: ConstrainedBox(
        constraints: BoxConstraints(maxHeight: maxHeight),
        child: Container(
          color: Colors.white,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Header
              Container(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [
                      Colors.blue.withOpacity(0.12),
                      Colors.blue.withOpacity(0.06),
                    ],
                  ),
                  border: Border(
                    bottom: BorderSide(
                      color: Colors.grey.withOpacity(0.15),
                      width: 1,
                    ),
                  ),
                ),
                padding: const EdgeInsets.fromLTRB(28, 28, 28, 28),
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          colors: [
                            Colors.blue[400]!,
                            Colors.blue[600]!,
                          ],
                        ),
                        borderRadius: BorderRadius.circular(14),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.blue.withOpacity(0.3),
                            blurRadius: 8,
                            offset: const Offset(0, 2),
                          ),
                        ],
                      ),
                      child: Icon(
                        widget.existingField == null ? Icons.add_box : Icons.edit,
                        color: Colors.white,
                        size: 26,
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Text(
                        widget.existingField == null ? 'Neues Feld' : 'Feld bearbeiten',
                        style: TextStyle(
                          fontSize: 22,
                          fontWeight: FontWeight.w700,
                          color: Colors.grey[900],
                          letterSpacing: -0.3,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              // Content
              Flexible(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.fromLTRB(28, 28, 28, 20),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      TextField(
                        controller: labelCtrl,
                        decoration: InputDecoration(
                          labelText: 'Anzeigename (Label)',
                          contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 18),
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(14)),
                          filled: true,
                          fillColor: Colors.grey[50],
                        ),
                        style: const TextStyle(fontSize: 16),
                        autofocus: widget.existingField == null,
                      ),
                      const SizedBox(height: 20),
                      DropdownButtonFormField<String>(
                        value: selectedType,
                        items: const [
                          DropdownMenuItem(value: 'string', child: Text('Text')),
                          DropdownMenuItem(value: 'int', child: Text('Zahl')),
                        ],
                        onChanged: (v) => setState(() => selectedType = v!),
                        decoration: InputDecoration(
                          labelText: 'Datentyp',
                          contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 18),
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(14)),
                          filled: true,
                          fillColor: Colors.grey[50],
                        ),
                        style: const TextStyle(fontSize: 16),
                      ),
                      const SizedBox(height: 24),
                      Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: Colors.grey[50],
                          borderRadius: BorderRadius.circular(14),
                          border: Border.all(color: Colors.grey.withOpacity(0.2), width: 1.5),
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  const Text(
                                    'Bearbeitbar',
                                    style: TextStyle(
                                      fontWeight: FontWeight.w600,
                                      fontSize: 16,
                                    ),
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    'Darf das Feld editiert werden?',
                                    style: TextStyle(fontSize: 13, color: Colors.grey[600]),
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(width: 16),
                            Switch(
                              value: isEditable,
                              onChanged: (v) => setState(() => isEditable = v),
                              activeColor: Colors.blue[600],
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              // Footer
              Container(
                padding: const EdgeInsets.fromLTRB(28, 20, 28, 28),
                decoration: BoxDecoration(
                  color: Colors.white,
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.05),
                      blurRadius: 10,
                      offset: const Offset(0, -5),
                    ),
                  ],
                  border: Border(top: BorderSide(color: Colors.grey.withOpacity(0.1))),
                ),
                child: Row(
                  children: [
                    Expanded(
                      child: OutlinedButton(
                        onPressed: () => Navigator.of(context).pop(),
                        style: OutlinedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(vertical: 16),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                          side: BorderSide(color: Colors.grey[300]!, width: 1.5),
                        ),
                        child: Text(
                          'Abbrechen',
                          style: TextStyle(
                            color: Colors.grey[700],
                            fontWeight: FontWeight.w600,
                            fontSize: 15,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 18),
                    Expanded(
                      child: ElevatedButton(
                        onPressed: () {
                          if (labelCtrl.text.isEmpty) return;
                          Navigator.of(context).pop({
                            'key': widget.existingField?['key'] ?? _generateKey(labelCtrl.text),
                            'label': labelCtrl.text,
                            'type': selectedType,
                            'editable': isEditable,
                          });
                        },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.blue[600],
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 16),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                          elevation: 0,
                        ),
                        child: const Text(
                          'Übernehmen',
                          style: TextStyle(
                            fontWeight: FontWeight.w600,
                            fontSize: 15,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
