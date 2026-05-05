import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';
import '../../core/theme/app_theme.dart';
import '../../core/providers/auth_provider.dart';
import '../widgets/glass_container.dart';
import '../widgets/app_feedback.dart';

class ProfileScreen extends ConsumerStatefulWidget {
  const ProfileScreen({super.key});

  @override
  ConsumerState<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends ConsumerState<ProfileScreen> {
  late TextEditingController _nameController;
  late TextEditingController _emailController;
  final _passwordController = TextEditingController();

  @override
  void initState() {
    super.initState();
    final authState = ref.read(authProvider);
    _nameController = TextEditingController(text: authState.shopName);
    _emailController = TextEditingController(text: authState.email);
  }

  @override
  void dispose() {
    _nameController.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final authState = ref.watch(authProvider);

    return Scaffold(
      backgroundColor: Colors.transparent,
      body: Container(
        decoration: const BoxDecoration(
          color: AppTheme.backgroundColor,
        ),
        child: SafeArea(
          child: Column(
            children: [
              // Header
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
                child: Row(
                  children: [
                    GestureDetector(
                      onTap: () => context.pop(),
                      child: Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          shape: BoxShape.circle,
                          boxShadow: [
                            BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 4, offset: const Offset(0, 2))
                          ],
                        ),
                        child: Icon(PhosphorIconsRegular.caretLeft, color: AppTheme.textPrimary, size: 20),
                      ),
                    ),
                    const SizedBox(width: 16),
                    const Text(
                      'Profile',
                      style: TextStyle(
                        fontSize: 24,
                        fontWeight: FontWeight.w800,
                        color: AppTheme.textPrimary,
                        letterSpacing: -0.5,
                      ),
                    ),
                  ],
                ),
              ),
              Expanded(
                child: ListView(
                  padding: const EdgeInsets.fromLTRB(20, 12, 20, 100),
                  physics: const BouncingScrollPhysics(),
                  children: [
                    // Avatar
                    Center(
                      child: GestureDetector(
                        onTap: () {
                          AppFeedback.showError(context, 'Notice', 'Uploading custom profile pictures requires Firebase Storage. Coming soon!');
                        },
                        child: Stack(
                          alignment: Alignment.bottomRight,
                          children: [
                            Container(
                              width: 96,
                              height: 96,
                              decoration: BoxDecoration(
                                color: AppTheme.primaryColor.withOpacity(0.1),
                                shape: BoxShape.circle,
                              ),
                              alignment: Alignment.center,
                              child: Text(
                                authState.shopName.isNotEmpty ? authState.shopName[0].toUpperCase() : 'S',
                                style: const TextStyle(
                                  color: AppTheme.primaryColor,
                                  fontSize: 36,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                            ),
                            Container(
                              padding: const EdgeInsets.all(6),
                              decoration: BoxDecoration(
                                color: AppTheme.primaryColor,
                                shape: BoxShape.circle,
                                border: Border.all(color: Colors.white, width: 2),
                              ),
                              child: Icon(PhosphorIconsRegular.camera, size: 14, color: Colors.white),
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 32),

                    // Details
                    Container(
                      padding: const EdgeInsets.all(20),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(color: Colors.grey.withOpacity(0.15)),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text('Personal Information', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 16)),
                          const SizedBox(height: 20),
                          TextFormField(
                            controller: _nameController,
                            decoration: InputDecoration(
                              labelText: 'Shop / Profile Name',
                              prefixIcon: Icon(PhosphorIconsRegular.storefront),
                            ),
                          ),
                          const SizedBox(height: 16),
                          TextFormField(
                            controller: _emailController,
                            enabled: false, // Wait for Firebase
                            decoration: InputDecoration(
                              labelText: 'Email Address',
                              prefixIcon: Icon(PhosphorIconsRegular.envelope),
                            ),
                          ),
                          const SizedBox(height: 8),
                          const Text('Email cannot be changed locally.', style: TextStyle(color: AppTheme.textSecondary, fontSize: 11)),
                        ],
                      ),
                    ),
                    const SizedBox(height: 20),

                    // Security
                    Container(
                      padding: const EdgeInsets.all(20),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(color: Colors.grey.withOpacity(0.15)),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text('Security', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 16)),
                          const SizedBox(height: 20),
                          TextFormField(
                            controller: _passwordController,
                            obscureText: true,
                            decoration: InputDecoration(
                              labelText: 'New Password',
                              prefixIcon: Icon(PhosphorIconsRegular.lockKey),
                            ),
                          ),
                          const SizedBox(height: 8),
                          const Text('Leave blank to keep current password.', style: TextStyle(color: AppTheme.textSecondary, fontSize: 11)),
                        ],
                      ),
                    ),
                    const SizedBox(height: 32),

                    SizedBox(
                      width: double.infinity,
                      height: 52,
                      child: ElevatedButton(
                        onPressed: _saveProfile,
                        child: const Text('Save Changes', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _saveProfile() {
    FocusScope.of(context).unfocus();
    final newName = _nameController.text.trim();
    if (newName.isNotEmpty) {
      ref.read(authProvider.notifier).updateShopName(newName);
    }
    
    if (_passwordController.text.isNotEmpty) {
      AppFeedback.showError(context, 'Notice', 'Password resets require Firebase Authentication. Coming soon!');
      return;
    }

    AppFeedback.showSuccess(context, 'Profile Updated', 'Your profile details have been saved successfully.');
    Future.delayed(const Duration(milliseconds: 1500), () {
      if (mounted) context.pop();
    });
  }
}
