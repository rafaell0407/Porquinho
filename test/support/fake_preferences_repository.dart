import 'package:porquinho/features/preferences/preferences_repository.dart';
import 'package:porquinho/features/reports/models/report_preferences.dart';
import 'package:porquinho/features/tools/models/tool_preferences.dart';

/// Preferências em memória, para testes de tela.
class FakePreferencesRepository implements PreferencesRepository {
  FakePreferencesRepository([
    this.tools_ = ToolPreferences.empty,
    this.reports_ = ReportPreferences.empty,
  ]);

  ToolPreferences tools_;
  ReportPreferences reports_;
  int writes = 0;

  @override
  Future<String?> theme() async => null;

  @override
  Future<void> setTheme(String? theme) async {}

  @override
  Future<Map<String, String>> onboarding() async => const {};

  @override
  Future<void> setOnboardingStep(String step, String status) async {}

  @override
  Future<ToolPreferences> tools() async => tools_;

  @override
  Future<void> setToolSelection(List<String>? toolIds) async {
    writes++;
    tools_ = tools_.withSelected(toolIds);
  }

  @override
  Future<void> dismissToolIntro(String toolId) async {
    writes++;
    tools_ = tools_.withDismissed(toolId);
  }

  @override
  Future<ReportPreferences> reports() async => reports_;

  @override
  Future<void> setReportSelection(List<String>? reportIds) async {
    writes++;
    reports_ = reports_.withSelected(reportIds);
  }

  @override
  Future<void> completeReportSetup(ReportSetupStatus status) async {
    writes++;
    reports_ = reports_.withSetup(status);
  }
}
