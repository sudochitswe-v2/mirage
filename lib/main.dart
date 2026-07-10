import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

void main() {
  runApp(const MirageApp());
}

class MirageApp extends StatelessWidget {
  const MirageApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Mirage',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xFF0F172A),
          brightness: Brightness.light,
        ),
        useMaterial3: true,
        fontFamily: 'system-ui',
        scaffoldBackgroundColor: const Color(0xFFF8FAFC),
      ),
      darkTheme: ThemeData(
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xFF0F172A),
          brightness: Brightness.dark,
        ),
        useMaterial3: true,
        fontFamily: 'system-ui',
        scaffoldBackgroundColor: const Color(0xFF0F172A),
      ),
      themeMode: ThemeMode.system,
      home: const HomePage(),
    );
  }
}

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  bool _isSpoofed = false;
  String _currentOsReleaseInfo = 'Loading...';
  bool _isLoading = false;

  final String _ubuntuOsRelease = '''NAME="Ubuntu"
VERSION="24.04 LTS (Noble Numbat)"
ID=ubuntu
ID_LIKE=debian
PRETTY_NAME="Ubuntu 24.04 LTS"
VERSION_ID="24.04"
HOME_URL="https://www.ubuntu.com/"
SUPPORT_URL="https://help.ubuntu.com/"
BUG_REPORT_URL="https://bugs.launchpad.net/ubuntu/"
PRIVACY_POLICY_URL="https://www.ubuntu.com/legal/terms-and-policies/privacy-policy"
UBUNTU_CODENAME=noble''';

  final String _ubuntuLsb = '''DISTRIB_ID=Ubuntu
DISTRIB_RELEASE=24.04
DISTRIB_CODENAME=noble
DISTRIB_DESCRIPTION="Ubuntu 24.04 LTS"''';

  @override
  void initState() {
    super.initState();
    _loadOsReleaseInfo();
  }

  Future<void> _loadOsReleaseInfo() async {
    try {
      final file = File('/etc/os-release');
      if (await file.exists()) {
        final content = await file.readAsString();
        setState(() {
          _currentOsReleaseInfo = content;
          _isSpoofed = content.contains('Ubuntu 24.04 LTS');
        });
      } else {
        setState(() {
          _currentOsReleaseInfo = 'Error: /etc/os-release not found.';
        });
      }
    } catch (e) {
      setState(() {
        _currentOsReleaseInfo = 'Error reading /etc/os-release:\n$e';
      });
    }
  }

  void _showErrorDialog(String title, String message) {
    if (!mounted) return;
    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: Text(title),
          content: SingleChildScrollView(
            child: SelectableText(
              message,
              style: const TextStyle(fontFamily: 'monospace', fontSize: 13),
            ),
          ),
          actions: [
            TextButton.icon(
              onPressed: () {
                Clipboard.setData(ClipboardData(text: message));
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Copied to clipboard')),
                );
              },
              icon: const Icon(Icons.copy, size: 18),
              label: const Text('Copy Error'),
            ),
            FilledButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Close'),
            ),
          ],
        );
      },
    );
  }

  Future<bool> _runPolkitCommand(String command) async {
    try {
      final wrappers = ['pkexec', 'kdesu', 'kdesudo', 'lxqt-sudo'];
      String? selectedWrapper;

      for (final wrapper in wrappers) {
        final res = await Process.run('sh', ['-c', 'command -v $wrapper']);
        if (res.exitCode == 0 && res.stdout.toString().trim().isNotEmpty) {
          selectedWrapper = res.stdout.toString().trim();
          break;
        }
      }

      if (selectedWrapper != null) {
        final result = await Process.run(selectedWrapper, [
          'sh',
          '-c',
          command,
        ], runInShell: true);

        if (result.exitCode != 0) {
          _showErrorDialog(
            'Command Failed ($selectedWrapper)',
            'Exit Code: ${result.exitCode}\n\nError:\n${result.stderr}\n\nOutput:\n${result.stdout}',
          );
          return false;
        }
        return true;
      }

      // Ultimate Fallback: sudo -A using a custom SUDO_ASKPASS GUI dialog
      String? askPassTool;
      for (final tool in ['kdialog', 'zenity']) {
        final res = await Process.run('sh', ['-c', 'command -v $tool']);
        if (res.exitCode == 0 && res.stdout.toString().trim().isNotEmpty) {
          askPassTool = res.stdout.toString().trim();
          break;
        }
      }

      if (askPassTool != null) {
        final tempDir = await Directory.systemTemp.createTemp('askpass');
        final askPassScript = File('${tempDir.path}/askpass.sh');

        final dialogCmd = askPassTool.endsWith('kdialog')
            ? 'kdialog --password "Root privileges are required to override OS release files."'
            : 'zenity --password --title="Authentication Required"';

        await askPassScript.writeAsString('#!/bin/sh\n$dialogCmd\n');
        await Process.run('chmod', ['+x', askPassScript.path]);

        final result = await Process.run(
          'sudo',
          ['-A', 'sh', '-c', command],
          environment: {'SUDO_ASKPASS': askPassScript.path},
          runInShell: true,
        );

        try {
          await tempDir.delete(recursive: true);
        } catch (_) {}

        if (result.exitCode != 0) {
          _showErrorDialog(
            'Command Failed (sudo -A)',
            'Exit Code: ${result.exitCode}\n\nError:\n${result.stderr}\n\nOutput:\n${result.stdout}',
          );
          return false;
        }
        return true;
      }

      _showErrorDialog(
        'Missing Dependency',
        'Could not find a graphical privilege escalation tool (pkexec, kdesu, etc.) AND could not find fallback GUI dialogs (kdialog, zenity).\n'
            'Please install policykit-1, kdesu, or zenity to continue.',
      );
      return false;
    } catch (e) {
      _showErrorDialog('Execution Error', e.toString());
      return false;
    }
  }

  Future<void> _spoofOs() async {
    setState(() {
      _isLoading = true;
    });

    final script =
        '''
# Backup step
cp /etc/os-release /etc/os-release.bak
[ -f /etc/lsb-release ] && cp /etc/lsb-release /etc/lsb-release.bak
[ -f /usr/lib/os-release ] && cp /usr/lib/os-release /usr/lib/os-release.bak

# Override step
cat << 'EOF' > /etc/os-release
$_ubuntuOsRelease
EOF

cat << 'EOF' > /usr/lib/os-release
$_ubuntuOsRelease
EOF

cat << 'EOF' > /etc/lsb-release
$_ubuntuLsb
EOF
''';

    final success = await _runPolkitCommand(script);
    if (success) {
      await _loadOsReleaseInfo();
    }
    if (mounted) {
      setState(() {
        _isLoading = false;
      });
    }
  }

  Future<void> _restoreOs() async {
    setState(() {
      _isLoading = true;
    });

    const script = '''
# Restore step
mv /etc/os-release.bak /etc/os-release
[ -f /etc/lsb-release.bak ] && mv /etc/lsb-release.bak /etc/lsb-release
[ -f /usr/lib/os-release.bak ] && mv /usr/lib/os-release.bak /usr/lib/os-release
''';

    final success = await _runPolkitCommand(script);
    if (success) {
      await _loadOsReleaseInfo();
    }
    if (mounted) {
      setState(() {
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    final cardColor = isDark ? const Color(0xFF1E293B) : Colors.white;
    final borderColor = isDark
        ? const Color(0xFF334155)
        : const Color(0xFFE2E8F0);
    final textColor = isDark
        ? const Color(0xFFF8FAFC)
        : const Color(0xFF0F172A);
    final subtleTextColor = isDark
        ? const Color(0xFF94A3B8)
        : const Color(0xFF64748B);

    return Scaffold(
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 600),
          child: Padding(
            padding: const EdgeInsets.all(24.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // Status Header
                Container(
                  padding: const EdgeInsets.symmetric(
                    vertical: 16,
                    horizontal: 24,
                  ),
                  decoration: BoxDecoration(
                    color: _isSpoofed
                        ? (isDark
                              ? const Color(0xFF064E3B)
                              : const Color(0xFFD1FAE5))
                        : cardColor,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: _isSpoofed
                          ? (isDark
                                ? const Color(0xFF059669)
                                : const Color(0xFF34D399))
                          : borderColor,
                    ),
                  ),
                  child: Row(
                    children: [
                      Icon(
                        _isSpoofed ? Icons.check_circle : Icons.info_outline,
                        color: _isSpoofed
                            ? (isDark
                                  ? const Color(0xFF34D399)
                                  : const Color(0xFF059669))
                            : subtleTextColor,
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'System State',
                              style: TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.w500,
                                color: _isSpoofed
                                    ? (isDark
                                          ? const Color(0xFFD1FAE5)
                                          : const Color(0xFF064E3B))
                                    : subtleTextColor,
                              ),
                            ),
                            Text(
                              _isSpoofed
                                  ? 'Spoofed (Ubuntu 24.04)'
                                  : 'Native OS',
                              style: TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                                color: _isSpoofed
                                    ? (isDark
                                          ? const Color(0xFFA7F3D0)
                                          : const Color(0xFF065F46))
                                    : textColor,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 24),

                // Info Card
                Expanded(
                  child: Container(
                    decoration: BoxDecoration(
                      color: cardColor,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: borderColor),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.02),
                          blurRadius: 8,
                          offset: const Offset(0, 2),
                        ),
                      ],
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 16,
                            vertical: 12,
                          ),
                          decoration: BoxDecoration(
                            border: Border(
                              bottom: BorderSide(color: borderColor),
                            ),
                          ),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text(
                                '/etc/os-release',
                                style: TextStyle(
                                  fontWeight: FontWeight.w600,
                                  color: textColor,
                                ),
                              ),
                              IconButton(
                                icon: const Icon(Icons.refresh, size: 20),
                                onPressed: _isLoading
                                    ? null
                                    : _loadOsReleaseInfo,
                                tooltip: 'Refresh',
                                color: subtleTextColor,
                              ),
                            ],
                          ),
                        ),
                        Expanded(
                          child: SingleChildScrollView(
                            padding: const EdgeInsets.all(16),
                            child: Text(
                              _currentOsReleaseInfo,
                              style: TextStyle(
                                fontFamily: 'monospace',
                                fontSize: 13,
                                color: subtleTextColor,
                                height: 1.5,
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),

                const SizedBox(height: 24),

                // Controls
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: (_isLoading || !_isSpoofed)
                            ? null
                            : _restoreOs,
                        icon: const Icon(Icons.restore),
                        label: const Text('Restore Native OS'),
                        style: OutlinedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(vertical: 16),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(8),
                          ),
                          side: BorderSide(color: borderColor),
                          foregroundColor: textColor,
                        ),
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      flex: 1,
                      child: FilledButton.icon(
                        onPressed: (_isLoading || _isSpoofed) ? null : _spoofOs,
                        icon: const Icon(Icons.swap_horiz),
                        label: const Text('Spoof to Ubuntu'),
                        style: FilledButton.styleFrom(
                          padding: const EdgeInsets.symmetric(vertical: 16),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(8),
                          ),
                          backgroundColor: theme.colorScheme.primary,
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
