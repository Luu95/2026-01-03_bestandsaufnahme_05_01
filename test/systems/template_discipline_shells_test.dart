import 'package:flutter_test/flutter_test.dart';
import 'package:bestandsaufnahme_01/features/systems/services/template_service.dart';

void main() {
  test('disciplineShell has label only', () {
    final d = TemplateService.disciplineShell('  HLKS  ');
    expect(d.label, 'HLKS');
    expect(d.schema, isEmpty);
    expect(d.revisionsobjektSchemas, isEmpty);
  });

  test('disciplineShells dedupes and sorts', () {
    final list = TemplateService.disciplineShells(['HLKS', ' Elektro ', 'HLKS']);
    expect(list.map((d) => d.label), ['Elektro', 'HLKS']);
  });

  test('matchGewerkLabel prefers exact then case then substring', () {
    const candidates = ['ITC 08 Klass.', 'Elektro', 'HLKS'];
    expect(TemplateService.matchGewerkLabel(candidates, 'Elektro'), 'Elektro');
    expect(TemplateService.matchGewerkLabel(candidates, 'elektro'), 'Elektro');
    expect(
      TemplateService.matchGewerkLabel(candidates, 'ITC 08'),
      'ITC 08 Klass.',
    );
    expect(TemplateService.matchGewerkLabel(candidates, 'Unbekannt'), isNull);
  });
}
