import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

class SettingsPage extends StatefulWidget {
  const SettingsPage({Key? key}) : super(key: key);

  @override
  State<SettingsPage> createState() => _SettingsPageState();
}

class _SettingsPageState extends State<SettingsPage> {
  // Business Settings
  final _businessNameController = TextEditingController();
  final _phoneController = TextEditingController();
  final _emailController = TextEditingController();
  String _selectedCurrency = 'GHS';
  String _selectedLanguage = 'English';

  // App Settings
  bool _isDarkMode = false;
  bool _notifications = true;
  bool _autoBackup = false;
  bool _biometricAuth = false;

  // UI State
  bool _isLoading = true;
  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    _loadSettings();
  }

  @override
  void dispose() {
    _businessNameController.dispose();
    _phoneController.dispose();
    _emailController.dispose();
    super.dispose();
  }

  Future<void> _loadSettings() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      _businessNameController.text = prefs.getString('business_name') ?? '';
      _phoneController.text = prefs.getString('business_phone') ?? '';
      _emailController.text = prefs.getString('business_email') ?? '';
      _selectedCurrency = prefs.getString('currency') ?? 'GHS';
      _selectedLanguage = prefs.getString('language') ?? 'English';
      _isDarkMode = prefs.getBool('dark_mode') ?? false;
      _notifications = prefs.getBool('notifications') ?? true;
      _autoBackup = prefs.getBool('auto_backup') ?? false;
      _biometricAuth = prefs.getBool('biometric_auth') ?? false;
      _isLoading = false;
    });
  }

  Future<void> _saveSettings() async {
    setState(() => _isSaving = true);

    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('business_name', _businessNameController.text);
    await prefs.setString('business_phone', _phoneController.text);
    await prefs.setString('business_email', _emailController.text);
    await prefs.setString('currency', _selectedCurrency);
    await prefs.setString('language', _selectedLanguage);
    await prefs.setBool('dark_mode', _isDarkMode);
    await prefs.setBool('notifications', _notifications);
    await prefs.setBool('auto_backup', _autoBackup);
    await prefs.setBool('biometric_auth', _biometricAuth);

    setState(() => _isSaving = false);

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Settings saved successfully'),
        backgroundColor: Colors.green,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }

    return Scaffold(
      backgroundColor: Colors.grey[50],
      appBar: AppBar(
        title: const Text(
          'Settings',
          style: TextStyle(fontWeight: FontWeight.w600),
        ),
        backgroundColor: Colors.white,
        foregroundColor: Colors.black87,
        elevation: 0.5,
        actions: [
          TextButton.icon(
            onPressed: _isSaving ? null : _saveSettings,
            icon: _isSaving
                ? const SizedBox(
              width: 16,
              height: 16,
              child: CircularProgressIndicator(strokeWidth: 2),
            )
                : const Icon(Icons.save, size: 18),
            label: const Text('Save'),
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildSection(
              'Business Information',
              Icons.business,
              [
                _buildTextField(
                  controller: _businessNameController,
                  label: 'Business Name',
                  icon: Icons.store,
                ),
                const SizedBox(height: 16),
                _buildTextField(
                  controller: _phoneController,
                  label: 'Phone Number',
                  icon: Icons.phone,
                  keyboardType: TextInputType.phone,
                ),
                const SizedBox(height: 16),
                _buildTextField(
                  controller: _emailController,
                  label: 'Email Address',
                  icon: Icons.email,
                  keyboardType: TextInputType.emailAddress,
                ),
              ],
            ),

            const SizedBox(height: 24),

            _buildSection(
              'Localization',
              Icons.language,
              [
                _buildDropdown(
                  label: 'Currency',
                  value: _selectedCurrency,
                  items: const [
                    DropdownMenuItem(value: 'GHS', child: Text('Ghanaian Cedi (₵)')),
                    DropdownMenuItem(value: 'USD', child: Text('US Dollar (\$)')),
                    DropdownMenuItem(value: 'EUR', child: Text('Euro (€)')),
                    DropdownMenuItem(value: 'GBP', child: Text('British Pound (£)')),
                  ],
                  onChanged: (value) => setState(() => _selectedCurrency = value!),
                ),
                const SizedBox(height: 16),
                _buildDropdown(
                  label: 'Language',
                  value: _selectedLanguage,
                  items: const [
                    DropdownMenuItem(value: 'English', child: Text('English')),
                    DropdownMenuItem(value: 'French', child: Text('Français')),
                    DropdownMenuItem(value: 'Spanish', child: Text('Español')),
                  ],
                  onChanged: (value) => setState(() => _selectedLanguage = value!),
                ),
              ],
            ),

            const SizedBox(height: 24),

            _buildSection(
              'App Preferences',
              Icons.settings,
              [
                _buildSwitchTile(
                  title: 'Dark Mode',
                  subtitle: 'Use dark theme',
                  value: _isDarkMode,
                  onChanged: (value) => setState(() => _isDarkMode = value),
                  icon: Icons.dark_mode,
                ),
                _buildSwitchTile(
                  title: 'Notifications',
                  subtitle: 'Receive app notifications',
                  value: _notifications,
                  onChanged: (value) => setState(() => _notifications = value),
                  icon: Icons.notifications,
                ),
                _buildSwitchTile(
                  title: 'Auto Backup',
                  subtitle: 'Automatically backup data',
                  value: _autoBackup,
                  onChanged: (value) => setState(() => _autoBackup = value),
                  icon: Icons.backup,
                ),
                _buildSwitchTile(
                  title: 'Biometric Login',
                  subtitle: 'Use fingerprint/face unlock',
                  value: _biometricAuth,
                  onChanged: (value) => setState(() => _biometricAuth = value),
                  icon: Icons.fingerprint,
                ),
              ],
            ),

            const SizedBox(height: 24),

            _buildSection(
              'Account & Data',
              Icons.account_circle,
              [
                _buildActionTile(
                  title: 'Export Data',
                  subtitle: 'Download your data',
                  icon: Icons.download,
                  onTap: () => _showSnackBar('Export feature coming soon'),
                ),
                _buildActionTile(
                  title: 'Import Data',
                  subtitle: 'Upload data from file',
                  icon: Icons.upload,
                  onTap: () => _showSnackBar('Import feature coming soon'),
                ),
                _buildActionTile(
                  title: 'Reset Settings',
                  subtitle: 'Restore default settings',
                  icon: Icons.restore,
                  onTap: _showResetDialog,
                  textColor: Colors.orange,
                ),
              ],
            ),

            const SizedBox(height: 24),

            _buildSection(
              'Support',
              Icons.help,
              [
                _buildActionTile(
                  title: 'Help & Support',
                  subtitle: 'Get help and contact us',
                  icon: Icons.help_outline,
                  onTap: () => _showSnackBar('Help feature coming soon'),
                ),
                _buildActionTile(
                  title: 'Privacy Policy',
                  subtitle: 'Read our privacy policy',
                  icon: Icons.privacy_tip,
                  onTap: () => _showSnackBar('Privacy policy coming soon'),
                ),
                _buildActionTile(
                  title: 'About',
                  subtitle: 'App version 1.0.0',
                  icon: Icons.info_outline,
                  onTap: () => _showAboutDialog(),
                ),
              ],
            ),

            const SizedBox(height: 32),
          ],
        ),
      ),
    );
  }

  Widget _buildSection(String title, IconData icon, List<Widget> children) {
    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey[200]!),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                Icon(icon, color: Colors.blue[600], size: 20),
                const SizedBox(width: 8),
                Text(
                  title,
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                    color: Colors.black87,
                  ),
                ),
              ],
            ),
          ),
          Divider(height: 1, color: Colors.grey[200]),
          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(children: children),
          ),
        ],
      ),
    );
  }

  Widget _buildTextField({
    required TextEditingController controller,
    required String label,
    required IconData icon,
    TextInputType? keyboardType,
  }) {
    return TextFormField(
      controller: controller,
      keyboardType: keyboardType,
      decoration: InputDecoration(
        labelText: label,
        prefixIcon: Icon(icon, size: 20),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: BorderSide(color: Colors.grey[300]!),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: BorderSide(color: Colors.blue[600]!),
        ),
        contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 16),
      ),
    );
  }

  Widget _buildDropdown({
    required String label,
    required String value,
    required List<DropdownMenuItem<String>> items,
    required Function(String?) onChanged,
  }) {
    return DropdownButtonFormField<String>(
      value: value,
      decoration: InputDecoration(
        labelText: label,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: BorderSide(color: Colors.grey[300]!),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: BorderSide(color: Colors.blue[600]!),
        ),
        contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 16),
      ),
      items: items,
      onChanged: onChanged,
    );
  }

  Widget _buildSwitchTile({
    required String title,
    required String subtitle,
    required bool value,
    required Function(bool) onChanged,
    required IconData icon,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          Icon(icon, color: Colors.grey[600], size: 20),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                Text(
                  subtitle,
                  style: TextStyle(
                    fontSize: 12,
                    color: Colors.grey[600],
                  ),
                ),
              ],
            ),
          ),
          Switch(
            value: value,
            onChanged: onChanged,
            activeColor: Colors.blue[600],
          ),
        ],
      ),
    );
  }

  Widget _buildActionTile({
    required String title,
    required String subtitle,
    required IconData icon,
    required VoidCallback onTap,
    Color? textColor,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(8),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 8),
        child: Row(
          children: [
            Icon(icon, color: textColor ?? Colors.grey[600], size: 20),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w500,
                      color: textColor,
                    ),
                  ),
                  Text(
                    subtitle,
                    style: TextStyle(
                      fontSize: 12,
                      color: Colors.grey[600],
                    ),
                  ),
                ],
              ),
            ),
            Icon(
              Icons.arrow_forward_ios,
              size: 14,
              color: Colors.grey[400],
            ),
          ],
        ),
      ),
    );
  }

  void _showSnackBar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message)),
    );
  }

  void _showResetDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Reset Settings'),
        content: const Text('Are you sure you want to reset all settings to default values?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () async {
              final prefs = await SharedPreferences.getInstance();
              await prefs.clear();
              Navigator.pop(context);
              _loadSettings();
              _showSnackBar('Settings reset successfully');
            },
            child: const Text('Reset', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
  }

  void _showAboutDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('About'),
        content: const Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Business Management App'),
            SizedBox(height: 8),
            Text('Version: 1.0.0'),
            Text('Build: 2025.1'),
            SizedBox(height: 14),
            Text('A simple and professional business management solution.'),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Close'),
          ),
        ],
      ),
    );
  }
}