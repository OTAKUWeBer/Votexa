import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../providers/poll_provider.dart';

class HostCreatePage extends StatefulWidget {
  const HostCreatePage({Key? key}) : super(key: key);

  @override
  State<HostCreatePage> createState() => _HostCreatePageState();
}

class _HostCreatePageState extends State<HostCreatePage> {
  final TextEditingController _passwordController = TextEditingController();
  bool _passwordProtected = false;
  bool _isCreating = false;

  @override
  void dispose() {
    _passwordController.dispose();
    super.dispose();
  }

  void _createPoll() async {
    setState(() => _isCreating = true);

    try {
      final pollProvider = context.read<PollProvider>();
      await pollProvider.initializeDeviceId();
      
      await pollProvider.createPoll(
        password: _passwordProtected ? _passwordController.text : null,
      );

      if (mounted) {
        Navigator.of(context).pushReplacementNamed('/host_poll');
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error creating poll: $e')),
        );
        setState(() => _isCreating = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [Color(0xFF0A0E27), Color(0xFF141829)],
          ),
        ),
        child: SafeArea(
          child: SingleChildScrollView(
            child: Padding(
              padding: const EdgeInsets.all(24.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Back Button
                  GestureDetector(
                    onTap: () => Navigator.pop(context),
                    child: Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: const Icon(
                        Icons.arrow_back,
                        color: Colors.white,
                      ),
                    ),
                  ),
                  const SizedBox(height: 32),
                  // Title
                  const Text(
                    'Host a Poll',
                    style: TextStyle(
                      fontSize: 32,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                  ),
                  const SizedBox(height: 8),
                  const Text(
                    'Configure your poll settings',
                    style: TextStyle(
                      fontSize: 16,
                      color: Color(0xFFd1d5db),
                    ),
                  ),
                  const SizedBox(height: 40),
                  // Settings Card
                  Container(
                    padding: const EdgeInsets.all(24),
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.05),
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(
                        color: Colors.white.withOpacity(0.1),
                      ),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Password Protection
                        Row(
                          children: [
                            Checkbox(
                              value: _passwordProtected,
                              onChanged: (value) {
                                setState(() => _passwordProtected = value ?? false);
                              },
                              activeColor: const Color(0xFF0DD9FF),
                            ),
                            const Text(
                              'Protect with password',
                              style: TextStyle(
                                fontSize: 16,
                                color: Colors.white,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 20),
                        // Password Field
                        if (_passwordProtected)
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text(
                                'Password',
                                style: TextStyle(
                                  fontSize: 14,
                                  color: Color(0xFFd1d5db),
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                              const SizedBox(height: 12),
                              TextField(
                                controller: _passwordController,
                                obscureText: true,
                                style: const TextStyle(color: Colors.white),
                                decoration: InputDecoration(
                                  hintText: 'Enter poll password',
                                  hintStyle: const TextStyle(
                                    color: Color(0xFF6b7280),
                                  ),
                                  filled: true,
                                  fillColor: Colors.white.withOpacity(0.05),
                                  border: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(12),
                                    borderSide: BorderSide(
                                      color: Colors.white.withOpacity(0.2),
                                    ),
                                  ),
                                  enabledBorder: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(12),
                                    borderSide: BorderSide(
                                      color: Colors.white.withOpacity(0.2),
                                    ),
                                  ),
                                  focusedBorder: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(12),
                                    borderSide: const BorderSide(
                                      color: Color(0xFF0DD9FF),
                                      width: 2,
                                    ),
                                  ),
                                  contentPadding: const EdgeInsets.all(16),
                                ),
                              ),
                              const SizedBox(height: 20),
                            ],
                          ),
                        // Info Box
                        Container(
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            color: const Color(0xFF0DD9FF).withOpacity(0.1),
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(
                              color: const Color(0xFF0DD9FF).withOpacity(0.3),
                            ),
                          ),
                          child: const Text(
                            'You will receive a QR code that participants can scan to join. The poll is completely offline and private.',
                            style: TextStyle(
                              fontSize: 14,
                              color: Color(0xFF0DD9FF),
                              height: 1.5,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 40),
                  // Create Button
                  SizedBox(
                    width: double.infinity,
                    height: 56,
                    child: ElevatedButton(
                      onPressed: _isCreating ? null : _createPoll,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF0DD9FF),
                        disabledBackgroundColor: const Color(0xFF006688),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      child: _isCreating
                          ? const SizedBox(
                              height: 24,
                              width: 24,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                valueColor: AlwaysStoppedAnimation<Color>(
                                  Colors.white,
                                ),
                              ),
                            )
                          : const Text(
                              'Create Poll',
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                                color: Color(0xFF0A0E27),
                              ),
                            ),
                    ),
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
