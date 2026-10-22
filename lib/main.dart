import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:image_picker/image_picker.dart';

import 'services/api_service.dart';

void main() {
  runApp(const LaporSaranaApp());
}

const maroon = Color(0xFF800020);
const cream = Color(0xFFFFF7EB);
const pageBg = Color(0xFFF8F7F5);

// ============================================================
// MODEL
// ============================================================

class Account {
  final int id;
  final String name;
  final String username;
  final String password;
  final String role;

  Account({
    this.id = 0,
    required this.name,
    required this.username,
    required this.password,
    required this.role,
  });
}

class Complaint {
  final int id;
  final int userId;
  final String title;
  final String location;
  final String description;
  final Uint8List? photo;
  final String? photoPath;
  String status;
  String response;
  String? feedback;

  Complaint({
    this.id = 0,
    this.userId = 0,
    required this.title,
    required this.location,
    required this.description,
    this.photo,
    this.photoPath,
    this.status = 'Pending',
    this.response = '',
    this.feedback,
  });

  // Membuat URL foto berdasarkan path dari database.
  String? get photoUrl {
    final path = photoPath?.trim();

    if (path == null || path.isEmpty || path.toLowerCase() == 'null') {
      return null;
    }

    if (path.startsWith('http://') || path.startsWith('https://')) {
      return path;
    }

    final cleanPath = path
        .replaceAll(r'\', '/')
        .replaceFirst(RegExp(r'^/+'), '');

    return '${ApiService.baseUrl}/$cleanPath';
  }
}

class NotificationItem {
  final int id;
  final int complaintId;
  final String title;
  final String message;
  final bool isRead;
  final String createdAt;

  const NotificationItem({
    required this.id,
    required this.complaintId,
    required this.title,
    required this.message,
    required this.isRead,
    required this.createdAt,
  });

  factory NotificationItem.fromJson(Map<String, dynamic> json) {
    return NotificationItem(
      id: int.tryParse(json['id']?.toString() ?? '') ?? 0,
      complaintId: int.tryParse(json['complaint_id']?.toString() ?? '') ?? 0,
      title: json['title']?.toString() ?? 'Pembaruan Pengaduan',
      message: json['message']?.toString() ?? '',
      isRead: json['is_read']?.toString() == '1' || json['is_read'] == true,
      createdAt: json['created_at']?.toString() ?? '',
    );
  }
}

// ============================================================
// APLIKASI
// ============================================================

class LaporSaranaApp extends StatelessWidget {
  const LaporSaranaApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'LaporSarana',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        useMaterial3: true,
        scaffoldBackgroundColor: pageBg,
        colorScheme: ColorScheme.fromSeed(seedColor: maroon),
        appBarTheme: const AppBarTheme(
          backgroundColor: maroon,
          foregroundColor: Colors.white,
        ),
        inputDecorationTheme: InputDecorationTheme(
          filled: true,
          fillColor: cream,
          contentPadding: const EdgeInsets.all(16),
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: const BorderSide(color: Color(0xFFD8C8BD)),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: const BorderSide(color: maroon, width: 1.5),
          ),
        ),
      ),
      home: const LoginPage(),
    );
  }
}

// ============================================================
// WIDGET FOTO
// Digunakan di dashboard dan halaman detail.
// ============================================================

class ComplaintPhoto extends StatelessWidget {
  final String? photoUrl;
  final double width;
  final double height;
  final double borderRadius;

  const ComplaintPhoto({
    super.key,
    required this.photoUrl,
    this.width = double.infinity,
    this.height = 220,
    this.borderRadius = 12,
  });

  @override
  Widget build(BuildContext context) {
    final url = photoUrl?.trim();

    if (url == null || url.isEmpty) {
      return _placeholder('Foto belum tersedia');
    }

    return ClipRRect(
      borderRadius: BorderRadius.circular(borderRadius),
      child: Image.network(
        url,
        width: width,
        height: height,
        fit: BoxFit.cover,
        loadingBuilder: (context, child, progress) {
          if (progress == null) return child;

          return Container(
            width: width,
            height: height,
            color: const Color(0xFFF0E9E5),
            alignment: Alignment.center,
            child: const CircularProgressIndicator(
              color: maroon,
              strokeWidth: 2,
            ),
          );
        },
        errorBuilder: (context, error, stackTrace) {
          debugPrint('URL foto bukti: $url');
          debugPrint('Gagal memuat foto: $error');

          return _placeholder('Foto tidak dapat ditampilkan');
        },
      ),
    );
  }

  Widget _placeholder(String message) {
    return Container(
      width: width,
      height: height,
      decoration: BoxDecoration(
        color: const Color(0xFFF0E9E5),
        borderRadius: BorderRadius.circular(borderRadius),
      ),
      alignment: Alignment.center,
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(Icons.broken_image_outlined, color: maroon, size: 28),
          const SizedBox(height: 5),
          Text(
            message,
            textAlign: TextAlign.center,
            style: const TextStyle(fontSize: 11, color: Colors.black54),
          ),
        ],
      ),
    );
  }
}

// ============================================================
// LOGIN
// ============================================================

class LoginPage extends StatefulWidget {
  const LoginPage({super.key});

  @override
  State<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> {
  final formKey = GlobalKey<FormState>();
  final usernameController = TextEditingController();
  final passwordController = TextEditingController();

  bool hidePassword = true;
  bool loading = false;

  Future<void> login() async {
    if (!formKey.currentState!.validate() || loading) return;

    setState(() => loading = true);

    try {
      final result = await ApiService.login(
        username: usernameController.text.trim(),
        password: passwordController.text,
      );

      if (!mounted) return;

      if (result['success'] == true) {
        final user = result['user'];

        if (user is! Map) {
          _showMessage('Data akun dari server tidak valid.');
          return;
        }

        final id = int.tryParse(user['id']?.toString() ?? '');

        if (id == null || id <= 0) {
          _showMessage('ID akun tidak valid. Periksa auth.php.');
          return;
        }

        final account = Account(
          id: id,
          name: user['name']?.toString() ?? '',
          username:
              user['username']?.toString() ?? usernameController.text.trim(),
          password: passwordController.text,
          role: user['role']?.toString() ?? 'Pelapor',
        );

        Navigator.pushReplacement(
          context,
          MaterialPageRoute(builder: (_) => DashboardPage(account: account)),
        );
      } else {
        _showMessage(result['message']?.toString() ?? 'Login gagal.');
      }
    } catch (e) {
      if (mounted) {
        _showMessage('Gagal menghubungi server. Periksa XAMPP.');
      }
    } finally {
      if (mounted) setState(() => loading = false);
    }
  }

  void _showMessage(String message) {
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message)));
  }

  @override
  void dispose() {
    usernameController.dispose();
    passwordController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: cream,
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 600),
              child: Form(
                key: formKey,
                child: Column(
                  children: [
                    Container(
                      width: 100,
                      height: 100,
                      decoration: BoxDecoration(
                        color: maroon,
                        borderRadius: BorderRadius.circular(24),
                      ),
                      child: const Icon(
                        Icons.apartment_rounded,
                        color: Colors.white,
                        size: 52,
                      ),
                    ),
                    const SizedBox(height: 22),
                    const Text(
                      'LaporSarana',
                      style: TextStyle(
                        fontSize: 30,
                        fontWeight: FontWeight.bold,
                        color: maroon,
                      ),
                    ),
                    const SizedBox(height: 8),
                    const Text('Sistem Pengaduan Sarana Sekolah'),
                    const SizedBox(height: 34),
                    TextFormField(
                      controller: usernameController,
                      decoration: const InputDecoration(
                        labelText: 'Username',
                        prefixIcon: Icon(Icons.person_outline),
                      ),
                      validator: (v) => v == null || v.trim().isEmpty
                          ? 'Username wajib diisi'
                          : null,
                    ),
                    const SizedBox(height: 14),
                    TextFormField(
                      controller: passwordController,
                      obscureText: hidePassword,
                      decoration: InputDecoration(
                        labelText: 'Password',
                        prefixIcon: const Icon(Icons.lock_outline),
                        suffixIcon: IconButton(
                          onPressed: () =>
                              setState(() => hidePassword = !hidePassword),
                          icon: Icon(
                            hidePassword
                                ? Icons.visibility_outlined
                                : Icons.visibility_off_outlined,
                          ),
                        ),
                      ),
                      validator: (v) => v == null || v.isEmpty
                          ? 'Password wajib diisi'
                          : null,
                      onFieldSubmitted: (_) => login(),
                    ),
                    const SizedBox(height: 24),
                    SizedBox(
                      width: double.infinity,
                      height: 52,
                      child: FilledButton(
                        onPressed: loading ? null : login,
                        style: FilledButton.styleFrom(
                          backgroundColor: maroon,
                          foregroundColor: Colors.white,
                        ),
                        child: loading
                            ? const CircularProgressIndicator(
                                color: Colors.white,
                              )
                            : const Text('Masuk'),
                      ),
                    ),
                    const SizedBox(height: 18),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Text('Belum punya akun?'),
                        TextButton(
                          onPressed: () async {
                            final registered = await Navigator.push<bool>(
                              context,
                              MaterialPageRoute(
                                builder: (_) => const RegisterPage(),
                              ),
                            );

                            if (registered == true && mounted) {
                              _showMessage(
                                'Pendaftaran berhasil. Silakan login.',
                              );
                            }
                          },
                          child: const Text(
                            'Daftar sekarang',
                            style: TextStyle(color: maroon),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 10),
                    const Text(
                      'Akun Admin harus tersedia di database.',
                      style: TextStyle(fontSize: 12, color: Colors.black54),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

// ============================================================
// REGISTER PELAPOR
// ============================================================

class RegisterPage extends StatefulWidget {
  const RegisterPage({super.key});

  @override
  State<RegisterPage> createState() => _RegisterPageState();
}

class _RegisterPageState extends State<RegisterPage> {
  final formKey = GlobalKey<FormState>();
  final nameController = TextEditingController();
  final usernameController = TextEditingController();
  final passwordController = TextEditingController();
  final confirmController = TextEditingController();

  bool loading = false;
  bool hidePassword = true;

  Future<void> register() async {
    if (!formKey.currentState!.validate() || loading) return;

    setState(() => loading = true);

    try {
      final result = await ApiService.register(
        name: nameController.text.trim(),
        username: usernameController.text.trim(),
        password: passwordController.text,
      );

      if (!mounted) return;

      if (result['success'] == true) {
        Navigator.pop(context, true);
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              result['message']?.toString() ?? 'Pendaftaran gagal.',
            ),
          ),
        );
      }
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Gagal menghubungi server.')),
        );
      }
    } finally {
      if (mounted) setState(() => loading = false);
    }
  }

  @override
  void dispose() {
    nameController.dispose();
    usernameController.dispose();
    passwordController.dispose();
    confirmController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Daftar Akun Pelapor')),
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(22),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 600),
            child: Form(
              key: formKey,
              child: Column(
                children: [
                  TextFormField(
                    controller: nameController,
                    decoration: const InputDecoration(
                      labelText: 'Nama lengkap',
                    ),
                    validator: (v) => v == null || v.trim().isEmpty
                        ? 'Nama wajib diisi'
                        : null,
                  ),
                  const SizedBox(height: 14),
                  TextFormField(
                    controller: usernameController,
                    decoration: const InputDecoration(labelText: 'Username'),
                    validator: (v) => v == null || v.trim().isEmpty
                        ? 'Username wajib diisi'
                        : null,
                  ),
                  const SizedBox(height: 14),
                  TextFormField(
                    controller: passwordController,
                    obscureText: hidePassword,
                    decoration: InputDecoration(
                      labelText: 'Password',
                      suffixIcon: IconButton(
                        onPressed: () =>
                            setState(() => hidePassword = !hidePassword),
                        icon: Icon(
                          hidePassword
                              ? Icons.visibility_outlined
                              : Icons.visibility_off_outlined,
                        ),
                      ),
                    ),
                    validator: (v) => v == null || v.length < 8
                        ? 'Password minimal 8 karakter'
                        : null,
                  ),
                  const SizedBox(height: 14),
                  TextFormField(
                    controller: confirmController,
                    obscureText: true,
                    decoration: const InputDecoration(
                      labelText: 'Konfirmasi password',
                    ),
                    validator: (v) => v != passwordController.text
                        ? 'Password belum sama'
                        : null,
                  ),
                  const SizedBox(height: 22),
                  SizedBox(
                    width: double.infinity,
                    child: FilledButton(
                      onPressed: loading ? null : register,
                      style: FilledButton.styleFrom(
                        backgroundColor: maroon,
                        foregroundColor: Colors.white,
                      ),
                      child: Text(loading ? 'Mendaftar...' : 'Daftar'),
                    ),
                  ),
                  const SizedBox(height: 12),
                  const Text(
                    'Pendaftaran ini hanya untuk Pelapor. '
                    'Admin menggunakan akun yang telah dibuat.',
                    textAlign: TextAlign.center,
                    style: TextStyle(fontSize: 12),
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

// ============================================================
// DASHBOARD
// ============================================================

class DashboardPage extends StatefulWidget {
  final Account account;

  const DashboardPage({super.key, required this.account});

  @override
  State<DashboardPage> createState() => _DashboardPageState();
}

class _DashboardPageState extends State<DashboardPage> {
  bool get isAdmin =>
      widget.account.role.trim().toLowerCase() == 'admin' ||
      widget.account.role.trim().toLowerCase() == 'sarpras';

  bool loading = true;
  String? errorMessage;
  List<Complaint> items = [];
  List<NotificationItem> notifications = [];
  bool loadingNotifications = false;

  @override
  void initState() {
    super.initState();
    loadComplaints();
    if (!isAdmin) loadNotifications();
  }

  Future<void> loadComplaints() async {
    if (mounted) {
      setState(() {
        loading = true;
        errorMessage = null;
      });
    }

    try {
      final result = await ApiService.getComplaints(
        userId: widget.account.id,
        role: widget.account.role,
      );

      if (!mounted) return;

      if (result['success'] != true) {
        setState(() {
          errorMessage =
              result['message']?.toString() ?? 'Pengaduan gagal dimuat.';
          loading = false;
        });
        return;
      }

      final data = result['data'];
      final parsed = <Complaint>[];

      if (data is List) {
        for (final item in data) {
          if (item is! Map) continue;

          parsed.add(
            Complaint(
              id: int.tryParse(item['id']?.toString() ?? '') ?? 0,
              userId: int.tryParse(item['user_id']?.toString() ?? '') ?? 0,
              title: item['title']?.toString() ?? '',
              location: item['location']?.toString() ?? '',
              description: item['description']?.toString() ?? '',
              photoPath: item['photo_path']?.toString(),
              status: item['status']?.toString() ?? 'Pending',
              response: item['response']?.toString() ?? '',
            ),
          );
        }
      }

      setState(() {
        items = parsed;
        loading = false;
      });
    } catch (e) {
      if (!mounted) return;

      setState(() {
        errorMessage = 'Tidak dapat mengambil data dari server.';
        loading = false;
      });

      debugPrint('Gagal memuat pengaduan: $e');
    }
  }

  Future<void> loadNotifications() async {
    if (isAdmin || loadingNotifications) return;

    setState(() => loadingNotifications = true);

    try {
      final uri = Uri.parse(
        '${ApiService.baseUrl}/notifications.php',
      ).replace(queryParameters: {'user_id': widget.account.id.toString()});

      final response = await http
          .get(uri, headers: const {'Accept': 'application/json'})
          .timeout(const Duration(seconds: 15));

      final result = jsonDecode(response.body);

      if (!mounted) return;

      if (response.statusCode >= 200 &&
          response.statusCode < 300 &&
          result is Map &&
          result['success'] == true &&
          result['data'] is List) {
        setState(() {
          notifications = (result['data'] as List)
              .whereType<Map>()
              .map(
                (item) =>
                    NotificationItem.fromJson(Map<String, dynamic>.from(item)),
              )
              .toList();
        });
      }
    } catch (e) {
      debugPrint('Notifikasi belum dapat dimuat: $e');
    } finally {
      if (mounted) setState(() => loadingNotifications = false);
    }
  }

  Future<void> openPage(Widget page) async {
    await Navigator.push(context, MaterialPageRoute(builder: (_) => page));

    if (!mounted) return;

    await loadComplaints();

    if (!isAdmin) await loadNotifications();
  }

  Future<void> openNotifications() async {
    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => NotificationsPage(
          account: widget.account,
          initialNotifications: notifications,
        ),
      ),
    );

    if (!mounted) return;

    await loadNotifications();
    await loadComplaints();
  }

  @override
  Widget build(BuildContext context) {
    final pending = items
        .where((c) => c.status.toLowerCase() == 'pending')
        .length;
    final process = items
        .where((c) => c.status.toLowerCase() == 'proses')
        .length;
    final done = items.where((c) => c.status.toLowerCase() == 'selesai').length;
    final unread = notifications.where((n) => !n.isRead).length;

    return Scaffold(
      appBar: AppBar(
        title: const Text('LaporSarana'),
        actions: [
          if (!isAdmin)
            IconButton(
              tooltip: 'Notifikasi',
              onPressed: openNotifications,
              icon: Badge(
                isLabelVisible: unread > 0,
                label: Text(unread > 99 ? '99+' : '$unread'),
                child: const Icon(Icons.notifications_outlined),
              ),
            ),
          IconButton(
            tooltip: 'Muat ulang',
            onPressed: () async {
              await loadComplaints();
              if (!isAdmin) await loadNotifications();
            },
            icon: const Icon(Icons.refresh),
          ),
          IconButton(
            tooltip: 'Keluar',
            onPressed: () {
              Navigator.pushAndRemoveUntil(
                context,
                MaterialPageRoute(builder: (_) => const LoginPage()),
                (_) => false,
              );
            },
            icon: const Icon(Icons.logout),
          ),
        ],
      ),
      floatingActionButton: !isAdmin
          ? FloatingActionButton.extended(
              backgroundColor: maroon,
              foregroundColor: Colors.white,
              onPressed: () =>
                  openPage(AddComplaintPage(account: widget.account)),
              icon: const Icon(Icons.add),
              label: const Text('Buat Laporan'),
            )
          : null,
      body: RefreshIndicator(
        onRefresh: () async {
          await loadComplaints();
          if (!isAdmin) await loadNotifications();
        },
        child: ListView(
          padding: const EdgeInsets.all(18),
          children: [
            Container(
              padding: const EdgeInsets.all(22),
              decoration: BoxDecoration(
                color: maroon,
                borderRadius: BorderRadius.circular(20),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Halo, ${widget.account.name}!',
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 23,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    isAdmin
                        ? 'Kelola pengaduan sarana sekolah.'
                        : 'Pantau laporan dan pembaruan status pengaduanmu.',
                    style: const TextStyle(color: Colors.white70),
                  ),
                  if (!isAdmin) ...[
                    const SizedBox(height: 14),
                    OutlinedButton.icon(
                      onPressed: openNotifications,
                      icon: const Icon(
                        Icons.notifications_active_outlined,
                        color: Colors.white,
                      ),
                      label: Text(
                        unread > 0
                            ? '$unread notifikasi belum dibaca'
                            : 'Lihat notifikasi',
                        style: const TextStyle(color: Colors.white),
                      ),
                      style: OutlinedButton.styleFrom(
                        side: const BorderSide(color: Colors.white70),
                      ),
                    ),
                  ],
                ],
              ),
            ),
            const SizedBox(height: 22),
            const Text(
              'Ringkasan Pengaduan',
              style: TextStyle(fontSize: 19, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: StatCard(
                    label: 'Pending',
                    count: pending,
                    color: Colors.orange,
                    icon: Icons.schedule,
                  ),
                ),
                const SizedBox(width: 9),
                Expanded(
                  child: StatCard(
                    label: 'Proses',
                    count: process,
                    color: Colors.blue,
                    icon: Icons.handyman_outlined,
                  ),
                ),
                const SizedBox(width: 9),
                Expanded(
                  child: StatCard(
                    label: 'Selesai',
                    count: done,
                    color: Colors.green,
                    icon: Icons.check_circle_outline,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 26),
            const Text(
              'Daftar Pengaduan',
              style: TextStyle(fontSize: 19, fontWeight: FontWeight.bold),
            ),
            if (loading)
              const Padding(
                padding: EdgeInsets.all(28),
                child: Center(child: CircularProgressIndicator()),
              )
            else if (errorMessage != null)
              Padding(
                padding: const EdgeInsets.only(top: 14),
                child: Column(
                  children: [
                    Text(errorMessage!, textAlign: TextAlign.center),
                    const SizedBox(height: 12),
                    FilledButton(
                      onPressed: loadComplaints,
                      child: const Text('Coba lagi'),
                    ),
                  ],
                ),
              )
            else if (items.isEmpty)
              const Padding(
                padding: EdgeInsets.all(28),
                child: Column(
                  children: [
                    Icon(Icons.inbox_outlined, size: 46, color: maroon),
                    SizedBox(height: 10),
                    Text('Belum ada pengaduan.'),
                  ],
                ),
              )
            else
              ...items.map(
                (complaint) => Card(
                  color: Colors.white,
                  margin: const EdgeInsets.only(top: 10),
                  child: ListTile(
                    contentPadding: const EdgeInsets.all(12),

                    // FOTO BUKTI MUNCUL DI DASHBOARD.
                    leading: complaint.photoUrl != null
                        ? ComplaintPhoto(
                            photoUrl: complaint.photoUrl,
                            width: 68,
                            height: 68,
                            borderRadius: 10,
                          )
                        : const CircleAvatar(
                            backgroundColor: Color(0xFFF4E5E8),
                            child: Icon(
                              Icons.report_problem_outlined,
                              color: maroon,
                            ),
                          ),

                    title: Text(
                      complaint.title,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(fontWeight: FontWeight.bold),
                    ),
                    subtitle: Padding(
                      padding: const EdgeInsets.only(top: 7),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(complaint.location),
                          const SizedBox(height: 7),
                          StatusChip(status: complaint.status),
                        ],
                      ),
                    ),
                    trailing: const Icon(Icons.chevron_right),
                    onTap: () => openPage(
                      DetailPage(complaint: complaint, account: widget.account),
                    ),
                  ),
                ),
              ),
            const SizedBox(height: 90),
          ],
        ),
      ),
    );
  }
}

// ============================================================
// KARTU RINGKASAN
// ============================================================

class StatCard extends StatelessWidget {
  final String label;
  final int count;
  final Color color;
  final IconData icon;

  const StatCard({
    super.key,
    required this.label,
    required this.count,
    required this.color,
    required this.icon,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 15, horizontal: 5),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(15),
      ),
      child: Column(
        children: [
          Icon(icon, color: color, size: 25),
          const SizedBox(height: 7),
          Text(
            '$count',
            style: TextStyle(
              color: color,
              fontSize: 23,
              fontWeight: FontWeight.bold,
            ),
          ),
          Text(label, style: const TextStyle(fontSize: 11)),
        ],
      ),
    );
  }
}

// ============================================================
// STATUS PENGADUAN
// ============================================================

class StatusChip extends StatelessWidget {
  final String status;

  const StatusChip({super.key, required this.status});

  @override
  Widget build(BuildContext context) {
    final normalized = status.toLowerCase();

    final color = normalized.contains('selesai')
        ? Colors.green
        : normalized.contains('proses')
        ? Colors.blue
        : normalized.contains('tolak')
        ? Colors.red
        : Colors.orange;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        status,
        style: TextStyle(
          color: color,
          fontWeight: FontWeight.bold,
          fontSize: 12,
        ),
      ),
    );
  }
}

// ============================================================
// TAMBAH PENGADUAN
// ============================================================

class AddComplaintPage extends StatefulWidget {
  final Account account;

  const AddComplaintPage({super.key, required this.account});

  @override
  State<AddComplaintPage> createState() => _AddComplaintPageState();
}

class _AddComplaintPageState extends State<AddComplaintPage> {
  final formKey = GlobalKey<FormState>();
  final titleController = TextEditingController();
  final locationController = TextEditingController();
  final descriptionController = TextEditingController();

  Uint8List? photoBytes;
  String? photoName;
  bool submitting = false;
  final picker = ImagePicker();

  Future<void> pickPhoto(ImageSource source) async {
    try {
      final file = await picker.pickImage(source: source, imageQuality: 75);

      if (file == null) return;

      final bytes = await file.readAsBytes();

      if (mounted) {
        setState(() {
          photoBytes = bytes;
          photoName = file.name;
        });
      }
    } catch (e) {
      debugPrint('Gagal memilih foto: $e');

      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Foto tidak dapat dibuka. Coba pilih dari galeri.'),
        ),
      );
    }
  }

  void showPhotoOptions() {
    showModalBottomSheet(
      context: context,
      builder: (sheetContext) => SafeArea(
        child: Wrap(
          children: [
            ListTile(
              leading: const Icon(Icons.camera_alt_outlined),
              title: const Text('Ambil foto dari kamera'),
              onTap: () {
                Navigator.pop(sheetContext);
                pickPhoto(ImageSource.camera);
              },
            ),
            ListTile(
              leading: const Icon(Icons.photo_library_outlined),
              title: const Text('Pilih dari galeri'),
              onTap: () {
                Navigator.pop(sheetContext);
                pickPhoto(ImageSource.gallery);
              },
            ),
          ],
        ),
      ),
    );
  }

  Future<void> submit() async {
    if (!formKey.currentState!.validate() || submitting) return;

    if (widget.account.id <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('ID akun tidak valid. Silakan login ulang.'),
        ),
      );
      return;
    }

    setState(() => submitting = true);

    try {
      final result = await ApiService.createComplaint(
        userId: widget.account.id,
        title: titleController.text.trim(),
        location: locationController.text.trim(),
        description: descriptionController.text.trim(),
        photoBytes: photoBytes,
        photoName: photoName ?? 'foto_pengaduan.jpg',
      );

      if (!mounted) return;

      if (result['success'] == true) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Pengaduan berhasil dikirim.')),
        );
        Navigator.pop(context, true);
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              result['message']?.toString() ?? 'Pengaduan gagal dikirim.',
            ),
          ),
        );
      }
    } catch (e) {
      debugPrint('Gagal mengirim pengaduan: $e');

      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Gagal menghubungi server.')),
      );
    } finally {
      if (mounted) setState(() => submitting = false);
    }
  }

  @override
  void dispose() {
    titleController.dispose();
    locationController.dispose();
    descriptionController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Buat Pengaduan')),
      body: Form(
        key: formKey,
        child: ListView(
          padding: const EdgeInsets.all(18),
          children: [
            const Text(
              'Laporkan Kerusakan',
              style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            const Text('Lengkapi detail masalah sarana sekolah.'),
            const SizedBox(height: 24),
            TextFormField(
              controller: titleController,
              decoration: const InputDecoration(
                labelText: 'Judul Pengaduan',
                hintText: 'Contoh: Kursi kelas rusak',
              ),
              validator: (v) =>
                  v == null || v.trim().isEmpty ? 'Judul wajib diisi' : null,
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: locationController,
              decoration: const InputDecoration(
                labelText: 'Lokasi Sarana',
                prefixIcon: Icon(Icons.location_on_outlined),
              ),
              validator: (v) =>
                  v == null || v.trim().isEmpty ? 'Lokasi wajib diisi' : null,
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: descriptionController,
              maxLines: 4,
              decoration: const InputDecoration(
                labelText: 'Deskripsi Masalah',
                alignLabelWithHint: true,
              ),
              validator: (v) => v == null || v.trim().isEmpty
                  ? 'Deskripsi wajib diisi'
                  : null,
            ),
            const SizedBox(height: 20),
            const Text(
              'Foto Bukti',
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 10),
            InkWell(
              onTap: showPhotoOptions,
              borderRadius: BorderRadius.circular(14),
              child: Container(
                height: 190,
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: Colors.black12),
                ),
                clipBehavior: Clip.antiAlias,
                child: photoBytes == null
                    ? const Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            Icons.add_a_photo_outlined,
                            color: maroon,
                            size: 40,
                          ),
                          SizedBox(height: 10),
                          Text('Pilih foto kamera atau galeri'),
                        ],
                      )
                    : Image.memory(
                        photoBytes!,
                        fit: BoxFit.cover,
                        width: double.infinity,
                      ),
              ),
            ),
            if (photoBytes != null)
              Align(
                alignment: Alignment.centerRight,
                child: TextButton.icon(
                  onPressed: () {
                    setState(() {
                      photoBytes = null;
                      photoName = null;
                    });
                  },
                  icon: const Icon(Icons.delete_outline),
                  label: const Text('Hapus foto'),
                ),
              ),
            const SizedBox(height: 24),
            SizedBox(
              height: 50,
              child: FilledButton.icon(
                onPressed: submitting ? null : submit,
                style: FilledButton.styleFrom(
                  backgroundColor: maroon,
                  foregroundColor: Colors.white,
                ),
                icon: submitting
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Colors.white,
                        ),
                      )
                    : const Icon(Icons.send),
                label: Text(submitting ? 'Mengirim...' : 'Kirim Pengaduan'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ============================================================
// DETAIL PENGADUAN
// ============================================================

class DetailPage extends StatefulWidget {
  final Complaint complaint;
  final Account account;

  const DetailPage({super.key, required this.complaint, required this.account});

  @override
  State<DetailPage> createState() => _DetailPageState();
}

class _DetailPageState extends State<DetailPage> {
  late String status;
  late TextEditingController responseController;
  final feedbackController = TextEditingController();

  bool saving = false;

  bool get isAdmin =>
      widget.account.role.trim().toLowerCase() == 'admin' ||
      widget.account.role.trim().toLowerCase() == 'sarpras';

  @override
  void initState() {
    super.initState();
    status = widget.complaint.status;
    responseController = TextEditingController(text: widget.complaint.response);
    feedbackController.text = widget.complaint.feedback ?? '';
  }

  @override
  void dispose() {
    responseController.dispose();
    feedbackController.dispose();
    super.dispose();
  }

  Future<void> saveChanges() async {
    final complaint = widget.complaint;

    if (saving) return;

    if (widget.account.id <= 0 || complaint.id <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('ID Admin atau pengaduan tidak valid.')),
      );
      return;
    }

    setState(() => saving = true);

    try {
      final newResponse = responseController.text.trim();

      final result = await ApiService.updateComplaintStatus(
        adminId: widget.account.id,
        complaintId: complaint.id,
        status: status,
        response: newResponse,
      );

      if (!mounted) return;

      if (result['success'] == true) {
        setState(() {
          complaint.status = status;
          complaint.response = newResponse;
        });

        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Status berhasil disimpan ke database.'),
          ),
        );

        Navigator.pop(context, true);
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              result['message']?.toString() ?? 'Perubahan gagal disimpan.',
            ),
          ),
        );
      }
    } catch (e) {
      debugPrint('Gagal menyimpan status: $e');

      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Gagal menghubungi server. Periksa koneksi XAMPP.'),
        ),
      );
    } finally {
      if (mounted) setState(() => saving = false);
    }
  }

  Future<void> saveFeedback() async {
    if (feedbackController.text.trim().isEmpty) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Umpan balik wajib diisi.')));
      return;
    }

    setState(() => saving = true);

    try {
      final response = await http
          .post(
            Uri.parse('${ApiService.baseUrl}/complaints.php'),
            headers: const {
              'Content-Type': 'application/json; charset=UTF-8',
              'Accept': 'application/json',
            },
            body: jsonEncode({
              'action': 'submit_feedback',
              'user_id': widget.account.id,
              'complaint_id': widget.complaint.id,
              'feedback': feedbackController.text.trim(),
            }),
          )
          .timeout(const Duration(seconds: 20));

      final result = jsonDecode(response.body);

      if (!mounted) return;

      if (response.statusCode >= 200 &&
          response.statusCode < 300 &&
          result is Map &&
          result['success'] == true) {
        widget.complaint.feedback = feedbackController.text.trim();

        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Umpan balik berhasil disimpan.')),
        );

        Navigator.pop(context, true);
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              result is Map
                  ? result['message']?.toString() ??
                        'Umpan balik gagal disimpan.'
                  : 'Umpan balik gagal disimpan.',
            ),
          ),
        );
      }
    } catch (e) {
      debugPrint('Gagal menyimpan umpan balik: $e');

      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Gagal menghubungi server.')),
      );
    } finally {
      if (mounted) setState(() => saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final complaint = widget.complaint;

    return Scaffold(
      appBar: AppBar(title: const Text('Detail Pengaduan')),
      body: ListView(
        padding: const EdgeInsets.all(18),
        children: [
          Text(
            complaint.title,
            style: const TextStyle(fontSize: 25, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              const Icon(Icons.location_on_outlined, color: maroon),
              const SizedBox(width: 8),
              Expanded(child: Text(complaint.location)),
            ],
          ),
          const SizedBox(height: 20),
          const Text(
            'Status Pengaduan',
            style: TextStyle(fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 8),
          Align(
            alignment: Alignment.centerLeft,
            child: StatusChip(status: status),
          ),
          const SizedBox(height: 22),
          const Text(
            'Deskripsi',
            style: TextStyle(fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 8),
          Text(complaint.description),

          // FOTO BUKTI PADA DETAIL.
          if (complaint.photoUrl != null) ...[
            const SizedBox(height: 20),
            const Text(
              'Foto Bukti',
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 10),
            ComplaintPhoto(
              photoUrl: complaint.photoUrl,
              height: 250,
              width: double.infinity,
              borderRadius: 14,
            ),
            const SizedBox(height: 8),
            Text(
              'Path foto: ${complaint.photoPath}',
              style: const TextStyle(fontSize: 11, color: Colors.black54),
            ),
          ] else if (complaint.photo != null) ...[
            const SizedBox(height: 20),
            const Text(
              'Foto Bukti',
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 10),
            ClipRRect(
              borderRadius: BorderRadius.circular(14),
              child: Image.memory(
                complaint.photo!,
                height: 230,
                fit: BoxFit.cover,
              ),
            ),
          ],

          const SizedBox(height: 24),
          const Divider(),
          const SizedBox(height: 12),
          const Text(
            'Tanggapan Petugas',
            style: TextStyle(fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 8),
          Text(
            complaint.response.isEmpty
                ? 'Belum ada tanggapan dari petugas.'
                : complaint.response,
          ),

          if (isAdmin) ...[
            const SizedBox(height: 24),
            const Text(
              'Kelola Pengaduan',
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 10),
            DropdownButtonFormField<String>(
              value: status,
              decoration: const InputDecoration(labelText: 'Status'),
              items: const [
                DropdownMenuItem(value: 'Pending', child: Text('Pending')),
                DropdownMenuItem(value: 'Proses', child: Text('Proses')),
                DropdownMenuItem(value: 'Selesai', child: Text('Selesai')),
              ],
              onChanged: saving
                  ? null
                  : (value) {
                      if (value != null) {
                        setState(() => status = value);
                      }
                    },
            ),
            const SizedBox(height: 14),
            TextField(
              controller: responseController,
              maxLines: 3,
              decoration: const InputDecoration(
                labelText: 'Tanggapan / Tindakan',
              ),
            ),
            const SizedBox(height: 14),
            SizedBox(
              width: double.infinity,
              child: FilledButton.icon(
                onPressed: saving ? null : saveChanges,
                style: FilledButton.styleFrom(
                  backgroundColor: maroon,
                  foregroundColor: Colors.white,
                ),
                icon: saving
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(
                          color: Colors.white,
                          strokeWidth: 2,
                        ),
                      )
                    : const Icon(Icons.save_outlined),
                label: Text(saving ? 'Menyimpan...' : 'Simpan Perubahan'),
              ),
            ),
          ],

          if (!isAdmin && status.toLowerCase() == 'selesai') ...[
            const SizedBox(height: 24),
            const Text(
              'Umpan Balik',
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 10),
            TextField(
              controller: feedbackController,
              maxLines: 3,
              decoration: const InputDecoration(
                hintText: 'Tulis penilaian atau masukan...',
              ),
            ),
            const SizedBox(height: 12),
            FilledButton(
              onPressed: saving ? null : saveFeedback,
              style: FilledButton.styleFrom(
                backgroundColor: maroon,
                foregroundColor: Colors.white,
              ),
              child: Text(saving ? 'Menyimpan...' : 'Kirim Umpan Balik'),
            ),
          ],

          if (complaint.feedback != null) ...[
            const SizedBox(height: 16),
            Text('Umpan balik: ${complaint.feedback}'),
          ],
          const SizedBox(height: 30),
        ],
      ),
    );
  }
}

// ============================================================
// NOTIFIKASI PELAPOR
// ============================================================

class NotificationsPage extends StatefulWidget {
  final Account account;
  final List<NotificationItem> initialNotifications;

  const NotificationsPage({
    super.key,
    required this.account,
    required this.initialNotifications,
  });

  @override
  State<NotificationsPage> createState() => _NotificationsPageState();
}

class _NotificationsPageState extends State<NotificationsPage> {
  late List<NotificationItem> items;
  bool loading = false;

  @override
  void initState() {
    super.initState();
    items = List.of(widget.initialNotifications);
    loadNotifications();
  }

  Future<void> loadNotifications() async {
    setState(() => loading = true);

    try {
      final uri = Uri.parse(
        '${ApiService.baseUrl}/notifications.php',
      ).replace(queryParameters: {'user_id': widget.account.id.toString()});

      final response = await http
          .get(uri, headers: const {'Accept': 'application/json'})
          .timeout(const Duration(seconds: 15));

      final result = jsonDecode(response.body);

      if (!mounted) return;

      if (response.statusCode >= 200 &&
          response.statusCode < 300 &&
          result is Map &&
          result['success'] == true &&
          result['data'] is List) {
        setState(() {
          items = (result['data'] as List)
              .whereType<Map>()
              .map(
                (item) =>
                    NotificationItem.fromJson(Map<String, dynamic>.from(item)),
              )
              .toList();
        });
      }
    } catch (e) {
      debugPrint('Gagal memuat notifikasi: $e');
    } finally {
      if (mounted) setState(() => loading = false);
    }
  }

  Future<void> markAsRead(NotificationItem item) async {
    if (item.isRead) return;

    try {
      final response = await http
          .post(
            Uri.parse('${ApiService.baseUrl}/notifications.php'),
            headers: const {
              'Content-Type': 'application/json; charset=UTF-8',
              'Accept': 'application/json',
            },
            body: jsonEncode({
              'action': 'mark_read',
              'notification_id': item.id,
              'user_id': widget.account.id,
            }),
          )
          .timeout(const Duration(seconds: 15));

      final result = jsonDecode(response.body);

      if (response.statusCode >= 200 &&
          response.statusCode < 300 &&
          result is Map &&
          result['success'] == true) {
        await loadNotifications();
      }
    } catch (e) {
      debugPrint('Gagal menandai notifikasi: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    final unread = items.where((item) => !item.isRead).length;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Notifikasi'),
        actions: [
          IconButton(
            tooltip: 'Muat ulang',
            onPressed: loadNotifications,
            icon: const Icon(Icons.refresh),
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: loadNotifications,
        child: loading && items.isEmpty
            ? ListView(
                children: const [
                  SizedBox(height: 180),
                  Center(child: CircularProgressIndicator()),
                ],
              )
            : items.isEmpty
            ? ListView(
                children: const [
                  SizedBox(height: 100),
                  Icon(Icons.notifications_none, size: 58, color: maroon),
                  SizedBox(height: 12),
                  Center(child: Text('Belum ada notifikasi.')),
                  SizedBox(height: 12),
                  Center(
                    child: Text(
                      'Notifikasi muncul ketika Admin '
                      'memperbarui laporan.',
                      textAlign: TextAlign.center,
                    ),
                  ),
                ],
              )
            : ListView(
                padding: const EdgeInsets.all(16),
                children: [
                  Text(
                    unread > 0
                        ? '$unread notifikasi belum dibaca'
                        : 'Semua notifikasi sudah dibaca',
                    style: const TextStyle(fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 12),
                  ...items.map(
                    (item) => Card(
                      color: item.isRead
                          ? Colors.white
                          : const Color(0xFFFFF0F2),
                      child: ListTile(
                        leading: CircleAvatar(
                          backgroundColor: const Color(0xFFF4E5E8),
                          child: Icon(
                            item.isRead
                                ? Icons.notifications_none
                                : Icons.notifications_active,
                            color: maroon,
                          ),
                        ),
                        title: Text(
                          item.title,
                          style: TextStyle(
                            fontWeight: item.isRead
                                ? FontWeight.normal
                                : FontWeight.bold,
                          ),
                        ),
                        subtitle: Padding(
                          padding: const EdgeInsets.only(top: 6),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(item.message),
                              if (item.createdAt.isNotEmpty) ...[
                                const SizedBox(height: 6),
                                Text(
                                  item.createdAt,
                                  style: const TextStyle(fontSize: 11),
                                ),
                              ],
                            ],
                          ),
                        ),
                        trailing: item.isRead
                            ? const Icon(Icons.done, color: Colors.grey)
                            : const Icon(Icons.circle, color: maroon, size: 10),
                        onTap: () => markAsRead(item),
                      ),
                    ),
                  ),
                ],
              ),
      ),
    );
  }
}
