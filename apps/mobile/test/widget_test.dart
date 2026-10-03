import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:offramp_mobile/main.dart';

void main() {
  testWidgets('App launches and renders onboarding screen', (WidgetTester tester) async {
    await tester.pumpWidget(
      const ProviderScope(
        child: OffRampApp(),
      ),
    );

    // Verify Onboarding Screen Elements
    expect(find.text('Get Started'), findsOneWidget);
    expect(find.text('INSTANT FIAT SETTLEMENT'), findsOneWidget);
  });
}
