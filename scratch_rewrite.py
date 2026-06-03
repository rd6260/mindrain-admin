import re

with open('lib/features/registrations/view/registrations_list_page.dart', 'r') as f:
    content = f.read()

# 1. Imports
content = content.replace("import 'package:supabase_flutter/supabase_flutter.dart';", "import 'package:flutter_bloc/flutter_bloc.dart';\nimport 'package:mindrain_admin/features/registrations/bloc/registrations_bloc.dart';")
content = content.replace("final _supabase = Supabase.instance.client;\n", "")

# 2. Page Class wrapper
page_class = """class RegistrationsPage extends StatelessWidget {
  const RegistrationsPage({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (context) => RegistrationsBloc()..add(FetchRegistrations()),
      child: const _RegistrationsPageView(),
    );
  }
}

class _RegistrationsPageView extends StatefulWidget {
  const _RegistrationsPageView();

  @override
  State<_RegistrationsPageView> createState() => _RegistrationsPageViewState();
}

class _RegistrationsPageViewState extends State<_RegistrationsPageView> {
  final _searchController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _searchController.addListener(() {
      context.read<RegistrationsBloc>().add(SearchQueryChanged(_searchController.text));
    });
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }
"""

# Regex to replace everything from class RegistrationsPage to the end of dispose()
content = re.sub(r'class RegistrationsPage extends StatefulWidget \{.*?\n  \}\n', page_class, content, flags=re.DOTALL)

# 3. Remove _fetchData, _applyFilters, _setSort
content = re.sub(r'  // ── Data ───────────────────────────────────────────────────────────────────\n.*?  // ── Helpers ────────────────────────────────────────────────────────────────', '  // ── Helpers ────────────────────────────────────────────────────────────────', content, flags=re.DOTALL)

# 4. _uniqueEvents
content = content.replace('  List<RegistrationEvent> get _uniqueEvents {\n    final seen = <String>{};\n    return _all\n        .where((r) => r.event != null && seen.add(r.event!.id))\n        .map((r) => r.event!)\n        .toList();\n  }', '  List<RegistrationEvent> _getUniqueEvents(List<Registration> all) {\n    final seen = <String>{};\n    return all\n        .where((r) => r.event != null && seen.add(r.event!.id))\n        .map((r) => r.event!)\n        .toList();\n  }')

# 5. _showEventPopup
content = content.replace('final total = _all.where((r) => r.eventId == event.id).length;', 'final all = context.read<RegistrationsBloc>().state.allRegistrations;\n    final total = all.where((r) => r.eventId == event.id).length;')
content = content.replace('final paid = _all.where((r) => r.eventId == event.id && r.paid).length;', 'final paid = all.where((r) => r.eventId == event.id && r.paid).length;')

# 6. Update build methods
content = content.replace('Widget build(BuildContext context) {', 'Widget build(BuildContext context) {\n    return BlocBuilder<RegistrationsBloc, RegistrationsState>(\n      builder: (context, state) {')
content = content.replace('      body: Column(\n        crossAxisAlignment: CrossAxisAlignment.start,\n        children: [\n          _buildHeader(),\n          _buildFilterBar(),\n          if (_error != null) _buildErrorBanner(),\n          Expanded(child: _buildBody()),\n        ],\n      ),\n    );', '        body: Column(\n          crossAxisAlignment: CrossAxisAlignment.start,\n          children: [\n            _buildHeader(state),\n            _buildFilterBar(state),\n            if (state.error != null) _buildErrorBanner(state),\n            Expanded(child: _buildBody(state)),\n          ],\n        ),\n      );\n    });')

content = content.replace('Widget _buildBody() {', 'Widget _buildBody(RegistrationsState state) {')
content = content.replace('if (_loading) {', 'if (state.status == RegistrationsStatus.loading || state.status == RegistrationsStatus.initial) {')
content = content.replace('if (_filtered.isEmpty) {', 'if (state.filteredRegistrations.isEmpty) {')
content = content.replace('return _buildTable();', 'return _buildTable(state);')

content = content.replace('Widget _buildErrorBanner() {', 'Widget _buildErrorBanner(RegistrationsState state) {')
content = content.replace('_error!', 'state.error!')
content = content.replace('onPressed: _fetchData,', 'onPressed: () => context.read<RegistrationsBloc>().add(FetchRegistrations()),')

content = content.replace('Widget _buildHeader() {', 'Widget _buildHeader(RegistrationsState state) {')
content = content.replace('_filtered.length', 'state.filteredRegistrations.length')
content = content.replace('_filtered.where', 'state.filteredRegistrations.where')
content = content.replace('if (!_loading) ...[', 'if (state.status != RegistrationsStatus.loading && state.status != RegistrationsStatus.initial) ...[')
content = content.replace('_loading\n                    ? \'Loading…\'', 'state.status == RegistrationsStatus.loading || state.status == RegistrationsStatus.initial\n                    ? \'Loading…\'')
content = content.replace('onTap: _fetchData,', 'onTap: () => context.read<RegistrationsBloc>().add(FetchRegistrations()),')

content = content.replace('Widget _buildFilterBar() {', 'Widget _buildFilterBar(RegistrationsState state) {')
content = content.replace('value: _eventFilter,', 'value: state.eventFilter,')
content = content.replace('..._uniqueEvents', '..._getUniqueEvents(state.allRegistrations)')
content = content.replace('setState(() => _eventFilter = v ?? \'\');\n              _applyFilters();', 'context.read<RegistrationsBloc>().add(EventFilterChanged(v ?? \'\'));')
content = content.replace('value: _groupFilter,', 'value: state.groupFilter,')
content = content.replace('setState(() => _groupFilter = v ?? \'\');\n              _applyFilters();', 'context.read<RegistrationsBloc>().add(GroupFilterChanged(v ?? \'\'));')
content = content.replace('value: _typeFilter,', 'value: state.typeFilter,')
content = content.replace('setState(() => _typeFilter = v ?? \'\');\n              _applyFilters();', 'context.read<RegistrationsBloc>().add(TypeFilterChanged(v ?? \'\'));')

content = content.replace('active: _paidFilter == \'\',', 'active: state.paidFilter == \'\',')
content = content.replace('setState(() => _paidFilter = \'\');\n              _applyFilters();', 'context.read<RegistrationsBloc>().add(PaidFilterChanged(\'\'));')
content = content.replace('active: _paidFilter == \'paid\',', 'active: state.paidFilter == \'paid\',')
content = content.replace('setState(() => _paidFilter = \'paid\');\n              _applyFilters();', 'context.read<RegistrationsBloc>().add(PaidFilterChanged(\'paid\'));')
content = content.replace('active: _paidFilter == \'unpaid\',', 'active: state.paidFilter == \'unpaid\',')
content = content.replace('setState(() => _paidFilter = \'unpaid\');\n              _applyFilters();', 'context.read<RegistrationsBloc>().add(PaidFilterChanged(\'unpaid\'));')

content = content.replace('Widget _buildTable() {', 'Widget _buildTable(RegistrationsState state) {')
content = content.replace('_col(\'Registered By\', \'name\'),', '_col(\'Registered By\', \'name\', state),')
content = content.replace('_col(\'Team ID\', \'team_id\', sortable: false),', '_col(\'Team ID\', \'team_id\', state, sortable: false),')
content = content.replace('_col(\'Group / Cat / Type\', \'group\', sortable: false),', '_col(\'Group / Cat / Type\', \'group\', state, sortable: false),')
content = content.replace('_col(\'Paid\', \'paid\'),', '_col(\'Paid\', \'paid\', state),')
content = content.replace('_col(\'Members\', \'members\', sortable: false),', '_col(\'Members\', \'members\', state, sortable: false),')
content = content.replace('_col(\'Created At\', \'created_at\'),', '_col(\'Created At\', \'created_at\', state),')
content = content.replace('rows: _filtered.map(_buildRow).toList(),', 'rows: state.filteredRegistrations.map(_buildRow).toList(),')

content = content.replace('DataColumn _col(\n    String label,\n    String key, {\n    bool numeric = false,\n    bool sortable = true,\n  }) {', 'DataColumn _col(\n    String label,\n    String key,\n    RegistrationsState state, {\n    bool numeric = false,\n    bool sortable = true,\n  }) {')
content = content.replace('onSort: sortable ? (_, _) => _setSort(key) : null,', 'onSort: sortable ? (_, _) => context.read<RegistrationsBloc>().add(SortChanged(key)) : null,')

with open('lib/features/registrations/view/registrations_list_page.dart', 'w') as f:
    f.write(content)
