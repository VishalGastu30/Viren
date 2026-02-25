import 'package:flutter/material.dart';
import '../../core/theme/design_tokens.dart';


class ImportCenterScreen extends StatefulWidget {
  const ImportCenterScreen({super.key});

  @override
  State<ImportCenterScreen> createState() => _ImportCenterScreenState();
}

class _ImportCenterScreenState extends State<ImportCenterScreen> with SingleTickerProviderStateMixin {
  bool _isScanning = false;
  late AnimationController _pulseController;
  late Animation<double> _pulseAnimation;

  @override
  void initState() {
    super.initState();
    _pulseController = AnimationController(
       vsync: this,
       duration: const Duration(milliseconds: 1500),
    );
    _pulseAnimation = Tween<double>(begin: 1.0, end: 1.2).animate(
      CurvedAnimation(parent: _pulseController, curve: Curves.easeInOutSine),
    );
  }

  @override
  void dispose() {
    _pulseController.dispose();
    super.dispose();
  }

  void _simulateScan() {
    setState(() {
      _isScanning = true;
    });
    _pulseController.repeat(reverse: true);

    Future.delayed(const Duration(seconds: 3), () {
      if (mounted) {
         setState(() {
           _isScanning = false;
         });
         _pulseController.stop();
         _pulseController.reset();
         _showSuccessSnack();
      }
    });
  }

  void _showSuccessSnack() {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            const Icon(Icons.check_circle_rounded, color: DesignTokens.obsidianTeal),
            const SizedBox(width: 12),
            Text('Successfully parsed 3 contracts.', style: Theme.of(context).textTheme.bodyMedium?.copyWith(color: DesignTokens.obsidianTeal)),
          ],
        ),
        backgroundColor: DesignTokens.graphiteSurface,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        margin: const EdgeInsets.all(24),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: DesignTokens.graphiteBase,
      appBar: AppBar(
        title: Text('Import Center', style: Theme.of(context).textTheme.titleLarge),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded),
          onPressed: () => Navigator.of(context).pop(),
        ),
      ),
      body: SingleChildScrollView(
        physics: const BouncingScrollPhysics(),
        padding: const EdgeInsets.all(24.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Add to Vault',
              style: Theme.of(context).textTheme.displayLarge,
            ),
            const SizedBox(height: 12),
            Text(
              'Viren operates locally. Any files dropped here are parsed purely on-device and never leave your phone.',
              style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                color: DesignTokens.textMediumContrast,
                height: 1.5,
              ),
            ),
            const SizedBox(height: 48),

            // Import Action Cards
            _ImportActionCard(
              icon: Icons.upload_file_rounded,
              title: 'Upload Statement',
              description: 'Drop a CSV or PDF from your broker.',
              onTap: _isScanning ? () {} : _simulateScan,
              isScanning: _isScanning,
              pulseAnimation: _pulseAnimation,
            ),
            const SizedBox(height: 16),
            _ImportActionCard(
              icon: Icons.mail_outline_rounded,
              title: 'Connect Email',
              description: 'Auto-scan for contract notes.',
              onTap: () {},
            ),
            const SizedBox(height: 16),
            _ImportActionCard(
              icon: Icons.edit_rounded,
              title: 'Manual Entry',
              description: 'Record a single trade with your thesis.',
              onTap: () {},
            ),

            const SizedBox(height: 48),
            Text(
               'Recent Parses',
               style: Theme.of(context).textTheme.titleLarge,
            ),
            const SizedBox(height: 24),
            
            // Mock recent parses listing
            _ParseHistoryItem(
               broker: 'Zerodha',
               date: '10 Feb 2024',
               status: 'Success',
               recordsFound: 14,
               confidence: 0.99,
               iconColor: DesignTokens.obsidianTeal, // Blue-ish mock for zerodha
            ),
            const SizedBox(height: 16),
            _ParseHistoryItem(
               broker: 'Groww',
               date: '15 Jan 2024',
               status: 'Success',
               recordsFound: 3,
               confidence: 0.95,
               iconColor: DesignTokens.ashGold, 
            ),
             const SizedBox(height: 16),
            _ParseHistoryItem(
               broker: 'Unknown Format',
               date: '02 Jan 2024',
               status: 'Failed',
               recordsFound: 0,
               confidence: 0.10,
               iconColor: DesignTokens.crimsonWarning, 
            ),
            
          ],
        ),
      )
    );
  }
}

class _ParseHistoryItem extends StatelessWidget {
  final String broker;
  final String date;
  final String status;
  final int recordsFound;
  final double confidence; // 0.0 to 1.0
  final Color iconColor;

  const _ParseHistoryItem({
    required this.broker,
    required this.date,
    required this.status,
    required this.recordsFound,
    required this.confidence,
    required this.iconColor,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: DesignTokens.graphiteSurface,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: Colors.white.withValues(alpha: 0.03)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
             width: 40,
             height: 40,
             decoration: BoxDecoration(
               color: iconColor.withValues(alpha: 0.1),
               borderRadius: BorderRadius.circular(12),
             ),
             child: Center(
               child: Icon(
                 status == 'Success' ? Icons.check_circle_outline_rounded : Icons.error_outline_rounded,
                 color: iconColor,
               ),
             ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                 Row(
                   mainAxisAlignment: MainAxisAlignment.spaceBetween,
                   children: [
                      Text(broker, style: Theme.of(context).textTheme.titleMedium),
                      Text(date, style: Theme.of(context).textTheme.bodySmall?.copyWith(color: DesignTokens.textMediumContrast)),
                   ],
                 ),
                 const SizedBox(height: 8),
                 Row(
                   children: [
                     Text('$recordsFound records', style: Theme.of(context).textTheme.bodyMedium),
                     const Spacer(),
                     _ConfidenceBadge(confidence: confidence),
                   ],
                 )
              ],
            ),
          )
        ],
      ),
    );
  }
}

class _ConfidenceBadge extends StatelessWidget {
  final double confidence;

  const _ConfidenceBadge({required this.confidence});

  @override
  Widget build(BuildContext context) {
    Color color = DesignTokens.obsidianTeal;
    if (confidence < 0.8) color = DesignTokens.ashGold;
    if (confidence < 0.5) color = DesignTokens.crimsonWarning;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
         color: color.withValues(alpha: 0.1),
         borderRadius: BorderRadius.circular(8),
         border: Border.all(color: color.withValues(alpha: 0.3)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
           Icon(Icons.auto_awesome_rounded, size: 12, color: color),
           const SizedBox(width: 4),
           Text(
             '${(confidence * 100).toInt()}% Match',
             style: Theme.of(context).textTheme.bodySmall?.copyWith(fontSize: 10, color: color, fontWeight: FontWeight.w600),
           )
        ],
      ),
    );
  }
}

class _ImportActionCard extends StatelessWidget {
  final IconData icon;
  final String title;
  final String description;
  final VoidCallback onTap;
  final bool isScanning;
  final Animation<double>? pulseAnimation;

  const _ImportActionCard({
    required this.icon,
    required this.title,
    required this.description,
    required this.onTap,
    this.isScanning = false,
    this.pulseAnimation,
  });

  @override
  Widget build(BuildContext context) {
    Widget content = Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: DesignTokens.graphiteSurface,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(
          color: isScanning 
            ? DesignTokens.obsidianTeal.withValues(alpha: 0.5) 
            : Colors.white.withValues(alpha: 0.05),
          width: isScanning ? 2.0 : 1.0,
        ),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: isScanning ? DesignTokens.obsidianTeal.withValues(alpha: 0.1) : DesignTokens.graphiteBase,
              borderRadius: BorderRadius.circular(16),
            ),
            child: Icon(
              icon,
              color: isScanning ? DesignTokens.obsidianTeal : DesignTokens.textMediumContrast,
              size: 28,
            ),
          ),
          const SizedBox(width: 20),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  isScanning ? 'Scanning...' : title,
                  style: Theme.of(context).textTheme.titleLarge?.copyWith(fontSize: 18),
                ),
                const SizedBox(height: 4),
                Text(
                  description,
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: DesignTokens.textMediumContrast,
                    height: 1.4,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 16),
          const Icon(Icons.chevron_right_rounded, color: DesignTokens.textMediumContrast),
        ],
      ),
    );

    if (pulseAnimation != null && isScanning) {
      return AnimatedBuilder(
        animation: pulseAnimation!,
        builder: (context, child) {
          return Container(
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(24),
              boxShadow: [
                BoxShadow(
                  color: DesignTokens.obsidianTeal.withValues(alpha: 0.1),
                  blurRadius: 20 * pulseAnimation!.value,
                  spreadRadius: 10 * pulseAnimation!.value,
                )
              ],
            ),
            child: Transform.scale(
              scale: 1.0 + (0.02 * pulseAnimation!.value),
              child: content,
            ),
          );
        },
      );
    }

    return GestureDetector(
      onTap: onTap,
      child: content,
    );
  }
}

