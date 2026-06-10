import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';
import '../../core/theme/app_theme.dart';
import '../../core/providers/auth_provider.dart';
import '../widgets/app_feedback.dart';

class ProfileScreen extends ConsumerStatefulWidget {
  const ProfileScreen({super.key});

  @override
  ConsumerState<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends ConsumerState<ProfileScreen> {
  late TextEditingController _nameController;
  late TextEditingController _emailController;
  late TextEditingController _phoneController;
  late TextEditingController _shopNumberController;
  late TextEditingController _addressController;
  final _passwordController = TextEditingController();
  String? _logoPath;

  @override
  void initState() {
    super.initState();
    final authState = ref.read(authProvider);
    _nameController = TextEditingController(text: authState.shopName);
    _emailController = TextEditingController(text: authState.email);
    _phoneController = TextEditingController(text: authState.phone);
    _shopNumberController = TextEditingController(text: authState.shopNumber);
    _addressController = TextEditingController(text: authState.address);
    _logoPath = authState.logoPath;
  }

  @override
  void dispose() {
    _nameController.dispose();
    _emailController.dispose();
    _phoneController.dispose();
    _shopNumberController.dispose();
    _addressController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _pickLogo() async {
    final source = await showModalBottomSheet<ImageSource>(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (_) => _ImageSourceSheet(),
    );
    if (source == null) return;
    final picked = await ImagePicker().pickImage(
      source: source,
      maxWidth: 512,
      maxHeight: 512,
      imageQuality: 85,
    );
    if (picked != null) setState(() => _logoPath = picked.path);
  }

  @override
  Widget build(BuildContext context) {
    final authState = ref.watch(authProvider);
    final initial = authState.shopName.isNotEmpty ? authState.shopName[0].toUpperCase() : 'S';

    return Scaffold(
      backgroundColor: const Color(0xFFF1F5F9),
      body: SafeArea(
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
                        border: Border.all(color: const Color(0xFFE2E8F0)),
                      ),
                      child: const Icon(PhosphorIconsRegular.caretLeft, color: Color(0xFF0F172A), size: 20),
                    ),
                  ),
                  const SizedBox(width: 16),
                  const Text(
                    'Profile',
                    style: TextStyle(fontSize: 24, fontWeight: FontWeight.w800, color: Color(0xFF0F172A), letterSpacing: -0.5),
                  ),
                ],
              ),
            ),

            Expanded(
              child: ListView(
                padding: const EdgeInsets.fromLTRB(20, 8, 20, 100),
                physics: const BouncingScrollPhysics(),
                children: [
                  // Logo/Avatar
                  Center(
                    child: GestureDetector(
                      onTap: _pickLogo,
                      child: Stack(
                        alignment: Alignment.bottomRight,
                        children: [
                          Container(
                            width: 100,
                            height: 100,
                            decoration: BoxDecoration(
                              gradient: LinearGradient(
                                begin: Alignment.topLeft,
                                end: Alignment.bottomRight,
                                colors: [AppTheme.primaryColor.withOpacity(0.15), AppTheme.accentColor.withOpacity(0.1)],
                              ),
                              shape: BoxShape.circle,
                              border: Border.all(color: AppTheme.primaryColor.withOpacity(0.3), width: 2),
                              image: _logoPath != null
                                  ? DecorationImage(image: FileImage(File(_logoPath!)), fit: BoxFit.cover)
                                  : null,
                            ),
                            alignment: Alignment.center,
                            child: _logoPath == null
                                ? Text(initial, style: const TextStyle(color: AppTheme.primaryColor, fontSize: 40, fontWeight: FontWeight.w800))
                                : null,
                          ),
                          Container(
                            padding: const EdgeInsets.all(8),
                            decoration: BoxDecoration(
                              gradient: const LinearGradient(
                                colors: [AppTheme.primaryColor, AppTheme.primaryDark],
                              ),
                              shape: BoxShape.circle,
                              border: Border.all(color: const Color(0xFFF1F5F9), width: 2),
                            ),
                            child: const Icon(PhosphorIconsRegular.camera, size: 16, color: Colors.white),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 32),

                  // Personal Info card
                  Container(
                    padding: const EdgeInsets.all(20),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(color: const Color(0xFFE2E8F0)),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(children: [
                          const Icon(PhosphorIconsRegular.storefront, color: AppTheme.primaryColor, size: 20),
                          const SizedBox(width: 10),
                          const Text('Personal Information', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 16, color: Color(0xFF0F172A))),
                        ]),
                        const SizedBox(height: 20),
                        TextFormField(
                          controller: _nameController,
                          textCapitalization: TextCapitalization.words,
                          decoration: const InputDecoration(
                            labelText: 'Shop / Profile Name',
                            prefixIcon: Icon(PhosphorIconsRegular.storefront),
                          ),
                        ),
                        const SizedBox(height: 16),
                        TextFormField(
                          controller: _phoneController,
                          keyboardType: TextInputType.phone,
                          decoration: const InputDecoration(
                            labelText: 'Phone Number',
                            prefixIcon: Icon(PhosphorIconsRegular.phone),
                          ),
                        ),
                        const SizedBox(height: 16),
                        TextFormField(
                          controller: _shopNumberController,
                          decoration: const InputDecoration(
                            labelText: 'Shop Number',
                            prefixIcon: Icon(PhosphorIconsRegular.tag),
                          ),
                        ),
                        const SizedBox(height: 16),
                        TextFormField(
                          controller: _addressController,
                          textCapitalization: TextCapitalization.sentences,
                          maxLines: 2,
                          decoration: const InputDecoration(
                            labelText: 'Address',
                            prefixIcon: Icon(PhosphorIconsRegular.mapPin),
                          ),
                        ),
                        const SizedBox(height: 16),
                        TextFormField(
                          controller: _emailController,
                          enabled: false,
                          decoration: const InputDecoration(
                            labelText: 'Email Address',
                            prefixIcon: Icon(PhosphorIconsRegular.envelope),
                          ),
                        ),
                        const SizedBox(height: 6),
                        const Text('Email cannot be changed locally.', style: TextStyle(color: Color(0xFF94A3B8), fontSize: 11)),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),

                  // Security card
                  Container(
                    padding: const EdgeInsets.all(20),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(color: const Color(0xFFE2E8F0)),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(children: [
                          const Icon(PhosphorIconsRegular.shieldCheck, color: AppTheme.successColor, size: 20),
                          const SizedBox(width: 10),
                          const Text('Security', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 16, color: Color(0xFF0F172A))),
                        ]),
                        const SizedBox(height: 20),
                        TextFormField(
                          controller: _passwordController,
                          obscureText: true,
                          decoration: const InputDecoration(
                            labelText: 'New Password',
                            prefixIcon: Icon(PhosphorIconsRegular.lockKey),
                          ),
                        ),
                        const SizedBox(height: 6),
                        const Text('Leave blank to keep current password.', style: TextStyle(color: Color(0xFF94A3B8), fontSize: 11)),
                      ],
                    ),
                  ),
                  const SizedBox(height: 32),

                  SizedBox(
                    width: double.infinity,
                    height: 52,
                    child: ElevatedButton.icon(
                      onPressed: _saveProfile,
                      icon: const Icon(PhosphorIconsFill.floppyDisk, size: 18),
                      label: const Text('Save Changes', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _saveProfile() {
    FocusScope.of(context).unfocus();
    final newName = _nameController.text.trim();
    final newPhone = _phoneController.text.trim();
    final newShopNumber = _shopNumberController.text.trim();
    final newAddress = _addressController.text.trim();

    if (newName.isEmpty) {
      AppFeedback.showError(context, 'Validation Error', 'Shop name cannot be empty.');
      return;
    }

    ref.read(authProvider.notifier).updateActiveShop(
          name: newName,
          phone: newPhone,
          shopNumber: newShopNumber,
          address: newAddress,
          logoPath: _logoPath,
        );

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

class _ImageSourceSheet extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    const bg = Colors.white;
    const textPrimary = Color(0xFF0F172A);

    return Container(
      decoration: const BoxDecoration(
          color: bg, borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      padding: const EdgeInsets.fromLTRB(24, 16, 24, 32),
      child: Column(mainAxisSize: MainAxisSize.min, children: [
        Container(
            width: 40, height: 4,
            decoration: BoxDecoration(
                color: Colors.grey.withOpacity(0.3), borderRadius: BorderRadius.circular(2))),
        const SizedBox(height: 20),
        const Text('Choose Photo',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700, color: textPrimary)),
        const SizedBox(height: 20),
        ListTile(
          leading: Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                  color: AppTheme.primaryColor.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(12)),
              child: const Icon(Icons.camera_alt_rounded, color: AppTheme.primaryColor)),
          title: const Text('Camera', style: TextStyle(fontWeight: FontWeight.w600, color: textPrimary)),
          onTap: () => Navigator.pop(context, ImageSource.camera),
        ),
        ListTile(
          leading: Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                  color: AppTheme.successColor.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(12)),
              child: const Icon(Icons.photo_library_rounded, color: AppTheme.successColor)),
          title: const Text('Gallery', style: TextStyle(fontWeight: FontWeight.w600, color: textPrimary)),
          onTap: () => Navigator.pop(context, ImageSource.gallery),
        ),
      ]),
    );
  }
}
