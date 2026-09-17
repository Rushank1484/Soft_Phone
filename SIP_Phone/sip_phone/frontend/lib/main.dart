import 'package:flutter/material.dart';

import 'api_service.dart';

void main() => runApp(const SipPhoneApp());

class SipPhoneApp extends StatelessWidget {
  const SipPhoneApp({super.key});

  @override
  Widget build(BuildContext context) => MaterialApp(
        title: 'Softphone',
        debugShowCheckedModeBanner: false,
        theme: ThemeData(
          scaffoldBackgroundColor: const Color(0xFFF4F4F1),
          colorScheme: ColorScheme.fromSeed(seedColor: const Color(0xFF1E5D5F)),
          fontFamily: 'Arial',
          cardTheme: CardThemeData(
            color: Colors.white,
            elevation: 0,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
          ),
          inputDecorationTheme: InputDecorationTheme(
            filled: true,
            fillColor: const Color(0xFFF7F6F3),
            contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: BorderSide.none),
            enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: BorderSide.none),
            focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: BorderSide(color: const Color(0xFF1E5D5F), width: 1.2)),
          ),
        ),
        home: const PhoneHomePage(),
      );
}

class PhoneHomePage extends StatefulWidget {
  const PhoneHomePage({super.key});

  @override
  State<PhoneHomePage> createState() => _PhoneHomePageState();
}

class _PhoneHomePageState extends State<PhoneHomePage> {
  final _numberController = TextEditingController();
  final _searchController = TextEditingController();
  final _loginNameController = TextEditingController();
  final _loginExtensionController = TextEditingController();
  final _loginEmailController = TextEditingController();
  final _loginPasswordController = TextEditingController();
  int _selectedTab = 0;
  bool _isWorkspaceOpen = false;
  bool _isCalling = false;
  String? _userName;
  String? _userExtension;
  String? _authToken;
  final _api = SipPhoneApi();
  List<ApiRecentCall> _serverRecentCalls = [];

  static const Color foreground = Color(0xFF17232B);
  static const Color muted = Color(0xFF677783);
  static const Color accent = Color(0xFF1E5D5F);
  static const Color accentSoft = Color(0xFFE7F1F1);
  static const Color mint = Color(0xFF73C7A0);
  static const Color danger = Color(0xFFE76F68);
  static const Color subtleBorder = Color(0xFFE9E5E0);

  void _addDigit(String digit) => setState(() => _numberController.text += digit);

  Future<void> _startCall() async {
    final destination = _numberController.text.trim();
    final token = _authToken;
    if (destination.isEmpty || token == null) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(token == null ? 'Sign in with an extension before calling.' : 'Enter a number to call.')));
      }
      return;
    }
    try {
      await _api.recordCall(token, destination);
      if (!mounted) return;
      setState(() => _isCalling = true);
      await _loadRecentCalls(token);
    } on ApiException catch (error) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(error.message)));
    } catch (_) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Could not connect the call.')));
    }
  }

  @override
  void dispose() {
    _numberController.dispose();
    _searchController.dispose();
    _loginNameController.dispose();
    _loginExtensionController.dispose();
    _loginEmailController.dispose();
    _loginPasswordController.dispose();
    super.dispose();
  }

  String get _displayName => _userName ?? 'Guest';

  String get _initials {
    final parts = _displayName.trim().split(RegExp(r'\s+')).where((part) => part.isNotEmpty).toList();
    if (parts.isEmpty) return 'GU';
    if (parts.length == 1) return parts.first.substring(0, 1).toUpperCase();
    return '${parts.first[0]}${parts.last[0]}'.toUpperCase();
  }

  Future<void> _showLoginDialog() async {
    _loginNameController.text = _userName ?? '';
    _loginExtensionController.text = _userExtension ?? '';
    _loginEmailController.clear();
    _loginPasswordController.clear();
    final name = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        title: const Text('Sign in to Softphone', style: TextStyle(color: foreground, fontWeight: FontWeight.w700)),
        content: SizedBox(
          width: 360,
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            TextField(
              controller: _loginNameController,
              textInputAction: TextInputAction.next,
              decoration: const InputDecoration(labelText: 'Your name', prefixIcon: Icon(Icons.person_outline_rounded)),
            ),
            const SizedBox(height: 14),
            TextField(
              controller: _loginExtensionController,
              keyboardType: TextInputType.phone,
              textInputAction: TextInputAction.next,
              decoration: const InputDecoration(labelText: 'Extension', prefixIcon: Icon(Icons.dialpad_rounded)),
            ),
            const SizedBox(height: 14),
            TextField(
              controller: _loginEmailController,
              keyboardType: TextInputType.emailAddress,
              textInputAction: TextInputAction.next,
              decoration: const InputDecoration(labelText: 'Email address', prefixIcon: Icon(Icons.email_outlined)),
            ),
            const SizedBox(height: 14),
            TextField(
              controller: _loginPasswordController,
              obscureText: true,
              decoration: const InputDecoration(labelText: 'Password', prefixIcon: Icon(Icons.lock_outline_rounded)),
            ),
          ]),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: accent, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))),
            onPressed: () {
              final name = _loginNameController.text.trim();
              final extension = _loginExtensionController.text.trim();
              final email = _loginEmailController.text.trim();
              final password = _loginPasswordController.text;
              if (name.isEmpty || extension.isEmpty || !RegExp(r'^\d+$').hasMatch(extension) || !email.contains('@') || password.length < 4) {
                ScaffoldMessenger.of(this.context).showSnackBar(const SnackBar(content: Text('Enter a valid name, numeric extension, email, and password.')));
                return;
              }
              Navigator.pop(context, name);
            },
            child: const Text('Sign in'),
          ),
        ],
      ),
    );
    if (name == null || name.isEmpty || !mounted) {
      return;
    }
    try {
      final user = await _api.login(
        name: name,
        extension: _loginExtensionController.text.trim(),
        email: _loginEmailController.text.trim(),
        password: _loginPasswordController.text,
      );
      if (!mounted) return;
      setState(() {
        _userName = user.name;
        _userExtension = user.extension;
        _authToken = user.token;
      });
      await _loadRecentCalls(user.token);
    } on ApiException catch (error) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(error.message)));
    } catch (_) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('API unavailable. Start the backend or try again later.')));
    }
  }

  Future<void> _loadRecentCalls(String token) async {
    try {
      final calls = await _api.recentCalls(token);
      if (mounted) setState(() => _serverRecentCalls = calls);
    } catch (_) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Could not load recent calls.')));
    }
  }

  Future<void> _logOut() async {
    final token = _authToken;
    if (token != null) {
      await _api.logout(token);
    }
    if (mounted) {
      setState(() {
        _authToken = null;
        _userName = null;
        _userExtension = null;
        _serverRecentCalls = [];
      });
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
        body: Container(
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [Color(0xFFF3F3EE), Color(0xFFF7F6F3), Color(0xFFF0F4F5)],
            ),
          ),
          child: SafeArea(
            child: LayoutBuilder(
              builder: (context, constraints) {
                final compact = constraints.maxWidth < 900;
                return Column(
                  children: [
                    _buildTopBar(compact),
                    Expanded(child: compact ? _buildMobileLayout() : _buildDesktopLayout()),
                  ],
                );
              },
            ),
          ),
        ),
      );

  Widget _buildTopBar(bool compact) => Container(
        height: 78,
        padding: const EdgeInsets.symmetric(horizontal: 24),
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.75),
          border: const Border(bottom: BorderSide(color: Color(0xFFE7E5E1))),
          boxShadow: const [BoxShadow(color: Color(0x0A000000), blurRadius: 12, offset: Offset(0, 2))],
        ),
        child: Row(
          children: [
            if (compact) ...[
              IconButton(
                onPressed: () => setState(() => _isWorkspaceOpen = !_isWorkspaceOpen),
                icon: Icon(_isWorkspaceOpen ? Icons.close_rounded : Icons.menu_rounded, color: accent),
              ),
              const SizedBox(width: 4),
            ],
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: accentSoft,
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: const Color(0xFFDDEBEC)),
              ),
              child: const Icon(Icons.phone_in_talk_rounded, color: accent, size: 22),
            ),
            const SizedBox(width: 12),
            const Text('Softphone', style: TextStyle(fontSize: 20, fontWeight: FontWeight.w700, color: foreground)),
            const Spacer(),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              decoration: BoxDecoration(
                color: const Color(0xFFEAF8F1),
                borderRadius: BorderRadius.circular(999),
              ),
              child: Row(
                children: const [
                  Icon(Icons.circle, size: 8, color: mint),
                  SizedBox(width: 6),
                  Text('Online', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: Color(0xFF386550))),
                ],
              ),
            ),
            const SizedBox(width: 14),
            IconButton(onPressed: () {}, icon: const Icon(Icons.settings_outlined, color: muted), tooltip: 'Settings'),
            const SizedBox(width: 10),
            if (_userName == null)
              FilledButton.icon(
                onPressed: _showLoginDialog,
                icon: const Icon(Icons.login_rounded, size: 18),
                label: const Text('Log in'),
                style: FilledButton.styleFrom(
                  backgroundColor: accent,
                  padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
              )
            else
              PopupMenuButton<String>(
                tooltip: 'Account menu',
                onSelected: (value) {
                  if (value == 'logout') _logOut();
                },
                itemBuilder: (context) => const [PopupMenuItem(value: 'logout', child: Text('Log out'))],
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
                  decoration: BoxDecoration(
                    color: const Color(0xFFF5F6F4),
                    borderRadius: BorderRadius.circular(999),
                    border: Border.all(color: const Color(0xFFE8E2DB)),
                  ),
                  child: Row(
                    children: [
                      CircleAvatar(
                        radius: 16,
                        backgroundColor: accentSoft,
                        child: Text(_initials, style: const TextStyle(color: accent, fontSize: 11, fontWeight: FontWeight.w700)),
                      ),
                      const SizedBox(width: 8),
                      Text(_displayName, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: foreground)),
                    ],
                  ),
                ),
              ),
          ],
        ),
      );

  Widget _buildDesktopLayout() => Padding(
        padding: const EdgeInsets.fromLTRB(24, 22, 24, 24),
        child: Row(
          children: [
            SizedBox(width: 260, child: _buildSidebar()),
            const SizedBox(width: 22),
            Expanded(child: _buildWorkspace()),
          ],
        ),
      );

  Widget _buildMobileLayout() => ListView(
        padding: const EdgeInsets.fromLTRB(16, 18, 16, 22),
        children: [
          if (_isWorkspaceOpen) ...[
            _buildSidebar(),
            const SizedBox(height: 16),
          ],
          _buildWorkspace(),
        ],
      );

  Widget _buildSidebar() => Container(
        padding: const EdgeInsets.fromLTRB(18, 18, 18, 14),
        decoration: BoxDecoration(
          color: const Color(0xFF1B2D35),
          borderRadius: BorderRadius.circular(24),
          border: Border.all(color: const Color(0xFF2B3B45)),
          boxShadow: const [BoxShadow(color: Color(0x0E0F2630), blurRadius: 20, offset: Offset(0, 10))],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SizedBox(height: 6),
            const Text('Workspace', style: TextStyle(color: Color(0xFFABC0C4), fontSize: 11, letterSpacing: 1.2, fontWeight: FontWeight.w700)),
            const SizedBox(height: 16),
            _navItem(Icons.dashboard_rounded, 'Overview', 0),
            _navItem(Icons.person_outline_rounded, 'Contacts', 1),
            _navItem(Icons.history_rounded, 'Call history', 2),
            const SizedBox(height: 18),
            const Divider(color: Color(0xFF2D3E45), thickness: 1),
            const SizedBox(height: 18),
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: const Color(0xFF213A42),
                borderRadius: BorderRadius.circular(18),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('Account', style: TextStyle(fontSize: 11, color: Color(0xFF99AEB5), letterSpacing: 1.2, fontWeight: FontWeight.w700)),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      CircleAvatar(
                        radius: 18,
                        backgroundColor: const Color(0xFFE7F1F1),
                        child: Text(_initials, style: const TextStyle(color: accent, fontSize: 12, fontWeight: FontWeight.w700)),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(_displayName, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w600, fontSize: 14)),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      );

  Widget _navItem(IconData icon, String label, int index) => InkWell(
        borderRadius: BorderRadius.circular(14),
        onTap: () => setState(() {
          _selectedTab = index;
          _isWorkspaceOpen = false;
        }),
        child: Container(
          margin: const EdgeInsets.only(bottom: 8),
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
          decoration: BoxDecoration(
            color: _selectedTab == index ? const Color(0xFF284A56) : Colors.transparent,
            borderRadius: BorderRadius.circular(14),
          ),
          child: Row(
            children: [
              Icon(icon, size: 18, color: _selectedTab == index ? Colors.white : const Color(0xFFC2CDD1)),
              const SizedBox(width: 12),
              Text(label, style: TextStyle(color: _selectedTab == index ? Colors.white : const Color(0xFFCFD9DD), fontSize: 14, fontWeight: FontWeight.w600)),
            ],
          ),
        ),
      );

  Widget _buildWorkspace() => LayoutBuilder(
        builder: (context, constraints) => SingleChildScrollView(
          padding: const EdgeInsets.only(bottom: 12),
          child: SizedBox(
            width: double.infinity,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const SizedBox(height: 4),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text('Good morning', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: muted)),
                        const SizedBox(height: 6),
                        Text(_displayName, style: const TextStyle(fontSize: 34, fontWeight: FontWeight.w700, color: foreground, letterSpacing: -0.8)),
                      ],
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.8),
                        borderRadius: BorderRadius.circular(999),
                        border: Border.all(color: subtleBorder),
                      ),
                      child: Row(
                        children: const [
                          Icon(Icons.signal_cellular_4_bar_rounded, size: 16, color: Color(0xFF4E8D7A)),
                          SizedBox(width: 6),
                          Text('Connected', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: Color(0xFF2A4E45))),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 26),
                if (_selectedTab == 0) _buildCallPanel(),
                if (_selectedTab == 1) _buildContactsPanel(),
                if (_selectedTab == 2) _buildCallHistoryPanel(),
              ],
            ),
          ),
        ),
      );

  Widget _buildCallPanel() => LayoutBuilder(
        builder: (context, constraints) {
          final compactRow = constraints.maxWidth < 980;
          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (compactRow)
                Column(
                  children: [
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(22),
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.75),
                        borderRadius: BorderRadius.circular(30),
                        border: Border.all(color: subtleBorder),
                        boxShadow: const [BoxShadow(color: Color(0x0F0F172A), blurRadius: 18, offset: Offset(0, 8))],
                      ),
                      child: _buildDialPadBody(),
                    ),
                    const SizedBox(height: 20),
                    _buildQuickPanel(),
                  ],
                )
              else
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: Container(
                        padding: const EdgeInsets.all(22),
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: 0.75),
                          borderRadius: BorderRadius.circular(30),
                          border: Border.all(color: subtleBorder),
                          boxShadow: const [BoxShadow(color: Color(0x0F0F172A), blurRadius: 18, offset: Offset(0, 8))],
                        ),
                        child: _buildDialPadBody(),
                      ),
                    ),
                    const SizedBox(width: 20),
                    SizedBox(
                      width: 290,
                      child: _buildQuickPanel(),
                    ),
                  ],
                ),
            ],
          );
        },
      );

  Widget _buildDialPadBody() => Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            const Text(
              'Dial pad',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w700,
                color: foreground,
              ),
            ),
            const Spacer(),
            if (_isCalling)
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 5,
                ),
                decoration: BoxDecoration(
                  color: const Color(0xFFFDECEC),
                  borderRadius: BorderRadius.circular(999),
                ),
                child: const Text(
                  'Calling…',
                  style: TextStyle(
                    color: danger,
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
          ],
        ),

        const SizedBox(height: 12),

        // Number input
        TextField(
          controller: _numberController,
          textAlign: TextAlign.center,
          keyboardType: TextInputType.phone,
          style: const TextStyle(
            fontSize: 24,
            letterSpacing: 1.5,
            fontWeight: FontWeight.w700,
            color: foreground,
          ),
          decoration: InputDecoration(
            hintText: 'Enter number',
            hintStyle: const TextStyle(
              fontSize: 17,
              color: Color(0xFF9AA6AE),
              letterSpacing: 0,
            ),
            filled: true,
            fillColor: const Color(0xFFF7F7F5),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(16),
              borderSide: BorderSide.none,
            ),
            contentPadding: const EdgeInsets.symmetric(
              vertical: 13,
            ),
          ),
        ),

        const SizedBox(height: 8),

        // Compact Dial Pad
        GridView.count(
          shrinkWrap: true,
          crossAxisCount: 3,

          // Increased ratio = shorter buttons
          childAspectRatio: 3.6,

          mainAxisSpacing: 6,
          crossAxisSpacing: 6,

          physics: const NeverScrollableScrollPhysics(),

          children: [
            '1',
            '2',
            '3',
            '4',
            '5',
            '6',
            '7',
            '8',
            '9',
            '*',
            '0',
            '#',
          ].map(
            (digit) => InkWell(
              borderRadius: BorderRadius.circular(10),
              onTap: () => _addDigit(digit),
              child: Container(
                decoration: BoxDecoration(
                  color: const Color(0xFFF7F7F4),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(
                    color: const Color(0xFFEAE5DF),
                  ),
                ),
                child: Center(
                  child: Text(
                    digit,
                    style: const TextStyle(
                      fontSize: 17,
                      color: foreground,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ),
            ),
          ).toList(),
        ),

        const SizedBox(height: 10),

        // Call / Clear buttons
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            _actionButton(
              Icons.backspace_rounded,
              'Clear',
              const Color(0xFF6F7E88),
              () => setState(
                () => _numberController.clear(),
              ),
            ),

            const SizedBox(width: 12),

            _callActionButton(
              _isCalling
                  ? Icons.call_end_rounded
                  : Icons.call_rounded,
              _isCalling ? 'End' : 'Call',
              _isCalling ? danger : accent,
              () => _isCalling
                  ? setState(() => _isCalling = false)
                  : _startCall(),
            ),
          ],
        ),
      ],
    );

  Widget _buildQuickPanel() => Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.75),
          borderRadius: BorderRadius.circular(28),
          border: Border.all(color: subtleBorder),
          boxShadow: const [BoxShadow(color: Color(0x0F0F172A), blurRadius: 18, offset: Offset(0, 8))],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Quick actions', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700, color: foreground)),
            const SizedBox(height: 16),
            _miniAction(Icons.voicemail_rounded, 'Voicemail', '03 new'),
            const SizedBox(height: 12),
            _miniAction(Icons.groups_rounded, 'Team', '8 online'),
            const SizedBox(height: 12),
            _miniAction(Icons.schedule_rounded, 'Availability', 'Ready'),
            const SizedBox(height: 18),
            const Divider(color: Color(0xFFE8E3DE)),
            const SizedBox(height: 18),
            const Text('Status', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: muted)),
            const SizedBox(height: 12),
            Row(
              children: const [
                Icon(Icons.circle, size: 10, color: mint),
                SizedBox(width: 8),
                Text('System healthy', style: TextStyle(color: Color(0xFF2F5149), fontWeight: FontWeight.w600)),
              ],
            ),
          ],
        ),
      );

  Widget _miniAction(IconData icon, String title, String desc) => Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(color: const Color(0xFFF7F7F4), borderRadius: BorderRadius.circular(18), border: Border.all(color: const Color(0xFFEAE5DF))),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(color: accentSoft, borderRadius: BorderRadius.circular(12)),
              child: Icon(icon, color: accent, size: 18),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: foreground)),
                  Text(desc, style: const TextStyle(fontSize: 12, color: muted)),
                ],
              ),
            ),
          ],
        ),
      );

  Widget _buildContactsPanel() => Container(
        padding: const EdgeInsets.all(22),
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.75),
          borderRadius: BorderRadius.circular(28),
          border: Border.all(color: subtleBorder),
          boxShadow: const [BoxShadow(color: Color(0x0F0F172A), blurRadius: 18, offset: Offset(0, 8))],
        ),
        child: Column(
          children: [
            Row(
              children: [
                const Text('Contacts', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700, color: foreground)),
                const Spacer(),
                IconButton(
                  onPressed: () {},
                  icon: const Icon(Icons.person_add_alt_1_rounded, color: accent),
                  tooltip: 'Add contact',
                ),
              ],
            ),
            const SizedBox(height: 8),
            TextField(
              controller: _searchController,
              decoration: InputDecoration(
                prefixIcon: const Icon(Icons.search_rounded, color: muted),
                hintText: 'Search contacts',
              ),
            ),
            const SizedBox(height: 24),
            const SizedBox(
              height: 180,
              child: Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.people_alt_rounded, size: 44, color: Color(0xFF9AA9AF)),
                    SizedBox(height: 12),
                    Text('No contacts yet', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700, color: Color(0xFF53616B))),
                    SizedBox(height: 6),
                    Text('Add a contact to start dialing faster.', style: TextStyle(color: Color(0xFF7D8B93), fontSize: 13)),
                  ],
                ),
              ),
            ),
          ],
        ),
      );

  Widget _buildCallHistoryPanel() => Container(
        padding: const EdgeInsets.all(22),
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.75),
          borderRadius: BorderRadius.circular(28),
          border: Border.all(color: subtleBorder),
          boxShadow: const [BoxShadow(color: Color(0x0F0F172A), blurRadius: 18, offset: Offset(0, 8))],
        ),
        child: Column(
          children: [
            Row(
              children: [
                const Text('Recent calls', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700, color: foreground)),
                const Spacer(),
                IconButton(
                  onPressed: _authToken == null ? null : () => _loadRecentCalls(_authToken!),
                  icon: const Icon(Icons.refresh_rounded, color: accent),
                  tooltip: 'Refresh call history',
                ),
              ],
            ),
            const SizedBox(height: 14),
            if (_serverRecentCalls.isEmpty)
              const SizedBox(
                height: 180,
                child: Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.history_rounded, size: 44, color: Color(0xFF9AA9AF)),
                      SizedBox(height: 12),
                      Text('No recent calls', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700, color: Color(0xFF53616B))),
                      SizedBox(height: 6),
                      Text('Your call history will appear here.', style: TextStyle(color: Color(0xFF7D8B93), fontSize: 13)),
                    ],
                  ),
                ),
              )
            else
              ..._serverRecentCalls.take(8).map(
                (call) => Container(
                  margin: const EdgeInsets.only(bottom: 10),
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(16),
                    color: const Color(0xFFF7F7F4),
                    border: Border.all(color: const Color(0xFFEAE5DF)),
                  ),
                  child: Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          color: call.direction == 'missed' ? const Color(0xFFFDECEC) : const Color(0xFFEAF8F1),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Icon(
                          call.direction == 'missed'
                              ? Icons.call_missed_rounded
                              : call.direction == 'incoming'
                                  ? Icons.call_received_rounded
                                  : Icons.call_made_rounded,
                          color: call.direction == 'missed' ? danger : const Color(0xFF2D7B5F),
                          size: 18,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(call.name, style: const TextStyle(fontWeight: FontWeight.w600, color: foreground)),
                            const SizedBox(height: 4),
                            Text(call.time, style: const TextStyle(fontSize: 12, color: muted)),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
          ],
        ),
      );

  Widget _actionButton(IconData icon, String label, Color color, VoidCallback onTap) => InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Container(
          width: 110,
          padding: const EdgeInsets.symmetric(vertical: 12),
          decoration: BoxDecoration(
            color: const Color(0xFFF7F7F5),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: const Color(0xFFEAE5DF)),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon, size: 18, color: color),
              const SizedBox(width: 8),
              Text(label, style: TextStyle(color: color, fontWeight: FontWeight.w600, fontSize: 14)),
            ],
          ),
        ),
      );

  Widget _callActionButton(IconData icon, String label, Color color, VoidCallback onTap) => InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(18),
        child: Container(
          width: 150,
          padding: const EdgeInsets.symmetric(vertical: 15),
          decoration: BoxDecoration(
            color: color,
            borderRadius: BorderRadius.circular(18),
            boxShadow: [BoxShadow(color: color.withValues(alpha: 0.28), blurRadius: 18, offset: const Offset(0, 10))],
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon, size: 20, color: Colors.white),
              const SizedBox(width: 8),
              Text(label, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w700, fontSize: 15)),
            ],
          ),
        ),
      );
}
