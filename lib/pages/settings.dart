import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

class SettingsPage extends StatefulWidget {
  const SettingsPage({super.key});

  @override
  State<SettingsPage> createState() => _SettingsPageState();
}

class _SettingsPageState extends State<SettingsPage> {
  final _tokenCtrl = TextEditingController();
  bool _isSaving = false;
  bool _isLoading = true;
  String? _successMessage;

  // Theme constants matching email management
  static const _accent = Color(0xFF6366F1);
  static const _bg = Color(0xFFF4F5F7);
  static const _border = Color(0xFFE4E4EF);
  static const _textActive = Color(0xFF1A1A2E);
  static const _textMuted = Color(0xFF6B7280);

  @override
  void initState() {
    super.initState();
    _loadSettings();
  }

  @override
  void dispose() {
    _tokenCtrl.dispose();
    super.dispose();
  }

  Future<void> _loadSettings() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      _tokenCtrl.text = prefs.getString('postmark_token') ?? '';
      _isLoading = false;
    });
  }

  Future<void> _saveSettings() async {
    setState(() {
      _isSaving = true;
      _successMessage = null;
    });

    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('postmark_token', _tokenCtrl.text.trim());

    if (mounted) {
      setState(() {
        _isSaving = false;
        _successMessage = 'Settings saved successfully';
      });
      
      // Clear success message after a delay
      Future.delayed(const Duration(seconds: 3), () {
        if (mounted) {
          setState(() {
            _successMessage = null;
          });
        }
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      color: _bg,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildTopBar(),
          Expanded(
            child: _isLoading 
                ? const Center(child: CircularProgressIndicator(color: _accent))
                : SingleChildScrollView(
                    padding: const EdgeInsets.all(24),
                    child: Center(
                      child: ConstrainedBox(
                        constraints: const BoxConstraints(maxWidth: 800),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            if (_successMessage != null) _buildSuccessBanner(),
                            _buildSection(
                              'API Credentials',
                              Icons.key_rounded,
                              _buildPostmarkForm(),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
          ),
        ],
      ),
    );
  }

  Widget _buildTopBar() => Container(
    height: 60,
    decoration: const BoxDecoration(
      color: Colors.white,
      border: Border(bottom: BorderSide(color: _border)),
    ),
    padding: const EdgeInsets.symmetric(horizontal: 24),
    child: const Row(
      children: [
        Icon(Icons.settings_rounded, color: _accent, size: 22),
        SizedBox(width: 12),
        Text(
          'Settings',
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.w700,
            color: _textActive,
          ),
        ),
      ],
    ),
  );

  Widget _buildSuccessBanner() => Container(
    margin: const EdgeInsets.only(bottom: 16),
    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
    decoration: BoxDecoration(
      color: Colors.green.shade50,
      borderRadius: BorderRadius.circular(8),
      border: Border.all(color: Colors.green.shade200),
    ),
    child: Row(
      children: [
        Icon(Icons.check_circle_rounded, color: Colors.green.shade600, size: 20),
        const SizedBox(width: 12),
        Text(
          _successMessage!,
          style: TextStyle(
            color: Colors.green.shade800,
            fontWeight: FontWeight.w500,
            fontSize: 14,
          ),
        ),
      ],
    ),
  );

  Widget _buildSection(String title, IconData icon, Widget content) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(icon, size: 16, color: _accent),
            const SizedBox(width: 8),
            Text(
              title,
              style: const TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: _textActive,
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(24),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: _border),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.02),
                blurRadius: 8,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: content,
        ),
      ],
    );
  }

  Widget _buildPostmarkForm() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Postmark Configuration',
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w600,
            color: _textActive,
          ),
        ),
        const SizedBox(height: 6),
        const Text(
          'Enter your Postmark Server API Token to enable email sending capabilities.',
          style: TextStyle(
            fontSize: 13,
            color: _textMuted,
          ),
        ),
        const SizedBox(height: 20),
        const Text(
          'Server API Token',
          style: TextStyle(
            fontWeight: FontWeight.w600,
            fontSize: 12,
            color: _textMuted,
            letterSpacing: 0.5,
          ),
        ),
        const SizedBox(height: 8),
        TextField(
          controller: _tokenCtrl,
          obscureText: true,
          style: const TextStyle(fontSize: 14, fontFamily: 'monospace'),
          decoration: InputDecoration(
            hintText: 'e.g. 1234abcd-5678-efgh-9012-ijklmnop3456',
            hintStyle: TextStyle(color: Colors.black.withValues(alpha: 0.2)),
            filled: true,
            fillColor: const Color(0xFFFAFAFC),
            contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8),
              borderSide: const BorderSide(color: _border),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8),
              borderSide: const BorderSide(color: _border),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8),
              borderSide: const BorderSide(color: _accent),
            ),
            prefixIcon: const Icon(Icons.password_rounded, color: _textMuted, size: 20),
          ),
        ),
        const SizedBox(height: 24),
        Align(
          alignment: Alignment.centerRight,
          child: ElevatedButton.icon(
            onPressed: _isSaving ? null : _saveSettings,
            icon: _isSaving 
                ? const SizedBox(
                    width: 16, height: 16, 
                    child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white)
                  )
                : const Icon(Icons.save_rounded, size: 18),
            label: Text(_isSaving ? 'Saving...' : 'Save Changes'),
            style: ElevatedButton.styleFrom(
              backgroundColor: _accent,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
              elevation: 0,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
              ),
            ),
          ),
        ),
      ],
    );
  }
}
