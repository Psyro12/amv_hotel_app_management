import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class SettingsScreen extends StatelessWidget {
  const SettingsScreen({Key? key}) : super(key: key);

  final Color amvViolet = const Color(0xFF2D0F35);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text("Settings", style: GoogleFonts.montserrat(fontWeight: FontWeight.bold)),
        backgroundColor: amvViolet,
        foregroundColor: Colors.white,
        elevation: 0,
      ),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          _buildSettingsSection("Account"),
          _buildSettingsTile(Icons.person_outline, "Edit Profile", () {}),
          _buildSettingsTile(Icons.notifications_none, "Notifications", () {}),
          
          const SizedBox(height: 20),
          _buildSettingsSection("Preferences"),
          _buildSettingsTile(Icons.language, "Language", () {}),
          _buildSettingsTile(Icons.dark_mode_outlined, "Dark Mode", () {}),
          
          const SizedBox(height: 20),
          _buildSettingsSection("Support"),
          _buildSettingsTile(Icons.help_outline, "Help Center", () {}),
          _buildSettingsTile(Icons.info_outline, "About App", () {}),
        ],
      ),
    );
  }

  Widget _buildSettingsSection(String title) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 5),
      child: Text(
        title,
        style: GoogleFonts.montserrat(
          fontSize: 16,
          fontWeight: FontWeight.bold,
          color: amvViolet,
        ),
      ),
    );
  }

  Widget _buildSettingsTile(IconData icon, String title, VoidCallback onTap) {
    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      margin: const EdgeInsets.only(bottom: 10),
      child: ListTile(
        leading: Icon(icon, color: amvViolet),
        title: Text(title, style: GoogleFonts.montserrat(fontSize: 14)),
        trailing: const Icon(Icons.chevron_right, size: 20),
        onTap: onTap,
      ),
    );
  }
}