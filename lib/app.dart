import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'core/theme.dart';
import 'state/providers.dart';
import 'views/hub_screen.dart';
import 'views/onboarding_screen.dart';

class SafeScapeApp extends ConsumerWidget {
  const SafeScapeApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return MaterialApp(
      title: 'Sensory SafeScape',
      debugShowCheckedModeBanner: false,
      theme: buildTheme(),
      home: const RootScreen(),
      builder: (context, child) {
        // Keep text readable but stop huge system font scales breaking cards.
        final mq = MediaQuery.of(context);
        final scaled = MediaQuery(
          data: mq.copyWith(textScaler: mq.textScaler.clamp(minScaleFactor: 1, maxScaleFactor: 1.3)),
          child: child!,
        );
        return Stack(children: [scaled, const SoftLightingOverlay()]);
      },
    );
  }
}

/// The first route. It follows the store, so wiping the data (sign-out or
/// account deletion) always lands on the welcome page, never a blank hub.
class RootScreen extends ConsumerWidget {
  const RootScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final onboarded = ref.watch(storeProvider.select((s) => s.onboarded));
    return onboarded ? const HubScreen() : const OnboardingScreen();
  }
}

/// "Soft Lighting": a warm sand wash over every screen (PDD Screen 1).
class SoftLightingOverlay extends ConsumerWidget {
  const SoftLightingOverlay({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final child = ref.watch(storeProvider).activeChild;
    final on = child?.sensory.softLighting ?? false;
    final warmth = child?.sensory.colorTemperature ?? 0.5;
    return IgnorePointer(
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 800),
        color: on ? const Color(0xFFF4B97A).withValues(alpha: 0.04 + 0.12 * warmth) : const Color(0x00000000),
      ),
    );
  }
}
