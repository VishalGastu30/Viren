import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';

import '../../core/theme/design_tokens.dart';
import '../../core/animations/animation_presets.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  // Use the global state for simplicity in this frontend test
  bool _isCalmMode = AnimationPresets.calmModeEnabled;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: DesignTokens.graphiteBase,
      appBar: AppBar(
        title: Text(
          'Settings',
          style: Theme.of(context).textTheme.titleLarge,
        ),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded),
          onPressed: () => Navigator.of(context).pop(),
        ),
      ),
      body: ListView(
        physics: const BouncingScrollPhysics(),
        padding: const EdgeInsets.all(24),
        children: [
          // Theme Group
          _SettingsGroupHeader(title: 'App Experience'),
          const SizedBox(height: 16),
          _SettingsSection(
            children: [
              _SettingsTile(
                icon: Icons.dark_mode_rounded,
                title: 'Dark Theme',
                subtitle: 'Viren is strictly dark-mode first for visual depth.',
                trailing: CupertinoSwitch(
                  value: true, 
                  onChanged: (val) {}, 
                  activeTrackColor: DesignTokens.obsidianTeal,
                ),
              ),
              const Divider(indent: 56, height: 1, color: DesignTokens.graphiteBase),
              _SettingsTile(
                icon: Icons.animation_rounded,
                title: 'Calm Mode',
                subtitle: 'Disable all complex animations, staggers, and transitions for an immediate, brutalist aesthetic.',
                trailing: CupertinoSwitch(
                  value: _isCalmMode, 
                  onChanged: (val) {
                    setState(() {
                       _isCalmMode = val;
                       AnimationPresets.calmModeEnabled = val; // Apply globally
                    });
                  }, 
                  activeTrackColor: DesignTokens.obsidianTeal,
                ),
              ),
            ],
          ),

          const SizedBox(height: 32),

          // Account Group
          _SettingsGroupHeader(title: 'Account & Data'),
          const SizedBox(height: 16),
          _SettingsSection(
            children: [
              _SettingsTile(
                icon: Icons.cloud_off_rounded,
                title: 'Offline Vault Storage',
                subtitle: 'Your portfolio data strictly remains on device.',
                trailing: Text('Active', style: Theme.of(context).textTheme.bodySmall?.copyWith(color: DesignTokens.obsidianTeal)),
              ),
              const Divider(indent: 56, height: 1, color: DesignTokens.graphiteBase),
              _SettingsTile(
                 icon: Icons.delete_outline_rounded,
                 title: 'Wipe Local Data',
                 iconColor: DesignTokens.crimsonWarning,
                 titleColor: DesignTokens.crimsonWarning,
                 onTap: () {
                    // Mock action
                 },
              )
            ],
          )
        ],
      )
    );
  }
}

class _SettingsGroupHeader extends StatelessWidget {
  final String title;

  const _SettingsGroupHeader({required this.title});

  @override
  Widget build(BuildContext context) {
    return Text(
      title,
      style: Theme.of(context).textTheme.titleMedium?.copyWith(
         color: DesignTokens.textMediumContrast,
      ),
    );
  }
}

class _SettingsSection extends StatelessWidget {
  final List<Widget> children;

  const _SettingsSection({required this.children});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
         color: DesignTokens.graphiteSurface,
         borderRadius: BorderRadius.circular(24),
         border: Border.all(color: Colors.white.withValues(alpha: 0.05)),
      ),
      child: Column(
         children: children,
      ),
    );
  }
}

class _SettingsTile extends StatelessWidget {
  final IconData icon;
  final String title;
  final String? subtitle;
  final Widget? trailing;
  final VoidCallback? onTap;
  final Color? iconColor;
  final Color? titleColor;

  const _SettingsTile({
    required this.icon,
    required this.title,
    this.subtitle,
    this.trailing,
    this.onTap,
    this.iconColor,
    this.titleColor,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(24), // Approx match to container
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                 color: (iconColor ?? DesignTokens.obsidianTeal).withValues(alpha: 0.1),
                 borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(icon, color: iconColor ?? DesignTokens.textHighContrast, size: 20),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title, 
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                       color: titleColor ?? DesignTokens.textHighContrast,
                       fontWeight: FontWeight.w500,
                    ),
                  ),
                  if (subtitle != null) ...[
                     const SizedBox(height: 4),
                     Text(
                        subtitle!,
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                           color: DesignTokens.textMediumContrast,
                           height: 1.3,
                        ),
                     ),
                  ]
                ],
              ),
            ),
            if (trailing != null) ...[
               const SizedBox(width: 16),
               trailing!,
            ],
            if (trailing == null && onTap != null) ...[
                const SizedBox(width: 16),
                const Icon(Icons.chevron_right_rounded, color: DesignTokens.textMediumContrast),
            ]
          ],
        ),
      ),
    );
  }
}
