/// Schema-Editor für Anlagen-Eingabefelder (CSV-Settings und Dialog).

import 'package:flutter/material.dart';
import 'package:uuid/uuid.dart';

import 'package:bestandsaufnahme_01/app/theme/app_palette.dart';

BoxDecoration _schemaFieldCardDecoration(BuildContext context) {
  final theme = Theme.of(context);
  final colorScheme = theme.colorScheme;
  return BoxDecoration(
    color: colorScheme.surface,
    borderRadius: BorderRadius.circular(16),
    border: Border.all(color: colorScheme.outline.withOpacity(0.25), width: 1.5),
    boxShadow: [
      BoxShadow(
        color: Colors.black.withOpacity(theme.brightness == Brightness.dark ? 0.25 : 0.03),
        blurRadius: 8,
        offset: const Offset(0, 2),
      ),
    ],
  );
}

/// Inline-Schema-Editor für den CSV-Settings-Tab (ohne Dialog-Hülle).
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

/// State des Inline-Schema-Editors.
class _SchemaEditorWidgetState extends State<SchemaEditorWidget> {
  late List<Map<String, dynamic>> schemaList;
  final _uuid = Uuid();

  bool _isGlobalField(Map<String, dynamic> field) => field['isGlobal'] == true;

  List<int> _individualIndices() {
    final indices = <int>[];
    for (var i = 0; i < schemaList.length; i++) {
      if (!_isGlobalField(schemaList[i])) indices.add(i);
    }
    return indices;
  }

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
      builder: (_) => AddSchemaFieldDialog(
        uuid: _uuid,
      ),
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
    final visibleIndices = widget.allowEditGlobal
        ? List<int>.generate(schemaList.length, (i) => i)
        : _individualIndices();
    final visibleCount = visibleIndices.length;

    return Column(
      children: [
        Expanded(
          child: visibleCount == 0
              ? Center(
                  child: Padding(
                    padding: const EdgeInsets.all(32),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Container(
                          padding: const EdgeInsets.all(20),
                          decoration: BoxDecoration(
                            color: AppPalette.primary.withOpacity(0.1),
                            shape: BoxShape.circle,
                          ),
                          child: Icon(
                            Icons.schema_outlined,
                            size: 64,
                            color: AppPalette.primaryLight,
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
                      if (widget.allowEditGlobal) {
                        if (newIndex > oldIndex) {
                          newIndex -= 1;
                        }
                        final item = schemaList.removeAt(oldIndex);
                        schemaList.insert(newIndex, item);
                      } else {
                        final globals = schemaList.where(_isGlobalField).toList();
                        final individuals = schemaList.where((f) => !_isGlobalField(f)).toList();
                        if (newIndex > oldIndex) {
                          newIndex -= 1;
                        }
                        final item = individuals.removeAt(oldIndex);
                        individuals.insert(newIndex, item);
                        schemaList = [...globals, ...individuals];
                      }
                      _notifyChange();
                    });
                  },
                  children: [
                    ...List.generate(visibleCount, (visibleIndex) {
                      final index = visibleIndices[visibleIndex];
                      final field = schemaList[index];
                      final type = (field['type'] ?? 'string').toString();
                      return Container(
                        key: ValueKey('${field['key']}_$index'),
                        margin: const EdgeInsets.only(bottom: 12),
                        decoration: _schemaFieldCardDecoration(context),
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
                                      color: Theme.of(context).colorScheme.surfaceContainerHighest,
                                      borderRadius: BorderRadius.circular(8),
                                    ),
                                    child: Icon(
                                      Icons.drag_handle,
                                      color: Theme.of(context).colorScheme.onSurfaceVariant,
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
                                                style: TextStyle(
                                                  fontWeight: FontWeight.w600,
                                                  fontSize: 16,
                                                  letterSpacing: -0.2,
                                                  color: Theme.of(context).colorScheme.onSurface,
                                                ),
                                                maxLines: 2,
                                                overflow: TextOverflow.ellipsis,
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
                                                color: AppPalette.fieldTypeBackground(type),
                                                borderRadius: BorderRadius.circular(8),
                                                border: Border.all(
                                                  color: AppPalette.fieldTypeBorder(type),
                                                ),
                                              ),
                                              child: Text(
                                                (type == 'int' || type == 'number')
                                                    ? 'Int'
                                                    : type == 'date'
                                                        ? 'Datum'
                                                        : type == 'dropdown'
                                                            ? 'Dropdown'
                                                            : 'String',
                                                style: TextStyle(
                                                  fontSize: 10,
                                                  color: AppPalette.fieldTypeText(type),
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
                                                    ? AppPalette.primary.withOpacity(0.15)
                                                    : Colors.grey.withOpacity(0.15),
                                                borderRadius: BorderRadius.circular(8),
                                                border: Border.all(
                                                  color: (field['editable'] ?? true)
                                                      ? AppPalette.primary.withOpacity(0.3)
                                                      : Colors.grey.withOpacity(0.3),
                                                ),
                                              ),
                                              child: Text(
                                                (field['editable'] ?? true) ? 'Editierbar' : 'Gesperrt',
                                                style: TextStyle(
                                                  fontSize: 10,
                                                  color: (field['editable'] ?? true)
                                                      ? AppPalette.primaryDark
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
                                    PopupMenuButton<String>(
                                      icon: const Icon(Icons.more_vert),
                                      padding: EdgeInsets.zero,
                                      constraints: const BoxConstraints(minWidth: 1),
                                      onSelected: (value) {
                                        if (value == 'edit') {
                                          _onEditField(index);
                                        } else if (value == 'delete') {
                                          showDialog<bool>(
                                            context: context,
                                            builder: (ctx) => AlertDialog(
                                              title: const Text('Feld löschen?'),
                                              content: Text(
                                                '„${field['label']}“ wirklich löschen?',
                                              ),
                                              actions: [
                                                TextButton(
                                                  onPressed: () => Navigator.of(ctx).pop(false),
                                                  child: const Text('Abbrechen'),
                                                ),
                                                TextButton(
                                                  onPressed: () => Navigator.of(ctx).pop(true),
                                                  style: TextButton.styleFrom(foregroundColor: AppPalette.error),
                                                  child: const Text('Löschen'),
                                                ),
                                              ],
                                            ),
                                          ).then((confirmed) {
                                            if (confirmed == true && mounted) {
                                              setState(() {
                                                schemaList.removeAt(index);
                                                _notifyChange();
                                              });
                                            }
                                          });
                                        }
                                      },
                                      itemBuilder: (context) => [
                                        const PopupMenuItem(
                                          value: 'edit',
                                          child: Row(
                                            mainAxisSize: MainAxisSize.min,
                                            children: [
                                              Icon(Icons.edit_outlined, size: 20),
                                              SizedBox(width: 12),
                                              Text('Bearbeiten'),
                                            ],
                                          ),
                                        ),
                                        PopupMenuItem(
                                          value: 'delete',
                                          child: Row(
                                            mainAxisSize: MainAxisSize.min,
                                            children: [
                                              Icon(Icons.delete_outline, size: 20, color: AppPalette.error),
                                              const SizedBox(width: 12),
                                              Text('Löschen', style: TextStyle(color: AppPalette.error)),
                                            ],
                                          ),
                                        ),
                                      ],
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
            color: Theme.of(context).colorScheme.surface,
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(Theme.of(context).brightness == Brightness.dark ? 0.3 : 0.05),
                blurRadius: 10,
                offset: const Offset(0, -5),
              ),
            ],
            border: Border(top: BorderSide(color: Theme.of(context).colorScheme.outline.withOpacity(0.15))),
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
                backgroundColor: AppPalette.primary,
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

/// Modal-Dialog zum Bearbeiten eines Schemas (Rückgabe der Feldliste).
class SchemaEditorDialog extends StatefulWidget {
  final List<Map<String, dynamic>> existingSchema;
  const SchemaEditorDialog({Key? key, required this.existingSchema}) : super(key: key);

  @override
  _SchemaEditorDialogState createState() => _SchemaEditorDialogState();
}

/// State des Schema-Dialogs.
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
          color: Theme.of(context).colorScheme.surface,
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
                      AppPalette.primary.withOpacity(0.12),
                      AppPalette.primary.withOpacity(0.06),
                    ],
                  ),
                  border: Border(
                    bottom: BorderSide(
                      color: Theme.of(context).colorScheme.outline.withOpacity(0.15),
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
                            AppPalette.primaryLight!,
                            AppPalette.primary!,
                          ],
                        ),
                        borderRadius: BorderRadius.circular(14),
                        boxShadow: [
                          BoxShadow(
                            color: AppPalette.primary.withOpacity(0.3),
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
                              fontSize: 17,
                              fontWeight: FontWeight.w600,
                              color: Theme.of(context).colorScheme.onSurface,
                              letterSpacing: -0.2,
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
                                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                              if (schemaList.length > 1)
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                  decoration: BoxDecoration(
                                    color: AppPalette.primary.withOpacity(0.1),
                                    borderRadius: BorderRadius.circular(6),
                                  ),
                                  child: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Icon(
                                        Icons.drag_handle,
                                        size: 12,
                                        color: AppPalette.primaryDark,
                                      ),
                                      const SizedBox(width: 3),
                                      Text(
                                        'Verschieben',
                                        style: TextStyle(
                                          fontSize: 10,
                                          color: AppPalette.primaryDark,
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
                                  color: AppPalette.primary.withOpacity(0.1),
                                  shape: BoxShape.circle,
                                ),
                                child: Icon(
                                  Icons.schema_outlined,
                                  size: 64,
                                  color: AppPalette.primaryLight,
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
                            final type = (field['type'] ?? 'string').toString();
                            return Container(
                              key: ValueKey('${field['key']}_$index'),
                              margin: const EdgeInsets.only(bottom: 12),
                              decoration: _schemaFieldCardDecoration(context),
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
                                            color: Theme.of(context).colorScheme.surfaceContainerHighest,
                                            borderRadius: BorderRadius.circular(8),
                                          ),
                                          child: Icon(
                                            Icons.drag_handle,
                                            color: Theme.of(context).colorScheme.onSurfaceVariant,
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
                                                      style: TextStyle(
                                                        fontWeight: FontWeight.w600,
                                                        fontSize: 16,
                                                        letterSpacing: -0.2,
                                                        color: Theme.of(context).colorScheme.onSurface,
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
                                                      color: AppPalette.fieldTypeBackground(type),
                                                      borderRadius: BorderRadius.circular(8),
                                                      border: Border.all(
                                                        color: AppPalette.fieldTypeBorder(type),
                                                      ),
                                                    ),
                                                    child: Text(
                                                      type == 'int'
                                                          ? 'Int'
                                                          : type == 'date'
                                                              ? 'Datum'
                                                              : type == 'dropdown'
                                                                  ? 'Dropdown'
                                                                  : 'String',
                                                      style: TextStyle(
                                                        fontSize: 10,
                                                        color: AppPalette.fieldTypeText(type),
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
                                                          ? AppPalette.primary.withOpacity(0.15)
                                                          : Colors.grey.withOpacity(0.15),
                                                      borderRadius: BorderRadius.circular(8),
                                                      border: Border.all(
                                                        color: (field['editable'] ?? true)
                                                            ? AppPalette.primary.withOpacity(0.3)
                                                            : Colors.grey.withOpacity(0.3),
                                                      ),
                                                    ),
                                                    child: Text(
                                                      (field['editable'] ?? true) ? 'Editierbar' : 'Gesperrt',
                                                      style: TextStyle(
                                                        fontSize: 10,
                                                        color: (field['editable'] ?? true)
                                                            ? AppPalette.primaryDark
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
                                        PopupMenuButton<String>(
                                          icon: const Icon(Icons.more_vert),
                                          padding: EdgeInsets.zero,
                                          constraints: const BoxConstraints(minWidth: 1),
                                          onSelected: (value) {
                                            if (value == 'edit') {
                                              _onEditField(index);
                                            } else if (value == 'delete') {
                                              showDialog<bool>(
                                                context: context,
                                                builder: (ctx) => AlertDialog(
                                                  title: const Text('Feld löschen?'),
                                                  content: Text(
                                                    '„${field['label']}“ wirklich löschen?',
                                                  ),
                                                  actions: [
                                                    TextButton(
                                                      onPressed: () => Navigator.of(ctx).pop(false),
                                                      child: const Text('Abbrechen'),
                                                    ),
                                                    TextButton(
                                                      onPressed: () => Navigator.of(ctx).pop(true),
                                                      style: TextButton.styleFrom(foregroundColor: AppPalette.error),
                                                      child: const Text('Löschen'),
                                                    ),
                                                  ],
                                                ),
                                              ).then((confirmed) {
                                                if (confirmed == true && mounted) {
                                                  setState(() => schemaList.removeAt(index));
                                                }
                                              });
                                            }
                                          },
                                          itemBuilder: (context) => [
                                            const PopupMenuItem(
                                              value: 'edit',
                                              child: Row(
                                                mainAxisSize: MainAxisSize.min,
                                                children: [
                                                  Icon(Icons.edit_outlined, size: 20),
                                                  SizedBox(width: 12),
                                                  Text('Bearbeiten'),
                                                ],
                                              ),
                                            ),
                                            PopupMenuItem(
                                              value: 'delete',
                                              child: Row(
                                                mainAxisSize: MainAxisSize.min,
                                                children: [
                                                  Icon(Icons.delete_outline, size: 20, color: AppPalette.error),
                                                  const SizedBox(width: 12),
                                                  Text('Löschen', style: TextStyle(color: AppPalette.error)),
                                                ],
                                              ),
                                            ),
                                          ],
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
                  color: Theme.of(context).colorScheme.surface,
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(Theme.of(context).brightness == Brightness.dark ? 0.3 : 0.05),
                      blurRadius: 10,
                      offset: const Offset(0, -5),
                    ),
                  ],
                  border: Border(top: BorderSide(color: Theme.of(context).colorScheme.outline.withOpacity(0.15))),
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
                          backgroundColor: AppPalette.primary,
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
  const AddSchemaFieldDialog({
    Key? key,
    required this.uuid,
    this.existingField,
  }) : super(key: key);

  @override
  _AddSchemaFieldDialogState createState() => _AddSchemaFieldDialogState();
}

class _AddSchemaFieldDialogState extends State<AddSchemaFieldDialog> {
  late final TextEditingController labelCtrl;
  late final TextEditingController optionsCtrl;
  late String selectedType;
  late bool isEditable;

  static String _optionsToText(dynamic raw) {
    if (raw is! List) return '';
    return raw.map((e) => e.toString().trim()).where((e) => e.isNotEmpty).join('; ');
  }

  static List<String> _parseOptionsText(String text) {
    if (text.trim().isEmpty) return [];
    final split = text.contains(';') ? text.split(';') : text.split(',');
    return split.map((e) => e.trim()).where((e) => e.isNotEmpty).toList();
  }

  @override
  void initState() {
    super.initState();
    labelCtrl = TextEditingController(text: widget.existingField?['label'] ?? '');
    optionsCtrl = TextEditingController(text: _optionsToText(widget.existingField?['options']));
    final fieldType = widget.existingField?['type'] ?? 'string';
    // Konvertiere alte Typen zu neuen: 'text' -> 'string', 'number' -> 'int'
    if (fieldType == 'text') {
      selectedType = 'string';
    } else if (fieldType == 'number') {
      selectedType = 'int';
    } else {
      selectedType = (fieldType == 'string' ||
              fieldType == 'int' ||
              fieldType == 'date' ||
              fieldType == 'dropdown')
          ? fieldType
          : 'string';
    }
    isEditable = widget.existingField?['editable'] ?? true;
  }

  @override
  void dispose() {
    labelCtrl.dispose();
    optionsCtrl.dispose();
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
          color: Theme.of(context).colorScheme.surface,
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
                      AppPalette.primary.withOpacity(0.12),
                      AppPalette.primary.withOpacity(0.06),
                    ],
                  ),
                  border: Border(
                    bottom: BorderSide(
                      color: Theme.of(context).colorScheme.outline.withOpacity(0.15),
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
                            AppPalette.primaryLight!,
                            AppPalette.primary!,
                          ],
                        ),
                        borderRadius: BorderRadius.circular(14),
                        boxShadow: [
                          BoxShadow(
                            color: AppPalette.primary.withOpacity(0.3),
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
                          color: Theme.of(context).colorScheme.onSurface,
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
                        ),
                        style: const TextStyle(fontSize: 16),
                        autofocus: widget.existingField == null,
                      ),
                      const SizedBox(height: 20),
                      DropdownButtonFormField<String>(
                        value: selectedType,
                        items: [
                          DropdownMenuItem(
                            value: 'string',
                            child: Text('String', style: TextStyle(fontSize: 16, color: Theme.of(context).colorScheme.onSurface)),
                          ),
                          DropdownMenuItem(
                            value: 'int',
                            child: Text('Int', style: TextStyle(fontSize: 16, color: Theme.of(context).colorScheme.onSurface)),
                          ),
                          DropdownMenuItem(
                            value: 'date',
                            child: Text('Datum', style: TextStyle(fontSize: 16, color: Theme.of(context).colorScheme.onSurface)),
                          ),
                          DropdownMenuItem(
                            value: 'dropdown',
                            child: Text('Dropdown', style: TextStyle(fontSize: 16, color: Theme.of(context).colorScheme.onSurface)),
                          ),
                        ],
                        onChanged: (v) => setState(() => selectedType = v!),
                        decoration: InputDecoration(
                          labelText: 'Datentyp',
                          contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 18),
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(14)),
                          filled: true,
                          fillColor: null,
                        ),
                        style: TextStyle(fontSize: 16, color: Theme.of(context).colorScheme.onSurface),
                      ),
                      if (selectedType == 'dropdown') ...[
                        const SizedBox(height: 14),
                        TextField(
                          controller: optionsCtrl,
                          decoration: InputDecoration(
                            labelText: 'Optionen (Semikolon-getrennt)',
                            hintText: 'z. B. Gas; Öl; Holz',
                            contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 18),
                            border: OutlineInputBorder(borderRadius: BorderRadius.circular(14)),
                            filled: true,
                          ),
                          style: const TextStyle(fontSize: 16),
                          minLines: 1,
                          maxLines: 4,
                        ),
                      ],
                      const SizedBox(height: 24),
                      Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: Theme.of(context).colorScheme.surfaceContainerHighest,
                          borderRadius: BorderRadius.circular(14),
                          border: Border.all(color: Theme.of(context).colorScheme.outline.withOpacity(0.25), width: 1.5),
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
                              activeColor: AppPalette.primary,
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
                  color: Theme.of(context).colorScheme.surface,
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(Theme.of(context).brightness == Brightness.dark ? 0.3 : 0.05),
                      blurRadius: 10,
                      offset: const Offset(0, -5),
                    ),
                  ],
                  border: Border(top: BorderSide(color: Theme.of(context).colorScheme.outline.withOpacity(0.15))),
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

                          final result = <String, dynamic>{
                            'key': widget.existingField?['key'] ?? _generateKey(labelCtrl.text),
                            'label': labelCtrl.text,
                            'type': selectedType,
                            'editable': isEditable,
                          };
                          if (selectedType == 'dropdown') {
                            final options = _parseOptionsText(optionsCtrl.text);
                            if (options.isNotEmpty) {
                              result['options'] = options;
                            }
                          }
                          Navigator.of(context).pop({...result});
                        },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppPalette.primary,
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
