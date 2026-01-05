// lib/pages/widgets/validation_progress_widget.dart

import 'package:flutter/material.dart';
import '../../services/anlage_validation_service.dart';

/// Motivierendes Widget zur Anzeige des Validierungsfortschritts
class ValidationProgressWidget extends StatelessWidget {
  final ValidationProgress progress;
  final String? title;

  const ValidationProgressWidget({
    Key? key,
    required this.progress,
    this.title,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    if (progress.total == 0) {
      return Card(
        margin: const EdgeInsets.all(16),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              Icon(Icons.info_outline, color: Colors.grey[600]),
              const SizedBox(width: 12),
              Text(
                'Keine Anlagen vorhanden',
                style: TextStyle(color: Colors.grey[600], fontSize: 14),
              ),
            ],
          ),
        ),
      );
    }

    final isComplete = progress.percentage >= 100;
    final isAlmostComplete = progress.percentage >= 80;
    final percentageColor = isComplete
        ? Colors.green
        : isAlmostComplete
            ? Colors.orange
            : Colors.blue;

    // Motivierende Nachricht basierend auf Fortschritt
    String motivationText;
    IconData motivationIcon;
    Color motivationColor;

    if (isComplete) {
      motivationText = '🎉 Alle Anlagen validiert! Perfekt!';
      motivationIcon = Icons.celebration;
      motivationColor = Colors.green;
    } else if (isAlmostComplete) {
      motivationText = '💪 Fast geschafft! Noch ${progress.remaining} Anlage${progress.remaining > 1 ? 'n' : ''} offen';
      motivationIcon = Icons.trending_up;
      motivationColor = Colors.orange;
    } else if (progress.percentage >= 50) {
      motivationText = '🔥 Gute Arbeit! Noch ${progress.remaining} Anlage${progress.remaining > 1 ? 'n' : ''} zu bearbeiten';
      motivationIcon = Icons.local_fire_department;
      motivationColor = Colors.deepOrange;
    } else {
      motivationText = '📋 Los geht\'s! ${progress.remaining} Anlage${progress.remaining > 1 ? 'n' : ''} warten auf Validierung';
      motivationIcon = Icons.assignment;
      motivationColor = Colors.blue;
    }

    return Card(
      margin: const EdgeInsets.all(16),
      elevation: 4,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(
          color: percentageColor.withOpacity(0.3),
          width: 2,
        ),
      ),
      child: Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(16),
          gradient: LinearGradient(
            colors: [
              percentageColor.withOpacity(0.1),
              percentageColor.withOpacity(0.05),
            ],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
        ),
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Titel
              if (title != null) ...[
                Row(
                  children: [
                    Icon(
                      Icons.check_circle_outline,
                      color: percentageColor,
                      size: 24,
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        title!,
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: Colors.black87,
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
              ],

              // Motivationsnachricht
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: motivationColor.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(
                    color: motivationColor.withOpacity(0.3),
                    width: 1,
                  ),
                ),
                child: Row(
                  children: [
                    Icon(motivationIcon, color: motivationColor, size: 20),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        motivationText,
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                          color: Colors.black87,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),

              // Prozentanzeige groß
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    '${progress.percentage.toStringAsFixed(0)}%',
                    style: TextStyle(
                      fontSize: 48,
                      fontWeight: FontWeight.bold,
                      color: percentageColor,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),

              // Fortschrittsbalken
              ClipRRect(
                borderRadius: BorderRadius.circular(12),
                child: LinearProgressIndicator(
                  value: progress.percentage / 100,
                  minHeight: 20,
                  backgroundColor: Colors.grey[200],
                  valueColor: AlwaysStoppedAnimation<Color>(percentageColor),
                ),
              ),
              const SizedBox(height: 12),

              // Statistiken
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [
                  _buildStatItem(
                    context,
                    Icons.check_circle,
                    '${progress.validated}',
                    'Validiert',
                    Colors.green,
                  ),
                  _buildStatItem(
                    context,
                    Icons.pending,
                    '${progress.remaining}',
                    'Offen',
                    Colors.orange,
                  ),
                  _buildStatItem(
                    context,
                    Icons.list,
                    '${progress.total}',
                    'Gesamt',
                    Colors.blue,
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildStatItem(
    BuildContext context,
    IconData icon,
    String value,
    String label,
    Color color,
  ) {
    return Column(
      children: [
        Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: color.withOpacity(0.1),
            shape: BoxShape.circle,
          ),
          child: Icon(icon, color: color, size: 20),
        ),
        const SizedBox(height: 4),
        Text(
          value,
          style: TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.bold,
            color: color,
          ),
        ),
        Text(
          label,
          style: TextStyle(
            fontSize: 12,
            color: Colors.grey[600],
          ),
        ),
      ],
    );
  }
}

