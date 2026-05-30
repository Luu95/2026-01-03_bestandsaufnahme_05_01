import 'package:flutter/material.dart';

/// Bestätigungsdialog: Löschen erst nach exakter Eingabe des Elementnamens.
Future<bool> showConfirmDeleteDialog(
  BuildContext context, {
  required String itemType,
  required String itemName,
  bool isPermanent = false,
}) async {
  return await showDialog<bool>(
        context: context,
        barrierDismissible: false,
        barrierColor: Colors.black.withOpacity(0.5),
        builder: (ctx) => _ConfirmDeleteDialog(
          itemType: itemType,
          itemName: itemName,
          isPermanent: isPermanent,
        ),
      ) ??
      false;
}

class _ConfirmDeleteDialog extends StatefulWidget {
  final String itemType;
  final String itemName;
  final bool isPermanent;

  const _ConfirmDeleteDialog({
    required this.itemType,
    required this.itemName,
    required this.isPermanent,
  });

  @override
  State<_ConfirmDeleteDialog> createState() => _ConfirmDeleteDialogState();
}

class _ConfirmDeleteDialogState extends State<_ConfirmDeleteDialog> {
  final _controller = TextEditingController();
  bool get _canDelete => _controller.text.trim() == widget.itemName;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final actionLabel = widget.isPermanent ? 'Endgültig löschen' : 'In Papierkorb verschieben';

    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
      child: Container(
        padding: const EdgeInsets.all(24),
        constraints: const BoxConstraints(maxWidth: 420),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Center(
              child: Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: Colors.red.withOpacity(0.1),
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  widget.isPermanent ? Icons.delete_forever : Icons.delete_outline,
                  size: 32,
                  color: Colors.red[700],
                ),
              ),
            ),
            const SizedBox(height: 20),
            Text(
              widget.isPermanent
                  ? '${widget.itemType} endgültig löschen?'
                  : '${widget.itemType} löschen?',
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.w600,
                color: Colors.grey[900],
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 12),
            Text(
              widget.isPermanent
                  ? '"${widget.itemName}" wird unwiderruflich gelöscht. Gib den Namen zur Bestätigung ein:'
                  : '"${widget.itemName}" wird in den Papierkorb verschoben. Gib den Namen zur Bestätigung ein:',
              style: TextStyle(fontSize: 14, color: Colors.grey[700], height: 1.5),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 20),
            TextField(
              controller: _controller,
              autofocus: true,
              decoration: InputDecoration(
                labelText: 'Name eingeben',
                hintText: widget.itemName,
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                errorText: _controller.text.isNotEmpty && !_canDelete
                    ? 'Name stimmt nicht überein'
                    : null,
              ),
              onChanged: (_) => setState(() {}),
            ),
            const SizedBox(height: 24),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: () => Navigator.of(context).pop(false),
                    style: OutlinedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    child: const Text('Abbrechen'),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: ElevatedButton(
                    onPressed: _canDelete ? () => Navigator.of(context).pop(true) : null,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.red[700],
                      foregroundColor: Colors.white,
                      disabledBackgroundColor: Colors.grey[300],
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    child: Text(actionLabel),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
