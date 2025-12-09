// ignore_for_file: use_build_context_synchronously
import 'package:flutter/material.dart';

class SettingsScreen extends StatefulWidget {
  final int userId;
  final String username;
  final bool isDarkMode;
  final String language;
  final Function(bool) onDarkModeChanged;
  final Function(String) onLanguageChanged;
  final VoidCallback onLogout;

  const SettingsScreen({
    super.key,
    required this.userId,
    required this.username,
    required this.isDarkMode,
    required this.language,
    required this.onDarkModeChanged,
    required this.onLanguageChanged,
    required this.onLogout,
  });

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  late bool _isDarkMode;
  late String _language;

  @override
  void initState() {
    super.initState();
    _isDarkMode = widget.isDarkMode;
    _language = widget.language;
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'الإعدادات',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        centerTitle: true,
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          // Profile section
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [colorScheme.primary, colorScheme.secondary],
              ),
              borderRadius: BorderRadius.circular(20),
              boxShadow: [
                BoxShadow(
                  color: colorScheme.primary.withAlpha(60),
                  blurRadius: 15,
                  offset: const Offset(0, 5),
                ),
              ],
            ),
            child: Row(
              children: [
                CircleAvatar(
                  radius: 35,
                  backgroundColor: Colors.white,
                  child: Text(
                    widget.username.substring(0, 1).toUpperCase(),
                    style: TextStyle(
                      fontSize: 28,
                      fontWeight: FontWeight.bold,
                      color: colorScheme.primary,
                    ),
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        '@${widget.username}',
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'ID: ${widget.userId}',
                        style: TextStyle(
                          color: Colors.white.withAlpha(200),
                          fontSize: 14,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),

          // Appearance section
          _buildSectionTitle('المظهر'),
          _buildSettingsCard([
            _buildSwitchTile(
              icon: Icons.dark_mode,
              title: 'الوضع الداكن',
              subtitle: 'تفعيل المظهر الداكن',
              value: _isDarkMode,
              onChanged: (value) {
                setState(() => _isDarkMode = value);
                widget.onDarkModeChanged(value);
              },
            ),
          ]),
          const SizedBox(height: 16),

          // Language section
          _buildSectionTitle('اللغة'),
          _buildSettingsCard([
            _buildLanguageTile(
              icon: Icons.language,
              title: 'اللغة',
              currentLanguage: _language,
            ),
          ]),
          const SizedBox(height: 16),

          // Notifications section
          _buildSectionTitle('الإشعارات'),
          _buildSettingsCard([
            _buildSwitchTile(
              icon: Icons.notifications,
              title: 'الإشعارات',
              subtitle: 'تفعيل الإشعارات',
              value: true,
              onChanged: (value) {},
            ),
            const Divider(height: 1),
            _buildSwitchTile(
              icon: Icons.email,
              title: 'إشعارات الرسائل',
              subtitle: 'تنبيهات الرسائل الجديدة',
              value: true,
              onChanged: (value) {},
            ),
          ]),
          const SizedBox(height: 16),

          // Privacy section
          _buildSectionTitle('الخصوصية والأمان'),
          _buildSettingsCard([
            _buildNavigationTile(
              icon: Icons.lock,
              title: 'تغيير كلمة المرور',
              onTap: () {},
            ),
            const Divider(height: 1),
            _buildNavigationTile(
              icon: Icons.security,
              title: 'الخصوصية',
              onTap: () {},
            ),
            const Divider(height: 1),
            _buildNavigationTile(
              icon: Icons.block,
              title: 'المستخدمون المحظورون',
              onTap: () {},
            ),
          ]),
          const SizedBox(height: 16),

          // About section
          _buildSectionTitle('حول التطبيق'),
          _buildSettingsCard([
            _buildNavigationTile(
              icon: Icons.info,
              title: 'عن التطبيق',
              onTap: () {},
            ),
            const Divider(height: 1),
            _buildNavigationTile(
              icon: Icons.help,
              title: 'المساعدة والدعم',
              onTap: () {},
            ),
            const Divider(height: 1),
            _buildNavigationTile(
              icon: Icons.policy,
              title: 'سياسة الخصوصية',
              onTap: () {},
            ),
          ]),
          const SizedBox(height: 24),

          // Logout button
          Container(
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(16),
              boxShadow: [
                BoxShadow(
                  color: Colors.red.withAlpha(40),
                  blurRadius: 10,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: ElevatedButton.icon(
              onPressed: () {
                showDialog(
                  context: context,
                  builder: (context) => AlertDialog(
                    title: const Text('تسجيل الخروج'),
                    content: const Text('هل أنت متأكد من تسجيل الخروج؟'),
                    actions: [
                      TextButton(
                        onPressed: () => Navigator.pop(context),
                        child: const Text('إلغاء'),
                      ),
                      TextButton(
                        onPressed: () {
                          Navigator.pop(context);
                          widget.onLogout();
                        },
                        child: const Text(
                          'خروج',
                          style: TextStyle(color: Colors.red),
                        ),
                      ),
                    ],
                  ),
                );
              },
              icon: const Icon(Icons.logout),
              label: const Text('تسجيل الخروج'),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.red.shade50,
                foregroundColor: Colors.red,
                padding: const EdgeInsets.symmetric(vertical: 16),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
              ),
            ),
          ),
          const SizedBox(height: 32),

          // Version
          Center(
            child: Text(
              'الإصدار 1.0.0',
              style: TextStyle(color: Colors.grey.shade500, fontSize: 12),
            ),
          ),
          const SizedBox(height: 16),
        ],
      ),
    );
  }

  Widget _buildSectionTitle(String title) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8, right: 4),
      child: Text(
        title,
        style: TextStyle(
          fontSize: 14,
          fontWeight: FontWeight.bold,
          color: Colors.grey.shade600,
        ),
      ),
    );
  }

  Widget _buildSettingsCard(List<Widget> children) {
    return Container(
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withAlpha(10),
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(children: children),
    );
  }

  Widget _buildSwitchTile({
    required IconData icon,
    required String title,
    required String subtitle,
    required bool value,
    required Function(bool) onChanged,
  }) {
    return ListTile(
      leading: Container(
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(
          color: Theme.of(context).colorScheme.primaryContainer,
          borderRadius: BorderRadius.circular(10),
        ),
        child: Icon(icon, color: Theme.of(context).colorScheme.primary),
      ),
      title: Text(title, style: const TextStyle(fontWeight: FontWeight.w500)),
      subtitle: Text(
        subtitle,
        style: TextStyle(color: Colors.grey.shade600, fontSize: 12),
      ),
      trailing: Switch(value: value, onChanged: onChanged),
    );
  }

  Widget _buildNavigationTile({
    required IconData icon,
    required String title,
    required VoidCallback onTap,
  }) {
    return ListTile(
      leading: Container(
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(
          color: Theme.of(context).colorScheme.primaryContainer,
          borderRadius: BorderRadius.circular(10),
        ),
        child: Icon(icon, color: Theme.of(context).colorScheme.primary),
      ),
      title: Text(title, style: const TextStyle(fontWeight: FontWeight.w500)),
      trailing: Icon(
        Icons.arrow_forward_ios,
        size: 16,
        color: Colors.grey.shade400,
      ),
      onTap: onTap,
    );
  }

  Widget _buildLanguageTile({
    required IconData icon,
    required String title,
    required String currentLanguage,
  }) {
    return ListTile(
      leading: Container(
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(
          color: Theme.of(context).colorScheme.primaryContainer,
          borderRadius: BorderRadius.circular(10),
        ),
        child: Icon(icon, color: Theme.of(context).colorScheme.primary),
      ),
      title: Text(title, style: const TextStyle(fontWeight: FontWeight.w500)),
      trailing: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: Theme.of(context).colorScheme.primaryContainer,
          borderRadius: BorderRadius.circular(20),
        ),
        child: DropdownButton<String>(
          value: currentLanguage,
          underline: const SizedBox(),
          isDense: true,
          items: const [
            DropdownMenuItem(value: 'ar', child: Text('العربية')),
            DropdownMenuItem(value: 'en', child: Text('English')),
          ],
          onChanged: (value) {
            if (value != null) {
              setState(() => _language = value);
              widget.onLanguageChanged(value);
            }
          },
        ),
      ),
    );
  }
}
