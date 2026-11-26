import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'data/kuaforum_feed_repository.dart';

const _inviteWine = Color(0xFF8E2947);
const _inviteBlush = Color(0xFFF7DDE3);
const _inviteInk = Color(0xFF39252C);
const _inviteMuted = Color(0xFF927B82);

class EmployeeInviteClaimPage extends StatefulWidget {
  final VoidCallback onClaimed;

  const EmployeeInviteClaimPage({super.key, required this.onClaimed});

  @override
  State<EmployeeInviteClaimPage> createState() => _EmployeeInviteClaimPageState();
}

class _EmployeeInviteClaimPageState extends State<EmployeeInviteClaimPage> {
  final repository = KuaforumFeedRepository();
  final emailController = TextEditingController();
  final passwordController = TextEditingController();
  final codeController = TextEditingController();
  bool submitting = false;
  bool obscurePassword = true;

  @override
  void dispose() {
    emailController.dispose();
    passwordController.dispose();
    codeController.dispose();
    super.dispose();
  }

  Future<void> claimInvite() async {
    final code = codeController.text.trim().toUpperCase();
    if (code.length != 10 || !RegExp(r'^[A-Z0-9]{10}$').hasMatch(code)) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('10 karakterli davet kodunu kontrol et.')),
      );
      return;
    }

    setState(() => submitting = true);
    final client = Supabase.instance.client;
    try {
      var user = client.auth.currentUser;
      if (user == null) {
        final email = emailController.text.trim();
        final password = passwordController.text;
        if (email.isEmpty || password.isEmpty) {
          throw AuthException('E-posta ve şifre alanlarını doldur.');
        }
        final response = await client.auth.signInWithPassword(
          email: email,
          password: password,
        );
        user = response.user;
        if (mounted) setState(() {});
      }
      if (user == null) {
        throw AuthException('Hesap oturumu açılamadı.');
      }

      final employeeId = await repository.claimEmployeeInvite(code);
      final linkedEmployee = await client
          .from('employees')
          .select('id')
          .eq('id', employeeId)
          .eq('user_id', user.id)
          .eq('is_active', true)
          .maybeSingle();
      final statusRows = await client.rpc('get_my_account_status') as List;
      final profile = statusRows.isEmpty
          ? null
          : Map<String, dynamic>.from(statusRows.first as Map);
      if (linkedEmployee == null ||
          profile == null ||
          profile['account_type'] != 'employee' ||
          profile['is_blocked'] == true) {
        throw AuthException(
          'Çalışan hesabı doğrulanamadı. İşletme yöneticinle iletişime geç.',
        );
      }

      if (!mounted) return;
      widget.onClaimed();
    } on AuthException catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(error.message), backgroundColor: _inviteWine),
        );
      }
    } on PostgrestException catch (error) {
      if (mounted) {
        final message = error.message.contains('Davet') ||
                error.message.contains('müşteri') ||
                error.message.contains('kısıtlandı')
            ? error.message
            : 'Davet kodu kullanılamadı. Kodun süresini ve daha önce kullanılmadığını kontrol et.';
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(message), backgroundColor: _inviteWine),
        );
      }
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('İşlem tamamlanamadı. İnternet bağlantını kontrol edip tekrar dene.'),
            backgroundColor: _inviteWine,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => submitting = false);
    }
  }

  Future<void> changeAccount() async {
    await Supabase.instance.client.auth.signOut();
    if (!mounted) return;
    emailController.clear();
    passwordController.clear();
    setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    final currentUser = Supabase.instance.client.auth.currentUser;
    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'Çalışan daveti',
          style: TextStyle(color: _inviteWine, fontWeight: FontWeight.w800),
        ),
      ),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(20, 12, 20, 28),
          children: [
            Container(
              padding: const EdgeInsets.all(22),
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [Color(0xFF8E2947), Color(0xFFC65B79)],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.circular(24),
              ),
              child: const Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(Icons.content_cut_rounded, color: Colors.white, size: 34),
                  SizedBox(height: 18),
                  Text(
                    'Ekibine katıl ♡',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 25,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                  SizedBox(height: 7),
                  Text(
                    'İşletme sahibinin sana verdiği 10 karakterli davet kodunu gir. Hesabın güvenli şekilde o işletmeye bağlansın.',
                    style: TextStyle(color: Colors.white, height: 1.45),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 22),
            if (currentUser == null) ...[
              const Text(
                'Önce hesabına giriş yap',
                style: TextStyle(
                  color: _inviteInk,
                  fontSize: 18,
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(height: 6),
              const Text(
                'Davetini kullanmak için kayıtlı müşteri hesabınla giriş yapmalısın.',
                style: TextStyle(color: _inviteMuted, height: 1.4),
              ),
              const SizedBox(height: 14),
              TextField(
                controller: emailController,
                keyboardType: TextInputType.emailAddress,
                autocorrect: false,
                decoration: const InputDecoration(
                  labelText: 'E-posta adresi',
                  prefixIcon: Icon(Icons.mail_outline_rounded),
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: passwordController,
                obscureText: obscurePassword,
                decoration: InputDecoration(
                  labelText: 'Şifre',
                  prefixIcon: const Icon(Icons.lock_outline_rounded),
                  border: const OutlineInputBorder(),
                  suffixIcon: IconButton(
                    onPressed: () =>
                        setState(() => obscurePassword = !obscurePassword),
                    icon: Icon(
                      obscurePassword
                          ? Icons.visibility_outlined
                          : Icons.visibility_off_outlined,
                    ),
                  ),
                ),
              ),
            ] else ...[
              const Text(
                'Giriş yapılan hesap',
                style: TextStyle(
                  color: _inviteInk,
                  fontSize: 18,
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(height: 8),
              Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: _inviteBlush),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.verified_user_outlined, color: _inviteWine),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        currentUser.email ?? 'Oturum açık',
                        style: const TextStyle(
                          color: _inviteInk,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                    TextButton(
                      onPressed: submitting ? null : changeAccount,
                      child: const Text('Değiştir'),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 8),
              const Text(
                'Davet kodu bu hesaba tanımlanacak. Hesabın müşteri hesabı olmalı.',
                style: TextStyle(color: _inviteMuted, fontSize: 12),
              ),
            ],
            const SizedBox(height: 22),
            const Text(
              'İşletme davet kodu',
              style: TextStyle(color: _inviteInk, fontWeight: FontWeight.w800),
            ),
            const SizedBox(height: 8),
            TextField(
              controller: codeController,
              textCapitalization: TextCapitalization.characters,
              textInputAction: TextInputAction.done,
              autocorrect: false,
              maxLength: 10,
              onChanged: (value) {
                final normalized =
                    value.toUpperCase().replaceAll(RegExp(r'[^A-Z0-9]'), '');
                if (normalized != value) {
                  codeController.value = TextEditingValue(
                    text: normalized,
                    selection: TextSelection.collapsed(
                      offset: normalized.length,
                    ),
                  );
                }
              },
              onSubmitted: (_) {
                if (!submitting) claimInvite();
              },
              decoration: const InputDecoration(
                hintText: 'ÖRN. 4A4605A229',
                prefixIcon: Icon(Icons.vpn_key_outlined),
                border: OutlineInputBorder(),
                counterText: '',
              ),
              style: const TextStyle(
                letterSpacing: 3,
                fontWeight: FontWeight.w800,
              ),
            ),
            const SizedBox(height: 16),
            SizedBox(
              height: 52,
              child: FilledButton.icon(
                onPressed: submitting ? null : claimInvite,
                style: FilledButton.styleFrom(
                  backgroundColor: _inviteWine,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(15),
                  ),
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
                    : const Icon(Icons.check_circle_outline_rounded),
                label: Text(
                  submitting ? 'Davet doğrulanıyor…' : 'İşletmeye katıl',
                ),
              ),
            ),
            const SizedBox(height: 14),
            const Text(
              'Davet kodu tek kullanımlıktır. Süresi dolduğunda işletme sahibinden yeni kod istemelisin.',
              textAlign: TextAlign.center,
              style: TextStyle(
                color: _inviteMuted,
                fontSize: 12,
                height: 1.4,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
