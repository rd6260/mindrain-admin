import 'package:flutter/material.dart';

// ---------------------------------------------------------------------------
// Route identifiers – swap these with your actual named routes / page widgets
// ---------------------------------------------------------------------------
const String kRouteSendEmails = '/email/send';
const String kRouteCollectedEmails = '/email/collected';
const String kRouteUnpaidUsers = '/email/unpaid';

// ---------------------------------------------------------------------------
// Data model for each option card
// ---------------------------------------------------------------------------
class _EmailOption {
  const _EmailOption({
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.accentColor,
    required this.route,
    this.badge,
  });

  final String title;
  final String subtitle;
  final IconData icon;
  final Color accentColor;
  final String route;
  final String? badge; // optional pill label, e.g. "New"
}

const List<_EmailOption> _options = [
  _EmailOption(
    title: 'Send Emails to Users',
    subtitle: 'Compose and dispatch messages to your entire user base or a targeted segment.',
    icon: Icons.send_rounded,
    accentColor: Color(0xFF4F8EF7),
    route: kRouteSendEmails,
  ),
  _EmailOption(
    title: 'View Collected Emails',
    subtitle: 'Browse the brief digest of emails collected from users over time.',
    icon: Icons.inbox_rounded,
    accentColor: Color(0xFF34C78A),
    route: kRouteCollectedEmails,
    badge: 'New',
  ),
  _EmailOption(
    title: 'Unpaid Users Emails',
    subtitle: 'List email addresses of users with outstanding payments for follow-up.',
    icon: Icons.receipt_long_rounded,
    accentColor: Color(0xFFF5A623),
    route: kRouteUnpaidUsers,
  ),
];

// ---------------------------------------------------------------------------
// Main widget
// ---------------------------------------------------------------------------
class EmailManagementGate extends StatefulWidget {
  const EmailManagementGate({super.key});

  @override
  State<EmailManagementGate> createState() => _EmailManagementGateState();
}

class _EmailManagementGateState extends State<EmailManagementGate>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 600),
    )..forward();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;

    return Scaffold(
      backgroundColor: colors.surface,
      body: CustomScrollView(
        slivers: [
          // ── Header ─────────────────────────────────────────────────────
          SliverToBoxAdapter(
            child: _Header(animation: _controller),
          ),

          // ── Option Cards ────────────────────────────────────────────────
          SliverPadding(
            padding: const EdgeInsets.fromLTRB(32, 8, 32, 40),
            sliver: SliverList.separated(
              itemCount: _options.length,
              separatorBuilder: (_, _) => const SizedBox(height: 16),
              itemBuilder: (context, index) {
                final delay = index * 0.15;
                final slideAnimation = Tween<Offset>(
                  begin: const Offset(0.0, 0.25),
                  end: Offset.zero,
                ).animate(
                  CurvedAnimation(
                    parent: _controller,
                    curve: Interval(delay, (delay + 0.55).clamp(0.0, 1.0),
                        curve: Curves.easeOutCubic),
                  ),
                );
                final fadeAnimation = Tween<double>(begin: 0, end: 1).animate(
                  CurvedAnimation(
                    parent: _controller,
                    curve: Interval(delay, (delay + 0.45).clamp(0.0, 1.0),
                        curve: Curves.easeOut),
                  ),
                );

                return FadeTransition(
                  opacity: fadeAnimation,
                  child: SlideTransition(
                    position: slideAnimation,
                    child: _OptionCard(option: _options[index]),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Header section
// ---------------------------------------------------------------------------
class _Header extends StatelessWidget {
  const _Header({required this.animation});

  final Animation<double> animation;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;

    final fadeAnim = Tween<double>(begin: 0, end: 1).animate(
      CurvedAnimation(parent: animation, curve: const Interval(0, 0.5)),
    );
    final slideAnim = Tween<Offset>(
      begin: const Offset(0, -0.3),
      end: Offset.zero,
    ).animate(
      CurvedAnimation(parent: animation, curve: const Interval(0, 0.5, curve: Curves.easeOut)),
    );

    return FadeTransition(
      opacity: fadeAnim,
      child: SlideTransition(
        position: slideAnim,
        child: Container(
          width: double.infinity,
          padding: const EdgeInsets.fromLTRB(32, 40, 32, 32),
          decoration: BoxDecoration(
            border: Border(
              bottom: BorderSide(
                color: colors.outlineVariant.withValues(alpha: 0.5),
              ),
            ),
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  color: colors.primaryContainer,
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Icon(
                  Icons.mail_outline_rounded,
                  color: colors.onPrimaryContainer,
                  size: 26,
                ),
              ),
              const SizedBox(width: 20),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Email Management',
                    style: theme.textTheme.headlineSmall?.copyWith(
                      fontWeight: FontWeight.w700,
                      color: colors.onSurface,
                      letterSpacing: -0.5,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Select an action to manage your user communications.',
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: colors.onSurfaceVariant,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Individual option card
// ---------------------------------------------------------------------------
class _OptionCard extends StatefulWidget {
  const _OptionCard({required this.option});

  final _EmailOption option;

  @override
  State<_OptionCard> createState() => _OptionCardState();
}

class _OptionCardState extends State<_OptionCard> {
  bool _hovered = false;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    final opt = widget.option;

    return MouseRegion(
      cursor: SystemMouseCursors.click,
      onEnter: (_) => setState(() => _hovered = true),
      onExit: (_) => setState(() => _hovered = false),
      child: GestureDetector(
        onTap: () => Navigator.of(context).pushNamed(opt.route),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          curve: Curves.easeOut,
          decoration: BoxDecoration(
            color: _hovered ? colors.surfaceContainerHigh : colors.surfaceContainer,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: _hovered
                  ? opt.accentColor.withValues(alpha: 0.5)
                  : colors.outlineVariant.withValues(alpha: 0.35),
              width: 1.5,
            ),
            boxShadow: _hovered
                ? [
                    BoxShadow(
                      color: opt.accentColor.withValues(alpha: 0.08),
                      blurRadius: 20,
                      offset: const Offset(0, 4),
                    )
                  ]
                : [],
          ),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 22),
            child: Row(
              children: [
                // Icon bubble
                AnimatedContainer(
                  duration: const Duration(milliseconds: 180),
                  width: 52,
                  height: 52,
                  decoration: BoxDecoration(
                    color: opt.accentColor.withValues(alpha: _hovered ? 0.18 : 0.10),
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: Icon(opt.icon, color: opt.accentColor, size: 26),
                ),
                const SizedBox(width: 20),

                // Text
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Text(
                            opt.title,
                            style: theme.textTheme.titleMedium?.copyWith(
                              fontWeight: FontWeight.w600,
                              color: colors.onSurface,
                            ),
                          ),
                          if (opt.badge != null) ...[
                            const SizedBox(width: 10),
                            _Badge(label: opt.badge!, color: opt.accentColor),
                          ],
                        ],
                      ),
                      const SizedBox(height: 4),
                      Text(
                        opt.subtitle,
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: colors.onSurfaceVariant,
                          height: 1.5,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 16),

                // Arrow
                AnimatedSlide(
                  duration: const Duration(milliseconds: 180),
                  offset: _hovered ? const Offset(0.15, 0) : Offset.zero,
                  child: Icon(
                    Icons.arrow_forward_rounded,
                    color: _hovered ? opt.accentColor : colors.onSurfaceVariant,
                    size: 22,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Small badge pill
// ---------------------------------------------------------------------------
class _Badge extends StatelessWidget {
  const _Badge({required this.label, required this.color});

  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: color.withValues(alpha: 0.3)),
      ),
      child: Text(
        label,
        style: TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w600,
          color: color,
          letterSpacing: 0.2,
        ),
      ),
    );
  }
}
