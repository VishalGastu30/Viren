import 'package:flutter/material.dart';

import '../../core/theme/design_tokens.dart';

class StyleGuideScreen extends StatelessWidget {
  const StyleGuideScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: DesignTokens.graphiteBase,
      appBar: AppBar(
        title: Text('Style Guide', style: Theme.of(context).textTheme.titleLarge),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded),
          onPressed: () => Navigator.of(context).pop(),
        ),
      ),
      body: SingleChildScrollView(
         physics: const BouncingScrollPhysics(),
         padding: const EdgeInsets.all(24),
         child: Column(
           crossAxisAlignment: CrossAxisAlignment.start,
           children: [
             // Typography Section
             Text('Typography', style: Theme.of(context).textTheme.titleLarge?.copyWith(color: DesignTokens.obsidianTeal)),
             const SizedBox(height: 16),
             _SectionContainer(
               child: Column(
                 crossAxisAlignment: CrossAxisAlignment.start,
                 children: [
                   _TypographyRow(label: 'Display Large', style: Theme.of(context).textTheme.displayLarge),
                   const SizedBox(height: 12),
                   _TypographyRow(label: 'Display Medium', style: Theme.of(context).textTheme.displayMedium),
                   const SizedBox(height: 12),
                   _TypographyRow(label: 'Display Small', style: Theme.of(context).textTheme.displaySmall),
                   const SizedBox(height: 24),
                   _TypographyRow(label: 'Title Large', style: Theme.of(context).textTheme.titleLarge),
                   const SizedBox(height: 12),
                   _TypographyRow(label: 'Title Medium', style: Theme.of(context).textTheme.titleMedium),
                   const SizedBox(height: 24),
                   _TypographyRow(label: 'Body Large', style: Theme.of(context).textTheme.bodyLarge),
                   const SizedBox(height: 12),
                   _TypographyRow(label: 'Body Medium', style: Theme.of(context).textTheme.bodyMedium),
                   const SizedBox(height: 12),
                   _TypographyRow(label: 'Body Small', style: Theme.of(context).textTheme.bodySmall),
                 ],
               ),
             ),

             const SizedBox(height: 48),

             // Colors Section
             Text('Colors', style: Theme.of(context).textTheme.titleLarge?.copyWith(color: DesignTokens.obsidianTeal)),
             const SizedBox(height: 16),
             _SectionContainer(
               child: GridView.count(
                 shrinkWrap: true,
                 physics: const NeverScrollableScrollPhysics(),
                 crossAxisCount: 2,
                 mainAxisSpacing: 16,
                 crossAxisSpacing: 16,
                 childAspectRatio: 2.5,
                 children: const [
                    _ColorTile(name: 'Graphite Base', color: DesignTokens.graphiteBase, isDarkText: false),
                    _ColorTile(name: 'Graphite Surface', color: DesignTokens.graphiteSurface, isDarkText: false),
                    _ColorTile(name: 'Obsidian Teal', color: DesignTokens.obsidianTeal, isDarkText: true),
                    _ColorTile(name: 'Ash Gold', color: DesignTokens.ashGold, isDarkText: true),
                    _ColorTile(name: 'Crimson Warning', color: DesignTokens.crimsonWarning, isDarkText: false),
                    _ColorTile(name: 'High Contrast', color: DesignTokens.textHighContrast, isDarkText: true),
                    _ColorTile(name: 'Med Contrast', color: DesignTokens.textMediumContrast, isDarkText: true),
                 ],
               ),
             )
           ],
         ),
      ),
    );
  }
}

class _SectionContainer extends StatelessWidget {
  final Widget child;

  const _SectionContainer({required this.child});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: DesignTokens.graphiteSurface,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: Colors.white.withValues(alpha: 0.05)),
      ),
      child: child,
    );
  }
}

class _TypographyRow extends StatelessWidget {
  final String label;
  final TextStyle? style;

  const _TypographyRow({required this.label, required this.style});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: Theme.of(context).textTheme.bodySmall?.copyWith(color: DesignTokens.textMediumContrast, fontSize: 10)),
        const SizedBox(height: 4),
        Text('Viren Financial', style: style),
      ],
    );
  }
}

class _ColorTile extends StatelessWidget {
  final String name;
  final Color color;
  final bool isDarkText;

  const _ColorTile({required this.name, required this.color, required this.isDarkText});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.white.withValues(alpha: 0.1)),
      ),
      child: Align(
        alignment: Alignment.bottomLeft,
        child: Text(
          name,
          style: Theme.of(context).textTheme.bodySmall?.copyWith(
            color: isDarkText ? DesignTokens.graphiteBase : DesignTokens.textHighContrast,
            fontWeight: FontWeight.w600,
            fontSize: 10,
          ),
        ),
      ),
    );
  }
}
