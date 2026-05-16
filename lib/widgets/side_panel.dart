import 'package:flutter/material.dart';
import 'package:mindrain_admin/pages/email_management.dart';
import 'package:mindrain_admin/pages/settings.dart';

// ─── Navigation Items ────────────────────────────────────────────────────────
class NavItem {
  final String label;
  final IconData icon;
  final IconData activeIcon;

  const NavItem({
    required this.label,
    required this.icon,
    required this.activeIcon,
  });
}

const List<NavItem> navItems = [
  NavItem(
    label: 'Home',
    icon: Icons.home_outlined,
    activeIcon: Icons.home_rounded,
  ),
  NavItem(
    label: 'Email Management',
    icon: Icons.mail_outline_rounded,
    activeIcon: Icons.mail_rounded,
  ),
  NavItem(
    label: 'Profile',
    icon: Icons.person_outline_rounded,
    activeIcon: Icons.person_rounded,
  ),
  NavItem(
    label: 'Registrations',
    icon: Icons.app_registration_outlined,
    activeIcon: Icons.app_registration_rounded,
  ),
  NavItem(
    label: 'Events',
    icon: Icons.event_outlined,
    activeIcon: Icons.event_rounded,
  ),
  NavItem(
    label: 'Settings',
    icon: Icons.settings_outlined,
    activeIcon: Icons.settings_rounded,
  ),
];

// ─── Main Layout ─────────────────────────────────────────────────────────────

class MainLayout extends StatefulWidget {
  const MainLayout({super.key});

  @override
  State<MainLayout> createState() => _MainLayoutState();
}

class _MainLayoutState extends State<MainLayout> {
  int _selectedIndex = 0;
  bool _isExpanded = true;

  static const double _expandedWidth = 240.0;
  static const double _collapsedWidth = 68.0;
  static const Duration _animDuration = Duration(milliseconds: 250);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF4F5F7),
      body: Row(
        children: [
          // ── Side Panel ──────────────────────────────────────────────────
          AnimatedContainer(
            duration: _animDuration,
            curve: Curves.easeInOutCubic,
            width: _isExpanded ? _expandedWidth : _collapsedWidth,
            child: SidePanel(
              selectedIndex: _selectedIndex,
              isExpanded: _isExpanded,
              animDuration: _animDuration,
              onItemSelected: (i) => setState(() => _selectedIndex = i),
              onToggle: () => setState(() => _isExpanded = !_isExpanded),
            ),
          ),

          // ── Main Content ────────────────────────────────────────────────
          Expanded(
            child: ContentArea(selectedIndex: _selectedIndex),
          ),
        ],
      ),
    );
  }
}

// ─── Side Panel ───────────────────────────────────────────────────────────────

class SidePanel extends StatelessWidget {
  final int selectedIndex;
  final bool isExpanded;
  final Duration animDuration;
  final ValueChanged<int> onItemSelected;
  final VoidCallback onToggle;

  const SidePanel({
    super.key,
    required this.selectedIndex,
    required this.isExpanded,
    required this.animDuration,
    required this.onItemSelected,
    required this.onToggle,
  });

  static const _bg = Color(0xFFFFFFFF);
  static const _border = Color(0xFFE4E4EF);
  static const _accent = Color(0xFF6366F1);
  static const _accentGlow = Color(0x1A6366F1);
  static const _textActive = Color(0xFF1A1A2E);
  static const _textMuted = Color(0xFF9494A8);

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        color: _bg,
        border: Border(
          right: BorderSide(color: _border, width: 1),
        ),
      ),
      child: Column(
        children: [
          // ── Logo / Brand ──────────────────────────────────────────────
          _buildHeader(),

          const SizedBox(height: 8),

          // ── Nav Items ─────────────────────────────────────────────────
          Expanded(
            child: ListView.builder(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              itemCount: navItems.length,
              itemBuilder: (_, i) => _NavTile(
                item: navItems[i],
                isSelected: selectedIndex == i,
                isExpanded: isExpanded,
                animDuration: animDuration,
                onTap: () => onItemSelected(i),
                accent: _accent,
                accentGlow: _accentGlow,
                textActive: _textActive,
                textMuted: _textMuted,
              ),
            ),
          ),

          // ── Divider ───────────────────────────────────────────────────
          Container(height: 1, color: _border, margin: const EdgeInsets.symmetric(horizontal: 10)),

          // ── Toggle Button ─────────────────────────────────────────────
          _buildToggle(),
        ],
      ),
    );
  }

  Widget _buildHeader() {
    return Container(
      height: 64,
      padding: const EdgeInsets.symmetric(horizontal: 14),
      decoration: const BoxDecoration(
        border: Border(bottom: BorderSide(color: _border, width: 1)),
      ),
      child: Row(
        children: [
          // App icon
          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [Color(0xFF818CF8), Color(0xFF6366F1)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(10),
              boxShadow: const [
                BoxShadow(color: _accentGlow, blurRadius: 12, spreadRadius: 2),
              ],
            ),
            child: const Icon(Icons.bolt_rounded, color: Colors.white, size: 20),
          ),

          // App name (fades + slides when collapsed)
          ClipRect(
            child: AnimatedAlign(
              duration: animDuration,
              curve: Curves.easeInOutCubic,
              alignment: Alignment.centerLeft,
              widthFactor: isExpanded ? 1.0 : 0.0,
              child: Padding(
                padding: const EdgeInsets.only(left: 12),
                child: AnimatedOpacity(
                  duration: animDuration,
                  opacity: isExpanded ? 1.0 : 0.0,
                  child: const Text(
                    'Mind Rain',
                    style: TextStyle(
                      color: _textActive,
                      fontSize: 17,
                      fontWeight: FontWeight.w700,
                      letterSpacing: 0.3,
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildToggle() {
    return Tooltip(
      message: isExpanded ? 'Collapse sidebar' : 'Expand sidebar',
      preferBelow: false,
      child: InkWell(
        onTap: onToggle,
        borderRadius: BorderRadius.circular(8),
        child: Container(
          height: 52,
          padding: const EdgeInsets.symmetric(horizontal: 14),
          child: Row(
            children: [
              AnimatedRotation(
                turns: isExpanded ? 0 : 0.5,
                duration: animDuration,
                curve: Curves.easeInOutCubic,
                child: const Icon(
                  Icons.keyboard_double_arrow_left_rounded,
                  color: _textMuted,
                  size: 20,
                ),
              ),
              ClipRect(
                child: AnimatedAlign(
                  duration: animDuration,
                  curve: Curves.easeInOutCubic,
                  alignment: Alignment.centerLeft,
                  widthFactor: isExpanded ? 1.0 : 0.0,
                  child: Padding(
                    padding: const EdgeInsets.only(left: 12),
                    child: AnimatedOpacity(
                      duration: animDuration,
                      opacity: isExpanded ? 1.0 : 0.0,
                      child: const Text(
                        'Collapse',
                        style: TextStyle(
                          color: _textMuted,
                          fontSize: 13,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ─── Nav Tile ─────────────────────────────────────────────────────────────────

class _NavTile extends StatefulWidget {
  final NavItem item;
  final bool isSelected;
  final bool isExpanded;
  final Duration animDuration;
  final VoidCallback onTap;
  final Color accent;
  final Color accentGlow;
  final Color textActive;
  final Color textMuted;

  const _NavTile({
    required this.item,
    required this.isSelected,
    required this.isExpanded,
    required this.animDuration,
    required this.onTap,
    required this.accent,
    required this.accentGlow,
    required this.textActive,
    required this.textMuted,
  });

  @override
  State<_NavTile> createState() => _NavTileState();
}

class _NavTileState extends State<_NavTile> {
  bool _hovered = false;

  @override
  Widget build(BuildContext context) {
    final bool active = widget.isSelected;

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Tooltip(
        message: widget.isExpanded ? '' : widget.item.label,
        preferBelow: false,
        child: MouseRegion(
          onEnter: (_) => setState(() => _hovered = true),
          onExit: (_) => setState(() => _hovered = false),
          child: GestureDetector(
            onTap: widget.onTap,
            child: AnimatedContainer(
              duration: widget.animDuration,
              curve: Curves.easeInOutCubic,
              height: 44,
              decoration: BoxDecoration(
                color: active
                    ? widget.accentGlow
                    : _hovered
                        ? const Color(0x0F6366F1)
                        : Colors.transparent,
                borderRadius: BorderRadius.circular(10),
                border: active
                    ? Border.all(color: widget.accent.withValues(alpha: 0.35), width: 1)
                    : Border.all(color: Colors.transparent, width: 1),
              ),
              child: Row(
                children: [
                  // Active indicator bar
                  AnimatedContainer(
                    duration: widget.animDuration,
                    width: 3,
                    height: active ? 22 : 0,
                    margin: const EdgeInsets.only(left: 0),
                    decoration: BoxDecoration(
                      color: widget.accent,
                      borderRadius: const BorderRadius.horizontal(
                        right: Radius.circular(4),
                      ),
                      boxShadow: active
                          ? [BoxShadow(color: widget.accentGlow, blurRadius: 8)]
                          : null,
                    ),
                  ),

                  const SizedBox(width: 11),

                  // Icon
                  Icon(
                    active ? widget.item.activeIcon : widget.item.icon,
                    size: 20,
                    color: active
                        ? widget.accent
                        : _hovered
                            ? widget.textActive
                            : widget.textMuted,
                  ),

                  // Label
                  ClipRect(
                    child: AnimatedAlign(
                      duration: widget.animDuration,
                      curve: Curves.easeInOutCubic,
                      alignment: Alignment.centerLeft,
                      widthFactor: widget.isExpanded ? 1.0 : 0.0,
                      child: Padding(
                        padding: const EdgeInsets.only(left: 12),
                        child: AnimatedOpacity(
                          duration: widget.animDuration,
                          opacity: widget.isExpanded ? 1.0 : 0.0,
                          child: Text(
                            widget.item.label,
                            style: TextStyle(
                              color: active
                                  ? widget.textActive
                                  : _hovered
                                      ? widget.textActive
                                      : widget.textMuted,
                              fontSize: 13.5,
                              fontWeight: active
                                  ? FontWeight.w600
                                  : FontWeight.w400,
                              letterSpacing: 0.1,
                            ),
                            overflow: TextOverflow.ellipsis,
                            maxLines: 1,
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

// ─── Content Area ─────────────────────────────────────────────────────────────

class ContentArea extends StatelessWidget {
  final int selectedIndex;

  const ContentArea({super.key, required this.selectedIndex});

  static final _pages = [
    const _PlaceholderPage(title: 'Home', icon: Icons.home_rounded, color: Color(0xFF6366F1)),
    const EmailManagementPage(),
    const _PlaceholderPage(title: 'Profile', icon: Icons.person_rounded, color: Color(0xFF10B981)),
    const _PlaceholderPage(title: 'Registrations', icon: Icons.app_registration_rounded, color: Color(0xFFF59E0B)),
    const _PlaceholderPage(title: 'Events', icon: Icons.event_rounded, color: Color(0xFFEC4899)),
    const SettingsPage(),
  ];

  @override
  Widget build(BuildContext context) {
    return AnimatedSwitcher(
      duration: const Duration(milliseconds: 200),
      child: _pages[selectedIndex],
    );
  }
}

class _PlaceholderPage extends StatelessWidget {
  final String title;
  final IconData icon;
  final Color color;

  const _PlaceholderPage({
    required this.title,
    required this.icon,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      key: ValueKey(title),
      color: const Color(0xFFF4F5F7),
      child: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 72,
              height: 72,
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: color.withValues(alpha: 0.3), width: 1.5),
              ),
              child: Icon(icon, color: color, size: 32),
            ),
            const SizedBox(height: 20),
            Text(
              title,
              style: TextStyle(
                color: Colors.black.withValues(alpha: 0.80),
                fontSize: 22,
                fontWeight: FontWeight.w600,
                letterSpacing: 0.2,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Your $title content goes here',
              style: TextStyle(
                color: Colors.black.withValues(alpha: 0.35),
                fontSize: 14,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
