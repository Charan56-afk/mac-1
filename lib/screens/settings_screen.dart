import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../services/app_settings.dart';
import '../theme_provider.dart';
import 'package:flutter_application_1/l10n/app_localizations.dart';

// ─── MAIN SETTINGS INDEX ─────────────────────────────────────────────────────
class FullSettingsScreen extends StatelessWidget {
  const FullSettingsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF050510),
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        iconTheme: const IconThemeData(color: Colors.white),
        title: Text('SETTINGS', style: GoogleFonts.outfit(color: Colors.white, fontWeight: FontWeight.bold, letterSpacing: 1.5)),
        centerTitle: true,
      ),
      body: ListView(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
        children: [
          _categoryCard(
            context,
            icon: Icons.display_settings_rounded,
            gradient: [const Color(0xFF00F0FF), const Color(0xFF0055FF)],
            title: AppLocalizations.of(context).contentDisplay,
            subtitle: 'Theme, Language, Auto-play, Data Saver',
            onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const ContentDisplaySettingsScreen())),
          ),
          const SizedBox(height: 12),
          _categoryCard(
            context,
            icon: Icons.notifications_rounded,
            gradient: [const Color(0xFFFFD700), const Color(0xFFFF8C00)],
            title: AppLocalizations.of(context).notifications,
            subtitle: 'Push, Email, Quiet Mode, Quiet Hours',
            onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const NotificationSettingsScreen())),
          ),
          const SizedBox(height: 12),
          _categoryCard(
            context,
            icon: Icons.shield_rounded,
            gradient: [const Color(0xFFFF0055), const Color(0xFFFF6B9D)],
            title: AppLocalizations.of(context).privacySafety,
            subtitle: 'Private Account, Story Privacy, Blocked Users',
            onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const PrivacySafetySettingsScreen())),
          ),
          const SizedBox(height: 12),
          _categoryCard(
            context,
            icon: Icons.manage_accounts_rounded,
            gradient: [const Color(0xFF9D00FF), const Color(0xFFFF00FF)],
            title: AppLocalizations.of(context).accountSecurity,
            subtitle: 'Two-Factor Auth, Change Password, Delete Account',
            onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const AccountSecuritySettingsScreen())),
          ),
        ],
      ),
    );
  }

  Widget _categoryCard(
    BuildContext context, {
    required IconData icon,
    required List<Color> gradient,
    required String title,
    required String subtitle,
    required VoidCallback onTap,
  }) {
    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(16),
        color: Colors.white.withValues(alpha: 0.04),
        border: Border.all(color: Colors.white.withValues(alpha: 0.06)),
      ),
      child: Material(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(16),
        child: InkWell(
          borderRadius: BorderRadius.circular(16),
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.all(16.0),
            child: Row(
              children: [
                Container(
                  width: 48,
                  height: 48,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(12),
                    gradient: LinearGradient(
                      colors: gradient,
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: gradient.first.withValues(alpha: 0.35),
                        blurRadius: 10,
                        offset: const Offset(0, 3),
                      ),
                    ],
                  ),
                  child: Icon(icon, color: Colors.white, size: 24),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title,
                        style: GoogleFonts.outfit(
                          color: Colors.white,
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        subtitle,
                        style: GoogleFonts.outfit(
                          color: Colors.white38,
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ),
                ),
                const Icon(
                  Icons.arrow_forward_ios_rounded,
                  color: Colors.white30,
                  size: 16,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// ─── REUSABLE SETTINGS WIDGETS ───────────────────────────────────────────────
class SettingsCard extends StatelessWidget {
  final Widget child;
  const SettingsCard({super.key, required this.child});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(14),
        color: Colors.white.withValues(alpha: 0.05),
        border: Border.all(color: Colors.white.withValues(alpha: 0.07)),
      ),
      child: child,
    );
  }
}

class SettingsIconBox extends StatelessWidget {
  final IconData icon;
  final Color color;
  const SettingsIconBox({super.key, required this.icon, required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 38,
      height: 38,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(10),
        color: color.withValues(alpha: 0.15),
      ),
      child: Icon(icon, color: color, size: 20),
    );
  }
}

class SettingsToggleTile extends StatelessWidget {
  final IconData icon;
  final Color iconColor;
  final String label;
  final String sublabel;
  final bool value;
  final ValueChanged<bool> onChanged;

  const SettingsToggleTile({
    super.key,
    required this.icon,
    required this.iconColor,
    required this.label,
    required this.sublabel,
    required this.value,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return SettingsCard(
      child: Row(
        children: [
          SettingsIconBox(icon: icon, color: iconColor),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: GoogleFonts.outfit(
                    color: Colors.white,
                    fontSize: 14,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                Text(
                  sublabel,
                  style: GoogleFonts.outfit(
                    color: Colors.white38,
                    fontSize: 11,
                  ),
                ),
              ],
            ),
          ),
          Switch.adaptive(
            value: value,
            onChanged: onChanged,
            activeThumbColor: const Color(0xFF00F0FF),
            activeTrackColor: const Color(0xFF00F0FF).withValues(alpha: 0.3),
          ),
        ],
      ),
    );
  }
}

class SettingsPickerTile extends StatelessWidget {
  final IconData icon;
  final Color iconColor;
  final String label;
  final String value;
  final List<String> options;
  final List<String>? optionLabels;
  final ValueChanged<String> onChanged;

  const SettingsPickerTile({
    super.key,
    required this.icon,
    required this.iconColor,
    required this.label,
    required this.value,
    required this.options,
    this.optionLabels,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    final labels = optionLabels ?? options;
    return SettingsCard(
      child: Row(
        children: [
          SettingsIconBox(icon: icon, color: iconColor),
          const SizedBox(width: 14),
          Expanded(
            child: Text(
              label,
              style: GoogleFonts.outfit(
                color: Colors.white,
                fontSize: 14,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
          DropdownButtonHideUnderline(
            child: DropdownButton<String>(
              value: value,
              dropdownColor: const Color(0xFF0F0F2A),
              icon: const Icon(
                Icons.keyboard_arrow_down_rounded,
                color: Colors.white38,
                size: 18,
              ),
              style: GoogleFonts.outfit(
                color: const Color(0xFF00F0FF),
                fontSize: 13,
              ),
              items: List.generate(
                options.length,
                (i) => DropdownMenuItem(
                  value: options[i],
                  child: Text(
                    labels[i],
                    style: GoogleFonts.outfit(
                      color: Colors.white,
                      fontSize: 13,
                    ),
                  ),
                ),
              ),
              onChanged: (v) {
                if (v != null) onChanged(v);
              },
            ),
          ),
        ],
      ),
    );
  }
}

class SettingsNavTile extends StatelessWidget {
  final IconData icon;
  final Color iconColor;
  final String label;
  final String sublabel;
  final VoidCallback onTap;

  const SettingsNavTile({
    super.key,
    required this.icon,
    required this.iconColor,
    required this.label,
    this.sublabel = '',
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return SettingsCard(
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(14),
        child: Row(
          children: [
            SettingsIconBox(icon: icon, color: iconColor),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    label,
                    style: GoogleFonts.outfit(
                      color: Colors.white,
                      fontSize: 14,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  if (sublabel.isNotEmpty)
                    Text(
                      sublabel,
                      style: GoogleFonts.outfit(
                        color: Colors.white38,
                        fontSize: 11,
                      ),
                    ),
                ],
              ),
            ),
            const Icon(
              Icons.chevron_right_rounded,
              color: Colors.white24,
              size: 20,
            ),
          ],
        ),
      ),
    );
  }
}

// ─── CONTENT & DISPLAY SCREEN ────────────────────────────────────────────────
class ContentDisplaySettingsScreen extends StatefulWidget {
  const ContentDisplaySettingsScreen({super.key});

  @override
  State<ContentDisplaySettingsScreen> createState() => _ContentDisplaySettingsScreenState();
}

class _ContentDisplaySettingsScreenState extends State<ContentDisplaySettingsScreen> {
  final _settings = AppSettings.instance;

  @override
  void initState() {
    super.initState();
    _settings.addListener(_onSettingsChanged);
  }

  @override
  void dispose() {
    _settings.removeListener(_onSettingsChanged);
    super.dispose();
  }

  void _onSettingsChanged() {
    if (mounted) setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF050510),
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        iconTheme: const IconThemeData(color: Colors.white),
        title: Text(
          AppLocalizations.of(context).contentDisplay.toUpperCase(),
          style: GoogleFonts.outfit(color: Colors.white, fontWeight: FontWeight.bold, letterSpacing: 1.2),
        ),
        centerTitle: true,
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          SettingsToggleTile(
            icon: Icons.dark_mode_rounded,
            iconColor: const Color(0xFF9D00FF),
            label: AppLocalizations.of(context).darkMode,
            sublabel: AppLocalizations.of(context).darkModeDesc,
            value: _settings.darkMode,
            onChanged: (v) {
              _settings.setDarkMode(v);
              ThemeController.toggleTheme(v);
            },
          ),
          SettingsToggleTile(
            icon: Icons.play_circle_rounded,
            iconColor: const Color(0xFF00C896),
            label: AppLocalizations.of(context).autoPlayVideos,
            sublabel: AppLocalizations.of(context).autoPlayVideosDesc,
            value: _settings.autoPlay,
            onChanged: _settings.setAutoPlay,
          ),
          SettingsToggleTile(
            icon: Icons.data_saver_on_rounded,
            iconColor: const Color(0xFF4facfe),
            label: AppLocalizations.of(context).dataSaver,
            sublabel: AppLocalizations.of(context).dataSaverDesc,
            value: _settings.dataSaver,
            onChanged: _settings.setDataSaver,
          ),
          SettingsPickerTile(
            icon: Icons.language_rounded,
            iconColor: const Color(0xFFFFD700),
            label: AppLocalizations.of(context).language,
            value: _settings.language,
            options: const ['English', 'Telugu', 'Hindi', 'Tamil', 'Kannada', 'Malayalam'],
            onChanged: _settings.setLanguage,
          ),
        ],
      ),
    );
  }
}

// ─── NOTIFICATION SETTINGS SCREEN ────────────────────────────────────────────
class NotificationSettingsScreen extends StatefulWidget {
  const NotificationSettingsScreen({super.key});

  @override
  State<NotificationSettingsScreen> createState() => _NotificationSettingsScreenState();
}

class _NotificationSettingsScreenState extends State<NotificationSettingsScreen> {
  final _settings = AppSettings.instance;

  @override
  void initState() {
    super.initState();
    _settings.addListener(_onSettingsChanged);
  }

  @override
  void dispose() {
    _settings.removeListener(_onSettingsChanged);
    super.dispose();
  }

  void _onSettingsChanged() {
    if (mounted) setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF050510),
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        iconTheme: const IconThemeData(color: Colors.white),
        title: Text(
          AppLocalizations.of(context).notifications.toUpperCase(),
          style: GoogleFonts.outfit(color: Colors.white, fontWeight: FontWeight.bold, letterSpacing: 1.2),
        ),
        centerTitle: true,
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          SettingsToggleTile(
            icon: Icons.notifications_rounded,
            iconColor: const Color(0xFFFFD700),
            label: AppLocalizations.of(context).pushNotifications,
            sublabel: AppLocalizations.of(context).pushNotificationsDesc,
            value: _settings.pushNotifications,
            onChanged: _settings.setPushNotifications,
          ),
          SettingsToggleTile(
            icon: Icons.email_rounded,
            iconColor: const Color(0xFF4facfe),
            label: AppLocalizations.of(context).emailNotifications,
            sublabel: AppLocalizations.of(context).emailNotificationsDesc,
            value: _settings.emailNotifications,
            onChanged: _settings.setEmailNotifications,
          ),
          SettingsToggleTile(
            icon: Icons.do_not_disturb_on_rounded,
            iconColor: const Color(0xFFFF0055),
            label: AppLocalizations.of(context).quietMode,
            sublabel: AppLocalizations.of(context).quietModeDesc,
            value: _settings.quietMode,
            onChanged: _settings.setQuietMode,
          ),
          if (_settings.quietMode) ...[
            const SizedBox(height: 8),
            _quietHoursTile(),
          ],
        ],
      ),
    );
  }

  Widget _quietHoursTile() => SettingsCard(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(AppLocalizations.of(context).quietHours, style: GoogleFonts.outfit(color: Colors.white70, fontSize: 13, fontWeight: FontWeight.w500)),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(child: _timeButton(AppLocalizations.of(context).start, _settings.quietStartHour, (h) => _settings.setQuietHours(h, _settings.quietEndHour))),
                const SizedBox(width: 12),
                Expanded(child: _timeButton(AppLocalizations.of(context).end, _settings.quietEndHour, (h) => _settings.setQuietHours(_settings.quietStartHour, h))),
              ],
            ),
          ],
        ),
      );

  Widget _timeButton(String label, int hour, Function(int) onPick) {
    final time = TimeOfDay(hour: hour, minute: 0);
    return InkWell(
      onTap: () async {
        final picked = await showTimePicker(context: context, initialTime: time);
        if (picked != null) onPick(picked.hour);
      },
      borderRadius: BorderRadius.circular(10),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 10),
        decoration: BoxDecoration(
          border: Border.all(color: const Color(0xFF00F0FF).withValues(alpha: 0.3)),
          borderRadius: BorderRadius.circular(10),
        ),
        child: Column(
          children: [
            Text(label, style: GoogleFonts.outfit(color: Colors.white38, fontSize: 10)),
            const SizedBox(height: 4),
            Text(time.format(context), style: GoogleFonts.outfit(color: const Color(0xFF00F0FF), fontSize: 16, fontWeight: FontWeight.bold)),
          ],
        ),
      ),
    );
  }
}

// ─── PRIVACY & SAFETY SCREEN ─────────────────────────────────────────────────
class PrivacySafetySettingsScreen extends StatefulWidget {
  const PrivacySafetySettingsScreen({super.key});

  @override
  State<PrivacySafetySettingsScreen> createState() => _PrivacySafetySettingsScreenState();
}

class _PrivacySafetySettingsScreenState extends State<PrivacySafetySettingsScreen> {
  final _settings = AppSettings.instance;

  @override
  void initState() {
    super.initState();
    _settings.addListener(_onSettingsChanged);
  }

  @override
  void dispose() {
    _settings.removeListener(_onSettingsChanged);
    super.dispose();
  }

  void _onSettingsChanged() {
    if (mounted) setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF050510),
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        iconTheme: const IconThemeData(color: Colors.white),
        title: Text(
          AppLocalizations.of(context).privacySafety.toUpperCase(),
          style: GoogleFonts.outfit(color: Colors.white, fontWeight: FontWeight.bold, letterSpacing: 1.2),
        ),
        centerTitle: true,
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          SettingsToggleTile(
            icon: Icons.lock_rounded,
            iconColor: const Color(0xFFFF6B9D),
            label: AppLocalizations.of(context).privateAccount,
            sublabel: AppLocalizations.of(context).privateAccountDesc,
            value: _settings.privateAccount,
            onChanged: _settings.setPrivateAccount,
          ),
          SettingsPickerTile(
            icon: Icons.auto_stories_rounded,
            iconColor: const Color(0xFF9D00FF),
            label: AppLocalizations.of(context).storyPrivacy,
            value: _settings.storyPrivacy,
            options: const ['everyone', 'followers', 'closeFriends'],
            optionLabels: [
              AppLocalizations.of(context).everyone,
              AppLocalizations.of(context).followersOnly,
              AppLocalizations.of(context).closeFriends,
            ],
            onChanged: _settings.setStoryPrivacy,
          ),
          SettingsPickerTile(
            icon: Icons.alternate_email_rounded,
            iconColor: const Color(0xFF00F0FF),
            label: AppLocalizations.of(context).mentionsTags,
            value: _settings.mentionsPrivacy,
            options: const ['everyone', 'followers', 'nobody'],
            optionLabels: [
              AppLocalizations.of(context).everyone,
              AppLocalizations.of(context).followersOnly,
              AppLocalizations.of(context).nobody,
            ],
            onChanged: _settings.setMentionsPrivacy,
          ),
          SettingsNavTile(
            icon: Icons.block_rounded,
            iconColor: Colors.redAccent,
            label: AppLocalizations.of(context).blockedUsers,
            sublabel: '',
            onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const _BlockedUsersScreen())),
          ),
        ],
      ),
    );
  }
}

// ─── ACCOUNT & SECURITY SCREEN ───────────────────────────────────────────────
class AccountSecuritySettingsScreen extends StatefulWidget {
  const AccountSecuritySettingsScreen({super.key});

  @override
  State<AccountSecuritySettingsScreen> createState() => _AccountSecuritySettingsScreenState();
}

class _AccountSecuritySettingsScreenState extends State<AccountSecuritySettingsScreen> {
  final _settings = AppSettings.instance;

  @override
  void initState() {
    super.initState();
    _settings.addListener(_onSettingsChanged);
  }

  @override
  void dispose() {
    _settings.removeListener(_onSettingsChanged);
    super.dispose();
  }

  void _onSettingsChanged() {
    if (mounted) setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF050510),
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        iconTheme: const IconThemeData(color: Colors.white),
        title: Text(
          AppLocalizations.of(context).accountSecurity.toUpperCase(),
          style: GoogleFonts.outfit(color: Colors.white, fontWeight: FontWeight.bold, letterSpacing: 1.2),
        ),
        centerTitle: true,
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          SettingsToggleTile(
            icon: Icons.security_rounded,
            iconColor: const Color(0xFF00C896),
            label: AppLocalizations.of(context).twoFactorAuth,
            sublabel: AppLocalizations.of(context).twoFactorAuthDesc,
            value: _settings.twoFactor,
            onChanged: _settings.setTwoFactor,
          ),
          SettingsNavTile(
            icon: Icons.edit_rounded,
            iconColor: const Color(0xFF00F0FF),
            label: AppLocalizations.of(context).changePassword,
            sublabel: AppLocalizations.of(context).changePasswordDesc,
            onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const _ChangePasswordScreen())),
          ),
          SettingsNavTile(
            icon: Icons.delete_forever_rounded,
            iconColor: Colors.red,
            label: AppLocalizations.of(context).deleteAccount,
            sublabel: AppLocalizations.of(context).deleteAccountDesc,
            onTap: () => _confirmDelete(context),
          ),
        ],
      ),
    );
  }

  void _confirmDelete(BuildContext ctx) => showDialog(
        context: ctx,
        builder: (_) => AlertDialog(
          backgroundColor: const Color(0xFF0F0F1A),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          title: Text(AppLocalizations.of(context).deleteAccount, style: GoogleFonts.outfit(color: Colors.white, fontWeight: FontWeight.bold)),
          content: Text(AppLocalizations.of(context).deleteAccountConfirm, style: GoogleFonts.outfit(color: Colors.white60, fontSize: 14)),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx), child: Text(AppLocalizations.of(context).cancel, style: GoogleFonts.outfit(color: Colors.white54))),
            TextButton(
              onPressed: () {
                Navigator.pop(ctx);
                ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Account deletion request submitted.')));
              },
              child: Text(AppLocalizations.of(context).delete, style: GoogleFonts.outfit(color: Colors.red)),
            ),
          ],
        ),
      );
}

// ─── CHANGE PASSWORD SCREEN ──────────────────────────────────────────────────
class _ChangePasswordScreen extends StatefulWidget {
  const _ChangePasswordScreen();
  @override
  State<_ChangePasswordScreen> createState() => _ChangePasswordScreenState();
}

class _ChangePasswordScreenState extends State<_ChangePasswordScreen> {
  final _currentCtrl = TextEditingController();
  final _newCtrl = TextEditingController();
  final _confirmCtrl = TextEditingController();
  bool _obscureCurrent = true;
  bool _obscureNew = true;
  bool _loading = false;

  @override
  void dispose() {
    _currentCtrl.dispose();
    _newCtrl.dispose();
    _confirmCtrl.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (_newCtrl.text != _confirmCtrl.text) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(AppLocalizations.of(context).passwordsDoNotMatch, style: GoogleFonts.outfit()), backgroundColor: Colors.red));
      return;
    }
    setState(() => _loading = true);
    await Future.delayed(const Duration(seconds: 1));
    if (mounted) {
      setState(() => _loading = false);
      Navigator.pop(context);
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(AppLocalizations.of(context).passwordUpdated, style: GoogleFonts.outfit()), backgroundColor: const Color(0xFF00C896)));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF050510),
      appBar: AppBar(backgroundColor: Colors.transparent, iconTheme: const IconThemeData(color: Colors.white), title: Text('CHANGE PASSWORD', style: GoogleFonts.outfit(color: Colors.white, fontWeight: FontWeight.bold, letterSpacing: 1.2)), centerTitle: true),
      body: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          children: [
            _passwordField(AppLocalizations.of(context).currentPassword, _currentCtrl, _obscureCurrent, () => setState(() => _obscureCurrent = !_obscureCurrent)),
            const SizedBox(height: 16),
            _passwordField(AppLocalizations.of(context).newPassword, _newCtrl, _obscureNew, () => setState(() => _obscureNew = !_obscureNew)),
            const SizedBox(height: 16),
            _passwordField(AppLocalizations.of(context).confirmNewPassword, _confirmCtrl, _obscureNew, () {}),
            const SizedBox(height: 32),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: _loading ? null : _submit,
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF00F0FF),
                  foregroundColor: Colors.black,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                ),
                child: _loading ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.black)) : Text(AppLocalizations.of(context).updatePassword, style: GoogleFonts.outfit(fontWeight: FontWeight.bold)),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _passwordField(String label, TextEditingController ctrl, bool obscure, VoidCallback toggle) => TextField(
        controller: ctrl,
        obscureText: obscure,
        style: GoogleFonts.outfit(color: Colors.white),
        decoration: InputDecoration(
          labelText: label,
          labelStyle: GoogleFonts.outfit(color: Colors.white38),
          filled: true,
          fillColor: Colors.white.withValues(alpha: 0.05),
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: Colors.white.withValues(alpha: 0.1))),
          enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: Colors.white.withValues(alpha: 0.1))),
          focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: Color(0xFF00F0FF))),
          suffixIcon: IconButton(icon: Icon(obscure ? Icons.visibility_off_rounded : Icons.visibility_rounded, color: Colors.white38), onPressed: toggle),
        ),
      );
}

// ─── BLOCKED USERS SCREEN ────────────────────────────────────────────────────
class _BlockedUsersScreen extends StatelessWidget {
  const _BlockedUsersScreen();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF050510),
      appBar: AppBar(backgroundColor: Colors.transparent, iconTheme: const IconThemeData(color: Colors.white), title: Text('BLOCKED USERS', style: GoogleFonts.outfit(color: Colors.white, fontWeight: FontWeight.bold, letterSpacing: 1.2)), centerTitle: true),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.block_rounded, size: 64, color: Colors.white.withValues(alpha: 0.15)),
            const SizedBox(height: 16),
            Text(AppLocalizations.of(context).noBlockedUsers, style: GoogleFonts.outfit(color: Colors.white38, fontSize: 16)),
            const SizedBox(height: 8),
            Text("Users you block won't be able to\nfind your profile or posts.", textAlign: TextAlign.center, style: GoogleFonts.outfit(color: Colors.white24, fontSize: 13, height: 1.5)),
          ],
        ),
      ),
    );
  }
}
