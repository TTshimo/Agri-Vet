import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

import 'home_screen.dart';
import '../theme/palette.dart';

class _FieldWavesPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final p1 = Path()
      ..moveTo(0, size.height * 0.18)
      ..cubicTo(
        size.width * 0.28, size.height * 0.36,
        size.width * 0.58, size.height * -0.02,
        size.width * 0.82, size.height * 0.16,
      )
      ..cubicTo(
        size.width * 0.94, size.height * 0.23,
        size.width, size.height * 0.18,
        size.width, size.height * 0.12,
      )
      ..lineTo(size.width, 0)
      ..lineTo(0, 0)
      ..close();
    canvas.drawPath(p1, Paint()..color = Bg.waveDark);

    final p2 = Path()
      ..moveTo(0, size.height * 0.30)
      ..cubicTo(
        size.width * 0.32, size.height * 0.45,
        size.width * 0.64, size.height * 0.16,
        size.width, size.height * 0.28,
      )
      ..lineTo(size.width, 0)
      ..lineTo(0, 0)
      ..close();
    canvas.drawPath(p2, Paint()..color = Bg.waveDarkSoft.withOpacity(0.7));
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

class _GlassCard extends StatelessWidget {
  const _GlassCard({required this.child, this.padding = const EdgeInsets.all(18)});

  final Widget child;
  final EdgeInsets padding;

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(20),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 18, sigmaY: 18),
        child: Container(
          padding: padding,
          decoration: BoxDecoration(
            color: Bg.glassFill,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: Bg.glassBorder, width: 0.8),
          ),
          child: child,
        ),
      ),
    );
  }
}

class _FieldLabel extends StatelessWidget {
  const _FieldLabel(this.text);
  final String text;

  @override
  Widget build(BuildContext context) {
    return Text(text,
        style: TextStyle(color: Fg.almond, fontSize: 12.5, fontWeight: FontWeight.w600));
  }
}

class _HelperText extends StatelessWidget {
  const _HelperText(this.text);
  final String text;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: 4, bottom: 14),
      child: Text(text, style: TextStyle(color: Fg.almondMuted, fontSize: 11, height: 1.4)),
    );
  }
}

class _AuthField extends StatelessWidget {
  const _AuthField({
    required this.controller,
    required this.hint,
    this.icon,
    this.obscure = false,
    this.suffix,
    this.keyboardType,
    this.onChanged,
  });

  final TextEditingController controller;
  final String hint;
  final IconData? icon;
  final bool obscure;
  final Widget? suffix;
  final TextInputType? keyboardType;
  final ValueChanged<String>? onChanged;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(top: 6),
      decoration: BoxDecoration(
        color: Bg.fieldFill,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: Bg.fieldBorder, width: 0.8),
      ),
      child: TextField(
        controller: controller,
        obscureText: obscure,
        keyboardType: keyboardType,
        onChanged: onChanged,
        style: TextStyle(color: Fg.almond, fontSize: 14),
        decoration: InputDecoration(
          hintText: hint,
          hintStyle: TextStyle(color: Fg.almondMuted.withOpacity(0.8), fontSize: 13.5),
          prefixIcon: icon == null ? null : Icon(icon, size: 18, color: Fg.almondSoft),
          suffixIcon: suffix,
          border: InputBorder.none,
          contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
        ),
      ),
    );
  }
}

class _Chip extends StatelessWidget {
  const _Chip({required this.label, required this.selected, required this.onTap});

  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 9, horizontal: 14),
        decoration: BoxDecoration(
          color: selected ? Bg.rust : Bg.fieldFill,
          borderRadius: BorderRadius.circular(999),
          border: Border.all(
            color: selected ? Bg.rust : Bg.fieldBorder,
            width: 0.8,
          ),
        ),
        child: Text(
          label,
          textAlign: TextAlign.center,
          style: TextStyle(
            color: selected ? Fg.ink : Fg.almond,
            fontSize: 12,
            fontWeight: selected ? FontWeight.w600 : FontWeight.w400,
          ),
        ),
      ),
    );
  }
}

class _FieldDropdown extends StatelessWidget {
  const _FieldDropdown({required this.value, required this.items, required this.onChanged});

  final String value;
  final List<String> items;
  final ValueChanged<String?> onChanged;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(top: 6),
      padding: const EdgeInsets.symmetric(horizontal: 14),
      decoration: BoxDecoration(
        color: Bg.fieldFill,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: Bg.fieldBorder, width: 0.8),
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<String>(
          value: value,
          isExpanded: true,
          dropdownColor: Bg.waveDarkSoft,
          style: TextStyle(color: Fg.almond, fontSize: 14),
          icon: Icon(Icons.keyboard_arrow_down, color: Fg.almondSoft, size: 18),
          items: items
              .map((e) => DropdownMenuItem(value: e, child: Text(e)))
              .toList(),
          onChanged: onChanged,
        ),
      ),
    );
  }
}

enum _AnimalType { livestock, crops, both }

class RegisterScreen extends StatefulWidget {
  const RegisterScreen({super.key});

  @override
  State<RegisterScreen> createState() => _RegisterScreenState();
}

class _RegisterScreenState extends State<RegisterScreen> {
  int _step = 0;
  bool _loading = false;
  String? _error;

  final _nameCtrl = TextEditingController();
  final _emailCtrl = TextEditingController();
  final _phoneCtrl = TextEditingController();
  final _passCtrl = TextEditingController();
  final _confirmCtrl = TextEditingController();
  bool _obscurePass = true;
  bool _agreedToTerms = false;
  _AnimalType _farmerType = _AnimalType.livestock;
  double _passwordStrength = 0;

  final _farmNameCtrl = TextEditingController();
  final _locationCtrl = TextEditingController();
  final _yearsCtrl = TextEditingController();
  final Set<String> _animalsKept = {};
  String _soilType = 'Sandy';
  String _waterSource = 'Borehole';

  @override
  void dispose() {
    _nameCtrl.dispose();
    _emailCtrl.dispose();
    _phoneCtrl.dispose();
    _passCtrl.dispose();
    _confirmCtrl.dispose();
    _farmNameCtrl.dispose();
    _locationCtrl.dispose();
    _yearsCtrl.dispose();
    super.dispose();
  }

  void _scorePassword(String value) {
    double score = 0;
    if (value.length >= 8) score += 1;
    if (RegExp(r'[0-9]').hasMatch(value)) score += 1;
    if (RegExp(r'[A-Z]').hasMatch(value)) score += 1;
    setState(() => _passwordStrength = score);
  }

  bool _validateStep1() {
    if (_nameCtrl.text.trim().isEmpty) {
      setState(() => _error = 'Enter your full name.');
      return false;
    }
    if (!_emailCtrl.text.contains('@')) {
      setState(() => _error = 'Enter a valid email address.');
      return false;
    }
    if (_passCtrl.text.length < 8) {
      setState(() => _error = 'Password needs at least 8 characters.');
      return false;
    }
    if (_passCtrl.text != _confirmCtrl.text) {
      setState(() => _error = "Passwords don't match.");
      return false;
    }
    if (!_agreedToTerms) {
      setState(() => _error = 'Please accept the terms to continue.');
      return false;
    }
    setState(() => _error = null);
    return true;
  }

  void _goToStep2() {
    if (_validateStep1()) setState(() => _step = 1);
  }

  Future<void> _completeRegistration({bool skipFarmDetails = false}) async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final credential = await FirebaseAuth.instance.createUserWithEmailAndPassword(
        email: _emailCtrl.text.trim(),
        password: _passCtrl.text,
      );
      final uid = credential.user?.uid;
      if (uid != null) {
        await FirebaseFirestore.instance.collection('users').doc(uid).set({
          'name': _nameCtrl.text.trim(),
          'email': _emailCtrl.text.trim(),
          'phone': _phoneCtrl.text.trim(),
          'farmerType': _farmerType.name,
          'farmName': skipFarmDetails ? '' : _farmNameCtrl.text.trim(),
          'location': skipFarmDetails ? '' : _locationCtrl.text.trim(),
          'animalsKept': skipFarmDetails ? <String>[] : _animalsKept.toList(),
          'soilType': skipFarmDetails ? '' : _soilType,
          'waterSource': skipFarmDetails ? '' : _waterSource,
          'yearsFarming': skipFarmDetails ? '' : _yearsCtrl.text.trim(),
          'createdAt': FieldValue.serverTimestamp(),
        });
      }
      if (!mounted) return;
      Navigator.of(context).pushAndRemoveUntil(
        MaterialPageRoute(builder: (_) => const HomeScreen()),
        (route) => false,
      );
    } on FirebaseAuthException catch (e) {
      setState(() {
        _step = 0;
        _error = _authErrorMessage(e);
      });
    } catch (e) {
      setState(() => _error = 'Something went wrong creating your account.');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  String _authErrorMessage(FirebaseAuthException e) {
    switch (e.code) {
      case 'email-already-in-use':
        return 'An account with that email already exists.';
      case 'invalid-email':
        return 'Invalid email address.';
      case 'weak-password':
        return 'Choose a stronger password.';
      default:
        return e.message ?? 'Could not create your account. Try again.';
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Bg.bgDark,
      body: Stack(
        children: [
          Positioned(
            top: 0,
            left: 0,
            right: 0,
            height: 220,
            child: CustomPaint(painter: _FieldWavesPainter()),
          ),
          SafeArea(
            child: SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(20, 20, 20, 28),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      InkWell(
                        onTap: () {
                          if (_step == 1) {
                            setState(() => _step = 0);
                          } else {
                            Navigator.of(context).pop();
                          }
                        },
                        borderRadius: BorderRadius.circular(17),
                        child: Container(
                          width: 34,
                          height: 34,
                          decoration: BoxDecoration(
                            color: Bg.fieldFill,
                            shape: BoxShape.circle,
                          ),
                          child: Icon(Icons.arrow_back, size: 16, color: Fg.almond),
                        ),
                      ),
                      const Spacer(),
                      Text('Step ${_step + 1} of 2',
                          style: TextStyle(color: Fg.almondSoft, fontSize: 12)),
                    ],
                  ),
                  const SizedBox(height: 18),
                  Text(
                    _step == 0 ? 'Create your account' : 'Tell us about your farm',
                    style: TextStyle(
                        color: Fg.almond, fontSize: 22, fontWeight: FontWeight.w600),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    _step == 0
                        ? 'Tell us a bit about you so AgroLens can tailor diagnosis and alerts to your farm.'
                        : 'This tunes which disease guides, questions and alerts you see — you can edit it later from your profile.',
                    style: TextStyle(color: Fg.almondSoft, fontSize: 13, height: 1.5),
                  ),
                  const SizedBox(height: 18),
                  Row(
                    children: [
                      Expanded(
                        child: Container(height: 4, decoration: BoxDecoration(
                            color: Bg.rust, borderRadius: BorderRadius.circular(999))),
                      ),
                      const SizedBox(width: 6),
                      Expanded(
                        child: Container(
                          height: 4,
                          decoration: BoxDecoration(
                            color: _step == 1 ? Bg.rust : Bg.fieldBorder,
                            borderRadius: BorderRadius.circular(999),
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 18),
                  _GlassCard(
                    child: _step == 0 ? _buildStep1() : _buildStep2(),
                  ),
                  if (_step == 0) ...[
                    const SizedBox(height: 18),
                    Row(
                      children: [
                        Expanded(child: Divider(color: Bg.fieldBorder, height: 0.8)),
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 10),
                          child: Text('or continue with',
                              style: TextStyle(color: Fg.almondMuted, fontSize: 11)),
                        ),
                        Expanded(child: Divider(color: Bg.fieldBorder, height: 0.8)),
                      ],
                    ),
                    const SizedBox(height: 14),
                    Row(
                      children: [
                        Expanded(child: _SocialButton(icon: Icons.g_mobiledata, label: 'Google', onTap: () {})),
                        const SizedBox(width: 10),
                        Expanded(child: _SocialButton(icon: Icons.phone_outlined, label: 'Phone', onTap: () {})),
                      ],
                    ),
                    const SizedBox(height: 20),
                    Center(
                      child: GestureDetector(
                        onTap: () => Navigator.of(context).pop(),
                        child: RichText(
                          text: TextSpan(
                            style: TextStyle(color: Fg.almondSoft, fontSize: 12.5),
                            children: [
                              const TextSpan(text: 'Already have an account? '),
                              TextSpan(
                                text: 'Log in',
                                style: TextStyle(color: Fg.almond, fontWeight: FontWeight.w600),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStep1() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const _FieldLabel('Full name'),
        _AuthField(controller: _nameCtrl, hint: 'Jane Doe', icon: Icons.person_outline),
   
        const _FieldLabel('Email address'),
        _AuthField(
          controller: _emailCtrl,
          hint: 'name@email.com',
          icon: Icons.mail_outline,
          keyboardType: TextInputType.emailAddress,
        ),

        const _FieldLabel('Phone number'),
        _AuthField(
          controller: _phoneCtrl,
          hint: '+267 71 234 567',
          icon: Icons.phone_outlined,
          keyboardType: TextInputType.phone,
        ),
        const _HelperText('Optional.'),

        const _FieldLabel('Password'),
        _AuthField(
          controller: _passCtrl,
          hint: 'Create a password',
          icon: Icons.lock_outline,
          obscure: _obscurePass,
          onChanged: _scorePassword,
          suffix: IconButton(
            icon: Icon(
              _obscurePass ? Icons.visibility_outlined : Icons.visibility_off_outlined,
              size: 18,
              color: Fg.almondSoft,
            ),
            onPressed: () => setState(() => _obscurePass = !_obscurePass),
          ),
        ),
        const SizedBox(height: 6),
        Row(
          children: List.generate(3, (i) {
            final filled = i < _passwordStrength;
            return Expanded(
              child: Container(
                margin: EdgeInsets.only(right: i == 2 ? 0 : 4),
                height: 3,
                decoration: BoxDecoration(
                  color: filled ? Bg.rust : Bg.fieldBorder,
                  borderRadius: BorderRadius.circular(999),
                ),
              ),
            );
          }),
        ),
        _HelperText(
          _passwordStrength <= 1
              ? 'At least 8 characters, 1 number. Strength: weak.'
              : _passwordStrength == 2
                  ? 'At least 8 characters, 1 number. Strength: fair.'
                  : 'At least 8 characters, 1 number. Strength: strong.',
        ),

        const _FieldLabel('Confirm password'),
        _AuthField(controller: _confirmCtrl, hint: 'Repeat your password', icon: Icons.lock_outline, obscure: true),
        const SizedBox(height: 14),

        const _FieldLabel('I farm'),
        const SizedBox(height: 8),
        Row(
          children: [
            Expanded(
              child: _Chip(
                label: 'Livestock',
                selected: _farmerType == _AnimalType.livestock,
                onTap: () => setState(() => _farmerType = _AnimalType.livestock),
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: _Chip(
                label: 'Crops',
                selected: _farmerType == _AnimalType.crops,
                onTap: () => setState(() => _farmerType = _AnimalType.crops),
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: _Chip(
                label: 'Both',
                selected: _farmerType == _AnimalType.both,
                onTap: () => setState(() => _farmerType = _AnimalType.both),
              ),
            ),
          ],
        ),
        const _HelperText("Sets which disease guides and questions you'll see first."),

        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SizedBox(
              width: 22,
              height: 22,
              child: Checkbox(
                value: _agreedToTerms,
                onChanged: (v) => setState(() => _agreedToTerms = v ?? false),
                fillColor: WidgetStateProperty.resolveWith(
                  (states) => states.contains(WidgetState.selected) ? Bg.rust : Bg.fieldFill,
                ),
                side: BorderSide(color: Bg.fieldBorder, width: 0.8),
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                'I agree to the Terms of Service and Privacy Policy, and to receive farm alerts by email.',
                style: TextStyle(color: Fg.almondSoft, fontSize: 11.5, height: 1.5),
              ),
            ),
          ],
        ),
        const SizedBox(height: 16),
        if (_error != null) ...[
          Text(_error!, style: const TextStyle(color: Color(0xFFE2A07A), fontSize: 12)),
          const SizedBox(height: 8),
        ],
        SizedBox(
          width: double.infinity,
          child: ElevatedButton(
            onPressed: _goToStep2,
            style: ElevatedButton.styleFrom(
              backgroundColor: Bg.rust,
              foregroundColor: Fg.ink,
              padding: const EdgeInsets.symmetric(vertical: 14),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
            child: const Text('Continue', style: TextStyle(fontWeight: FontWeight.w600)),
          ),
        ),
      ],
    );
  }

  Widget _buildStep2() {
    const animalOptions = ['Cattle', 'Goats', 'Poultry', 'Sheep'];
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const _FieldLabel('Farm name'),
        _AuthField(controller: _farmNameCtrl, hint: 'Tshimologo Farm', icon: Icons.home_work_outlined),
        const _HelperText('Optional. Shown on your profile, not searchable by others.'),

        const _FieldLabel('Location'),
        _AuthField(controller: _locationCtrl, hint: 'Maun, Botswana', icon: Icons.location_on_outlined),
        const _HelperText('Matches you to nearby outbreak alerts and farmers.'),

        const _FieldLabel('Animals kept'),
        const SizedBox(height: 8),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: animalOptions.map((a) {
            final selected = _animalsKept.contains(a);
            return _Chip(
              label: a,
              selected: selected,
              onTap: () => setState(() {
                selected ? _animalsKept.remove(a) : _animalsKept.add(a);
              }),
            );
          }).toList(),
        ),
        const _HelperText('Select any that apply. Sharpens your diagnosis suggestions.'),

        const _FieldLabel('Soil type'),
        _FieldDropdown(
          value: _soilType,
          items: const ['Sandy', 'Clay', 'Loam', 'Not sure'],
          onChanged: (v) => setState(() => _soilType = v ?? _soilType),
        ),
        const _HelperText('Helps flag crop risks common to your soil.'),

        const _FieldLabel('Water source'),
        _FieldDropdown(
          value: _waterSource,
          items: const ['Borehole', 'River or dam', 'Municipal', 'Rain-fed only'],
          onChanged: (v) => setState(() => _waterSource = v ?? _waterSource),
        ),
        const _HelperText('Some diseases spread fastest through shared water.'),

        const _FieldLabel('Years farming'),
        _AuthField(
          controller: _yearsCtrl,
          hint: 'e.g. 5',
          icon: Icons.calendar_today_outlined,
          keyboardType: TextInputType.number,
        ),
        const _HelperText("Optional. Just helps us calibrate guidance for beginners vs veterans."),

        if (_error != null) ...[
          Text(_error!, style: const TextStyle(color: Color(0xFFE2A07A), fontSize: 12)),
          const SizedBox(height: 8),
        ],
        SizedBox(
          width: double.infinity,
          child: ElevatedButton(
            onPressed: _loading ? null : () => _completeRegistration(),
            style: ElevatedButton.styleFrom(
              backgroundColor: Bg.rust,
              foregroundColor: Fg.ink,
              padding: const EdgeInsets.symmetric(vertical: 14),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
            child: _loading
                ? SizedBox(
                    height: 18, width: 18,
                    child: CircularProgressIndicator(strokeWidth: 2, color: Fg.ink),
                  )
                : const Text('Finish setting up', style: TextStyle(fontWeight: FontWeight.w600)),
          ),
        ),
        const SizedBox(height: 6),
        Center(
          child: TextButton(
            onPressed: _loading ? null : () => _completeRegistration(skipFarmDetails: true),
            child: Text("Skip for now, I'll fill this in later",
                style: TextStyle(color: Fg.almondSoft, fontSize: 12.5)),
          ),
        ),
      ],
    );
  }
}

class _SocialButton extends StatelessWidget {
  const _SocialButton({required this.icon, required this.label, required this.onTap});

  final IconData icon;
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 12),
        decoration: BoxDecoration(
          color: Bg.fieldFill,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: Bg.fieldBorder, width: 0.8),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, size: 18, color: Fg.almond),
            const SizedBox(width: 6),
            Text(label, style: TextStyle(color: Fg.almond, fontSize: 12.5)),
          ],
        ),
      ),
    );
  }
}