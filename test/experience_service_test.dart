import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:first/services/experience_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('demo mode can be toggled and observed', () async {
    SharedPreferences.setMockInitialValues({});

    expect(await ExperienceService.loadDemoMode(), false);
    expect(ExperienceService.demoModeEnabled.value, false);

    await ExperienceService.setDemoModeEnabled(true);

    expect(await ExperienceService.loadDemoMode(), true);
    expect(ExperienceService.demoModeEnabled.value, true);
  });

  test('addDemoExp adds experience and returns the updated total', () async {
    SharedPreferences.setMockInitialValues({'xp_total': 90});

    final totalExp = await ExperienceService.addDemoExp(25);

    expect(totalExp, 115);
    expect(await ExperienceService.getTotalExp(), 115);
    expect(ExperienceService.levelFromExp(totalExp), 2);
  });

  test('resetExp clears experience and refreshes the save timestamp', () async {
    SharedPreferences.setMockInitialValues({
      'xp_total': 250,
      'xp_last_save_ms': 1,
    });

    final totalExp = await ExperienceService.resetExp();
    final prefs = await SharedPreferences.getInstance();

    expect(totalExp, 0);
    expect(await ExperienceService.getTotalExp(), 0);
    expect(prefs.getInt('xp_last_save_ms'), greaterThan(1));
  });
}
