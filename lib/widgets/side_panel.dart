import 'package:flutter/material.dart';
import 'package:mindrain_admin/pages/brief_collected_emails_page.dart';
import 'package:mindrain_admin/pages/send_emails_page.dart';
import 'package:mindrain_admin/pages/settings.dart';
import 'package:mindrain_admin/pages/signed_up_users_page.dart';

// ─── Navigation Model ─────────────────────────────────────────────────────────

class NavSubItem {
  final String label;
  final IconData icon;
  final Widget page;

  const NavSubItem({
    required this.label,
    required this.icon,
    required this.page,
  });
}

class NavItem {
  final String label;
  final IconData icon;
  final IconData activeIcon;
  final Widget page;
  final List<NavSubItem> children;

  const NavItem({
    required this.label,
    required this.icon,
    required this.activeIcon,
    required this.page,
    this.children = const [],
  });

  bool get hasChildren => children.isNotEmpty;
}

const List<NavItem> navItems = [
  NavItem(
    label: 'Home',
    icon: Icons.home_outlined,
    activeIcon: Icons.home_rounded,
    page: _PlaceholderPage(
      title: 'Home',
      icon: Icons.home_rounded,
      color: Color(0xFF6366F1),
    ),
  ),
  NavItem(
    label: 'Email Management',
    icon: Icons.mail_outline_rounded,
    activeIcon: Icons.mail_rounded,
    page: _PlaceholderPage(
      title: 'Email Management',
      icon: Icons.mail_rounded,
      color: Color(0xFF6366F1),
    ),
    children: [
      NavSubItem(
        label: 'Send Emails',
        icon: Icons.send_rounded,
        page: SendEmailsPage(),
      ),
      NavSubItem(
        label: 'Brief Collected Emails',
        icon: Icons.inbox_rounded,
        page: BriefCollectedEmailsPage(),
      ),
      NavSubItem(
        label: 'Signed Up Users',
        icon: Icons.receipt_long_rounded,
        page: SignedUpUsersPage(),
      ),
    ],
  ),
  NavItem(
    label: 'Profile',
    icon: Icons.person_outline_rounded,
    activeIcon: Icons.person_rounded,
    page: _PlaceholderPage(
      title: 'Profile',
      icon: Icons.person_rounded,
      color: Color(0xFF10B981),
    ),
  ),
  NavItem(
    label: 'Registrations',
    icon: Icons.app_registration_outlined,
    activeIcon: Icons.app_registration_rounded,
    page: _PlaceholderPage(
      title: 'Registrations',
      icon: Icons.app_registration_rounded,
      color: Color(0xFFF59E0B),
    ),
  ),
  NavItem(
    label: 'Events',
    icon: Icons.event_outlined,
    activeIcon: Icons.event_rounded,
    page: _PlaceholderPage(
      title: 'Events',
      icon: Icons.event_rounded,
      color: Color(0xFFEC4899),
    ),
  ),
  NavItem(
    label: 'Settings',
    icon: Icons.settings_outlined,
    activeIcon: Icons.settings_rounded,
    page: _PlaceholderPage(
      title: 'Settings',
      icon: Icons.settings_rounded,
      color: Colors.blue,
    ),
  ),
];

// ─── Selection State ──────────────────────────────────────────────────────────

/// Uniquely identifies what's selected: a top-level nav item, or a sub-item.
class NavSelection {
  final int itemIndex;
  final int? subIndex; // null = parent selected, non-null = child selected

  const NavSelection(this.itemIndex, [this.subIndex]);

  @override
  bool operator ==(Object other) =>
      other is NavSelection &&
      other.itemIndex == itemIndex &&
      other.subIndex == subIndex;

  @override
  int get hashCode => Object.hash(itemIndex, subIndex);
}

// ─── Main Layout ──────────────────────────────────────────────────────────────

class MainLayout extends StatefulWidget {
  const MainLayout({super.key});

  @override
  State<MainLayout> createState() => _MainLayoutState();
}

class _MainLayoutState extends State<MainLayout> {
  NavSelection _selection = const NavSelection(0);
  bool _isExpanded = true;

  // Which parent indices are expanded in the sidebar
  final Set<int> _expandedItems = {1}; // Email Management open by default

  static const double _expandedWidth = 240.0;
  static const double _collapsedWidth = 68.0;
  static const Duration _animDuration = Duration(milliseconds: 250);

  void _onItemTapped(int itemIndex) {
    final item = navItems[itemIndex];
    if (item.hasChildren) {
      setState(() {
        // Toggle expand/collapse; also select the parent
        if (_expandedItems.contains(itemIndex)) {
          _expandedItems.remove(itemIndex);
        } else {
          _expandedItems.add(itemIndex);
        }
        _selection = NavSelection(itemIndex);
      });
    } else {
      setState(() => _selection = NavSelection(itemIndex));
    }
  }

  void _onSubItemTapped(int itemIndex, int subIndex) {
    setState(() => _selection = NavSelection(itemIndex, subIndex));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF4F5F7),
      body: Row(
        children: [
          AnimatedContainer(
            duration: _animDuration,
            curve: Curves.easeInOutCubic,
            width: _isExpanded ? _expandedWidth : _collapsedWidth,
            child: SidePanel(
              selection: _selection,
              expandedItems: _expandedItems,
              isExpanded: _isExpanded,
              animDuration: _animDuration,
              onItemTapped: _onItemTapped,
              onSubItemTapped: _onSubItemTapped,
              onToggle: () => setState(() => _isExpanded = !_isExpanded),
            ),
          ),
          Expanded(child: ContentArea(selection: _selection)),
        ],
      ),
    );
  }
}

// ─── Side Panel ───────────────────────────────────────────────────────────────

class SidePanel extends StatelessWidget {
  final NavSelection selection;
  final Set<int> expandedItems;
  final bool isExpanded;
  final Duration animDuration;
  final ValueChanged<int> onItemTapped;
  final void Function(int, int) onSubItemTapped;
  final VoidCallback onToggle;

  const SidePanel({
    super.key,
    required this.selection,
    required this.expandedItems,
    required this.isExpanded,
    required this.animDuration,
    required this.onItemTapped,
    required this.onSubItemTapped,
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
        border: Border(right: BorderSide(color: _border, width: 1)),
      ),
      child: Column(
        children: [
          _buildHeader(),
          const SizedBox(height: 8),
          Expanded(
            child: ListView.builder(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              itemCount: navItems.length,
              itemBuilder: (_, i) {
                final item = navItems[i];
                final isParentActive =
                    selection.itemIndex == i && selection.subIndex == null;
                final isExpanded_ = expandedItems.contains(i);

                return Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    _NavTile(
                      item: item,
                      isSelected:
                          isParentActive ||
                          (selection.itemIndex == i &&
                              selection.subIndex != null),
                      isActiveParent: selection.itemIndex == i,
                      isExpanded: isExpanded,
                      isOpen: isExpanded_,
                      animDuration: animDuration,
                      onTap: () => onItemTapped(i),
                      accent: _accent,
                      accentGlow: _accentGlow,
                      textActive: _textActive,
                      textMuted: _textMuted,
                    ),

                    // Sub-items (only when sidebar is expanded)
                    if (item.hasChildren && isExpanded_)
                      _SubItemList(
                        parentIndex: i,
                        items: item.children,
                        selectedSubIndex: selection.itemIndex == i
                            ? selection.subIndex
                            : null,
                        sidebarExpanded: isExpanded,
                        animDuration: animDuration,
                        onTap: (si) => onSubItemTapped(i, si),
                        accent: _accent,
                        accentGlow: _accentGlow,
                        textActive: _textActive,
                        textMuted: _textMuted,
                      ),
                  ],
                );
              },
            ),
          ),
          Container(
            height: 1,
            color: _border,
            margin: const EdgeInsets.symmetric(horizontal: 10),
          ),
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
            child: const Icon(
              Icons.bolt_rounded,
              color: Colors.white,
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
  final bool isActiveParent;
  final bool isExpanded;
  final bool isOpen; // whether children are shown
  final Duration animDuration;
  final VoidCallback onTap;
  final Color accent;
  final Color accentGlow;
  final Color textActive;
  final Color textMuted;

  const _NavTile({
    required this.item,
    required this.isSelected,
    required this.isActiveParent,
    required this.isExpanded,
    required this.isOpen,
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
                    ? Border.all(
                        color: widget.accent.withValues(alpha: 0.35),
                        width: 1,
                      )
                    : Border.all(color: Colors.transparent, width: 1),
              ),
              child: Row(
                children: [
                  // Active bar
                  AnimatedContainer(
                    duration: widget.animDuration,
                    width: 3,
                    height: active ? 22 : 0,
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
                  Expanded(
                    child: ClipRect(
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
                  ),

                  // Chevron for items with children (only when sidebar expanded)
                  if (widget.item.hasChildren && widget.isExpanded)
                    Padding(
                      padding: const EdgeInsets.only(right: 10),
                      child: AnimatedRotation(
                        turns: widget.isOpen ? 0.25 : 0,
                        duration: widget.animDuration,
                        curve: Curves.easeInOutCubic,
                        child: Icon(
                          Icons.chevron_right_rounded,
                          size: 16,
                          color: active ? widget.accent : widget.textMuted,
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

// ─── Sub-item List ────────────────────────────────────────────────────────────

class _SubItemList extends StatelessWidget {
  final int parentIndex;
  final List<NavSubItem> items;
  final int? selectedSubIndex;
  final bool sidebarExpanded;
  final Duration animDuration;
  final ValueChanged<int> onTap;
  final Color accent;
  final Color accentGlow;
  final Color textActive;
  final Color textMuted;

  const _SubItemList({
    required this.parentIndex,
    required this.items,
    required this.selectedSubIndex,
    required this.sidebarExpanded,
    required this.animDuration,
    required this.onTap,
    required this.accent,
    required this.accentGlow,
    required this.textActive,
    required this.textMuted,
  });

  @override
  Widget build(BuildContext context) {
    // When sidebar is collapsed, hide sub-items (they show via tooltip on parent)
    if (!sidebarExpanded) return const SizedBox.shrink();

    return Padding(
      padding: const EdgeInsets.only(left: 16, bottom: 4),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          for (int i = 0; i < items.length; i++)
            _SubTile(
              item: items[i],
              isSelected: selectedSubIndex == i,
              animDuration: animDuration,
              onTap: () => onTap(i),
              accent: accent,
              accentGlow: accentGlow,
              textActive: textActive,
              textMuted: textMuted,
            ),
        ],
      ),
    );
  }
}

class _SubTile extends StatefulWidget {
  final NavSubItem item;
  final bool isSelected;
  final Duration animDuration;
  final VoidCallback onTap;
  final Color accent;
  final Color accentGlow;
  final Color textActive;
  final Color textMuted;

  const _SubTile({
    required this.item,
    required this.isSelected,
    required this.animDuration,
    required this.onTap,
    required this.accent,
    required this.accentGlow,
    required this.textActive,
    required this.textMuted,
  });

  @override
  State<_SubTile> createState() => _SubTileState();
}

class _SubTileState extends State<_SubTile> {
  bool _hovered = false;

  @override
  Widget build(BuildContext context) {
    final bool active = widget.isSelected;

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 1),
      child: MouseRegion(
        onEnter: (_) => setState(() => _hovered = true),
        onExit: (_) => setState(() => _hovered = false),
        child: GestureDetector(
          onTap: widget.onTap,
          child: AnimatedContainer(
            duration: widget.animDuration,
            curve: Curves.easeInOutCubic,
            height: 36,
            decoration: BoxDecoration(
              color: active
                  ? widget.accentGlow
                  : _hovered
                  ? const Color(0x0A6366F1)
                  : Colors.transparent,
              borderRadius: BorderRadius.circular(8),
            ),
            child: Row(
              children: [
                // Connector line
                SizedBox(
                  width: 20,
                  child: Center(
                    child: Container(
                      width: 1.5,
                      height: double.infinity,
                      color: widget.accent.withValues(
                        alpha: active ? 0.4 : 0.15,
                      ),
                    ),
                  ),
                ),

                // Dot
                Container(
                  width: 5,
                  height: 5,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: active
                        ? widget.accent
                        : widget.textMuted.withValues(alpha: 0.5),
                  ),
                ),

                const SizedBox(width: 10),

                // Icon
                Icon(
                  widget.item.icon,
                  size: 15,
                  color: active
                      ? widget.accent
                      : _hovered
                      ? widget.textActive
                      : widget.textMuted,
                ),

                const SizedBox(width: 8),

                // Label
                Expanded(
                  child: Text(
                    widget.item.label,
                    style: TextStyle(
                      color: active
                          ? widget.accent
                          : _hovered
                          ? widget.textActive
                          : widget.textMuted,
                      fontSize: 12.5,
                      fontWeight: active ? FontWeight.w600 : FontWeight.w400,
                      letterSpacing: 0.1,
                    ),
                    overflow: TextOverflow.ellipsis,
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

// ─── Content Area ─────────────────────────────────────────────────────────────

class ContentArea extends StatelessWidget {
  final NavSelection selection;

  const ContentArea({super.key, required this.selection});

  @override
  Widget build(BuildContext context) {
    return AnimatedSwitcher(
      duration: const Duration(milliseconds: 200),
      child: KeyedSubtree(key: ValueKey(selection), child: _resolve(selection)),
    );
  }

  Widget _resolve(NavSelection sel) {
    final item = navItems[sel.itemIndex];
    if (sel.subIndex != null) {
      return item.children[sel.subIndex!].page;
    }
    return item.page;
  }
}

// ─── Placeholder Page ─────────────────────────────────────────────────────────

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
                border: Border.all(
                  color: color.withValues(alpha: 0.3),
                  width: 1.5,
                ),
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
