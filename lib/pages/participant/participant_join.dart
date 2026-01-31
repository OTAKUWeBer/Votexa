import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import '../../providers/participant_provider.dart';

class ParticipantJoinPage extends StatefulWidget {
  const ParticipantJoinPage({Key? key}) : super(key: key);

  @override
  State<ParticipantJoinPage> createState() => _ParticipantJoinPageState();
}

class _ParticipantJoinPageState extends State<ParticipantJoinPage> {
  late MobileScannerController _scannerController;
  bool _isScanning = true;
  final TextEditingController _pollIdController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();
  final TextEditingController _hostAddressController = TextEditingController();
  final TextEditingController _hostPortController = TextEditingController();
  bool _manualEntry = false;
  String _hostAddress = '192.168.1.100';
  int _hostPort = 8080;

  @override
  void initState() {
    super.initState();
    _scannerController = MobileScannerController();
    context.read<ParticipantProvider>().initializeIds();
  }

  @override
  void dispose() {
    _scannerController.dispose();
    _pollIdController.dispose();
    _passwordController.dispose();
    _hostAddressController.dispose();
    _hostPortController.dispose();
    super.dispose();
  }

  Future<void> _handleBarcode(BarcodeCapture barcode) async {
    if (!_isScanning) return;
    _isScanning = false;

    final List<Barcode> barcodes = barcode.barcodes;
    if (barcodes.isNotEmpty) {
      final String qrData = barcodes.first.rawValue ?? '';
      _parsePollData(qrData);
    }
  }

  void _parsePollData(String qrData) {
    // Expected format: VOTEXA|POLL_ID|HOST_IP|PORT
    print('[ParticipantJoin] Parsing QR data: $qrData');
    try {
      if (qrData.startsWith('VOTEXA|')) {
        final parts = qrData.substring(7).split('|');
        print('[ParticipantJoin] QR parts: $parts');
        if (parts.length >= 3) {
          _pollIdController.text = parts[0];
          _hostAddress = parts[1];
          _hostAddressController.text = parts[1];
          _hostPort = int.tryParse(parts[2]) ?? 8080;
          _hostPortController.text = parts[2];
          print('[ParticipantJoin] Parsed - Poll: ${parts[0]}, Host: ${parts[1]}, Port: ${parts[2]}');
        } else {
          print('[ParticipantJoin] Invalid QR format - not enough parts');
          _pollIdController.text = qrData;
        }
      } else if (qrData.startsWith('VOTEXA:')) {
        _pollIdController.text = qrData.substring(7);
      } else {
        _pollIdController.text = qrData;
      }
    } catch (e) {
      print('[ParticipantJoin] Error parsing QR: $e');
      _pollIdController.text = qrData;
    }

    _showJoinDialog();
  }

  void _showJoinDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFF141829),
        title: const Text(
          'Join Poll',
          style: TextStyle(color: Colors.white),
        ),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                'Poll ID: ${_pollIdController.text}',
                style: const TextStyle(
                  color: Color(0xFF0DD9FF),
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: _hostAddressController,
                style: const TextStyle(color: Colors.white),
                decoration: InputDecoration(
                  hintText: 'Host IP Address',
                  hintStyle: const TextStyle(color: Color(0xFF6b7280)),
                  filled: true,
                  fillColor: Colors.white.withOpacity(0.05),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                    borderSide: BorderSide(
                      color: Colors.white.withOpacity(0.2),
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: _hostPortController,
                style: const TextStyle(color: Colors.white),
                keyboardType: TextInputType.number,
                decoration: InputDecoration(
                  hintText: 'Host Port',
                  hintStyle: const TextStyle(color: Color(0xFF6b7280)),
                  filled: true,
                  fillColor: Colors.white.withOpacity(0.05),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                    borderSide: BorderSide(
                      color: Colors.white.withOpacity(0.2),
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: _passwordController,
                obscureText: true,
                style: const TextStyle(color: Colors.white),
                decoration: InputDecoration(
                  hintText: 'Password (if needed)',
                  hintStyle: const TextStyle(color: Color(0xFF6b7280)),
                  filled: true,
                  fillColor: Colors.white.withOpacity(0.05),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                    borderSide: BorderSide(
                      color: Colors.white.withOpacity(0.2),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              _isScanning = true;
            },
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () async {
              Navigator.pop(context);
              await _joinPoll();
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF8b5cf6),
            ),
            child: const Text('Join'),
          ),
        ],
      ),
    );
  }

  Future<void> _joinPoll() async {
    if (_pollIdController.text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please enter a poll ID')),
      );
      return;
    }

    if (_hostAddressController.text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please enter host IP address')),
      );
      return;
    }

    if (_hostPortController.text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please enter host port')),
      );
      return;
    }

    try {
      // Update from text fields
      _hostAddress = _hostAddressController.text;
      _hostPort = int.tryParse(_hostPortController.text) ?? 8080;

      print('[ParticipantJoin] Joining poll - Host: $_hostAddress:$_hostPort, Poll: ${_pollIdController.text}');

      final participantProvider = context.read<ParticipantProvider>();

      final success = await participantProvider.joinPoll(
        hostAddress: _hostAddress,
        hostPort: _hostPort,
        pollId: _pollIdController.text,
        password: _passwordController.text.isEmpty ? null : _passwordController.text,
      );

      if (mounted) {
        if (success) {
          Navigator.of(context).pushReplacementNamed('/participant_vote');
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Failed to join poll: ${participantProvider.connectionError ?? 'Unknown error'}')),
          );
          _isScanning = true;
        }
      }
    } catch (e) {
      if (mounted) {
        print('[ParticipantJoin] Join error: $e');
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e')),
        );
        _isScanning = true;
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
            colors: [Color(0xFF1e1b4b), Color(0xFF4c1d95)],
          ),
        ),
        child: SafeArea(
          child: Column(
            children: [
              // Header
              Padding(
                padding: const EdgeInsets.all(20),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
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
                    const Text(
                      'Join Poll',
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                      ),
                    ),
                    GestureDetector(
                      onTap: () {
                        setState(() => _manualEntry = !_manualEntry);
                      },
                      child: Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: Colors.white.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Icon(
                          _manualEntry ? Icons.qr_code : Icons.edit,
                          color: Colors.white,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              // Content
              Expanded(
                child: _manualEntry
                    ? _buildManualEntry()
                    : _buildQRScanner(),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildQRScanner() {
    return Column(
      children: [
        Expanded(
          child: ClipRRect(
            borderRadius: const BorderRadius.only(
              topLeft: Radius.circular(24),
              topRight: Radius.circular(24),
            ),
            child: MobileScanner(
              controller: _scannerController,
              onDetect: _handleBarcode,
              errorBuilder: (context, error, child) {
                return SizedBox(
                  width: double.infinity,
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(
                        Icons.error,
                        color: Colors.red,
                        size: 48,
                      ),
                      const SizedBox(height: 16),
                      Text(
                        error.toString(),
                        style: const TextStyle(color: Colors.white),
                      ),
                    ],
                  ),
                );
              },
            ),
          ),
        ),
        Container(
          padding: const EdgeInsets.all(24),
          decoration: const BoxDecoration(
            color: Color(0xFF1e1b4b),
            borderRadius: BorderRadius.only(
              topLeft: Radius.circular(24),
              topRight: Radius.circular(24),
            ),
          ),
          child: const Column(
            children: [
              Text(
                'Scan QR Code',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                ),
              ),
              SizedBox(height: 12),
              Text(
                'Point your camera at the QR code displayed by the host',
                style: TextStyle(
                  fontSize: 14,
                  color: Color(0xFFd1d5db),
                ),
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildManualEntry() {
    return Padding(
      padding: const EdgeInsets.all(24),
      child: SingleChildScrollView(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Text(
              'Enter Connection Details',
              style: TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.bold,
                color: Colors.white,
              ),
            ),
            const SizedBox(height: 32),
            TextField(
              controller: _hostAddressController,
              style: const TextStyle(color: Colors.white, fontSize: 16),
              decoration: InputDecoration(
                hintText: 'Host IP Address',
                hintStyle: const TextStyle(color: Color(0xFF6b7280)),
                filled: true,
                fillColor: Colors.white.withOpacity(0.05),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide(
                    color: Colors.white.withOpacity(0.2),
                  ),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: const BorderSide(
                    color: Color(0xFF8b5cf6),
                    width: 2,
                  ),
                ),
                contentPadding: const EdgeInsets.all(16),
              ),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _hostPortController,
              style: const TextStyle(color: Colors.white, fontSize: 16),
              keyboardType: TextInputType.number,
              decoration: InputDecoration(
                hintText: 'Host Port',
                hintStyle: const TextStyle(color: Color(0xFF6b7280)),
                filled: true,
                fillColor: Colors.white.withOpacity(0.05),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide(
                    color: Colors.white.withOpacity(0.2),
                  ),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: const BorderSide(
                    color: Color(0xFF8b5cf6),
                    width: 2,
                  ),
                ),
                contentPadding: const EdgeInsets.all(16),
              ),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _pollIdController,
              style: const TextStyle(color: Colors.white, fontSize: 16),
              decoration: InputDecoration(
                hintText: 'Poll ID',
                hintStyle: const TextStyle(color: Color(0xFF6b7280)),
                filled: true,
                fillColor: Colors.white.withOpacity(0.05),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide(
                    color: Colors.white.withOpacity(0.2),
                  ),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: const BorderSide(
                    color: Color(0xFF8b5cf6),
                    width: 2,
                  ),
                ),
                contentPadding: const EdgeInsets.all(16),
              ),
            ),
            const SizedBox(height: 24),
            SizedBox(
              width: double.infinity,
              height: 56,
              child: ElevatedButton(
                onPressed: _joinPoll,
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF8b5cf6),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                child: const Text(
                  'Join Poll',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
