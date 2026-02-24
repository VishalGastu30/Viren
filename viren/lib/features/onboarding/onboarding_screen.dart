import 'package:flutter/material.dart';

import '../../app/router.dart';
import '../../core/theme/design_tokens.dart';
import '../../core/animations/animation_presets.dart';

class OnboardingScreen extends StatefulWidget {
  const OnboardingScreen({super.key});

  @override
  State<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends State<OnboardingScreen> {
  final PageController _pageController = PageController();
  int _currentPage = 0;

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  void _nextPage() {
    if (_currentPage == 1) {
       Navigator.of(context).pushReplacement(
        PageRouteBuilder(
          pageBuilder: (context, animation, secondaryAnimation) => const VirenRouter(),
          transitionsBuilder: (context, animation, secondaryAnimation, child) {
            return FadeTransition(opacity: animation, child: child);
          },
          transitionDuration: AnimationPresets.durationNormal,
        )
      );
    } else {
      _pageController.nextPage(
        duration: AnimationPresets.durationNormal,
        curve: AnimationPresets.entrance,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: DesignTokens.graphiteBase,
      body: SafeArea(
        child: Column(
          children: [
            Expanded(
              child: PageView(
                controller: _pageController,
                physics: const NeverScrollableScrollPhysics(), // Forced linear progression
                onPageChanged: (index) => setState(() => _currentPage = index),
                children: const [
                  _OnboardingPage(
                    title: 'Offline First.',
                    subtitle: 'Your network is the only network.',
                    description: 'Viren holds your financial history securely on this device. No servers. No aggregators. Just you and your portfolio.',
                    icon: Icons.shield_rounded,
                  ),
                  _OnboardingPage(
                    title: 'Intelligent Parse.',
                    subtitle: 'Mock Gmail Sync', // Noted as mock heavily
                    description: 'Link your Gmail to automatically parse PDF contract notes. We extract what is necessary and forget the rest.',
                    icon: Icons.mark_email_read_rounded,
                  ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(32.0),
              child: Column(
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: List.generate(2, (index) {
                      return AnimatedContainer(
                        duration: AnimationPresets.durationFast,
                        margin: const EdgeInsets.symmetric(horizontal: 4),
                        width: _currentPage == index ? 24 : 8,
                        height: 4,
                        decoration: BoxDecoration(
                          color: _currentPage == index ? DesignTokens.obsidianTeal : DesignTokens.graphiteSurface,
                          borderRadius: BorderRadius.circular(2),
                        ),
                      );
                    }),
                  ),
                  const SizedBox(height: 32),
                  SizedBox(
                    width: double.infinity,
                    height: 56,
                    child: ElevatedButton(
                      onPressed: _nextPage,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: DesignTokens.obsidianTeal,
                        foregroundColor: DesignTokens.textHighContrast,
                        elevation: 0,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(16),
                        ),
                      ),
                      child: Text(
                        _currentPage == 0 ? 'Continue' : 'Enter Viren',
                        style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w600),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _OnboardingPage extends StatelessWidget {
  final String title;
  final String subtitle;
  final String description;
  final IconData icon;

  const _OnboardingPage({
    required this.title,
    required this.subtitle,
    required this.description,
    required this.icon,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(32.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: DesignTokens.graphiteSurface,
              shape: BoxShape.circle,
            ),
            child: Icon(
              icon,
              size: 40,
              color: DesignTokens.textHighContrast,
            ),
          ),
          const SizedBox(height: 40),
          Text(
            title,
            style: Theme.of(context).textTheme.displayLarge,
          ),
          const SizedBox(height: 12),
          Text(
            subtitle,
            style: Theme.of(context).textTheme.titleLarge?.copyWith(
              color: DesignTokens.obsidianTeal,
            ),
          ),
          const SizedBox(height: 24),
          Text(
            description,
            style: Theme.of(context).textTheme.bodyLarge?.copyWith(
              color: DesignTokens.textMediumContrast,
              height: 1.5,
            ),
          ),
        ],
      ),
    );
  }
}
