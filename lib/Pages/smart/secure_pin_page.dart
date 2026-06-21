import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../services/lock_service.dart';

enum PinMode {
  create, // Set a new PIN (requires confirmation)
  unlock, // Enter existing PIN to unlock
}

class SecurePinPage extends StatefulWidget {
  final PinMode mode;
  final String fileId; // File or folder ID to lock/unlock
  final String? entityType; // 'file' or 'folder' – for context

  const SecurePinPage({
    super.key,
    required this.mode,
    required this.fileId,
    this.entityType,
  });

  @override
  State<SecurePinPage> createState() => _SecurePinPageState();
}

class _SecurePinPageState extends State<SecurePinPage>
    with SingleTickerProviderStateMixin {
  static const int _pinLength = 4;

  String _pin = '';
  String _confirmPin = '';
  bool _isConfirming = false;
  bool _isError = false;
  bool _isSuccess = false;
  String _errorMessage = '';
  bool _didComplete = false;

  late AnimationController _shakeController;
  late Animation<double> _shakeAnimation;

  @override
  void initState() {
    super.initState();
    _shakeController = AnimationController(
      duration: const Duration(milliseconds: 400),
      vsync: this,
    );
    _shakeAnimation = Tween<double>(begin: 0, end: 20).animate(
      CurvedAnimation(parent: _shakeController, curve: Curves.easeInOut),
    );
  }

  @override
  void dispose() {
    _shakeController.dispose();
    super.dispose();
  }

  void _onDigitPressed(String digit) {
    if (_isSuccess) return;
    HapticFeedback.lightImpact();

    setState(() {
      if (_isError) {
        _isError = false;
        _pin = '';
        _confirmPin = '';
        _isConfirming = false;
        _errorMessage = '';
      }

      if (!_isConfirming) {
        if (_pin.length < _pinLength) {
          _pin += digit;
          if (_pin.length == _pinLength && widget.mode == PinMode.unlock) {
            _verifyPin();
          }
        }
      } else {
        if (_confirmPin.length < _pinLength) {
          _confirmPin += digit;
          if (_confirmPin.length == _pinLength) {
            _confirmPinAndLock();
          }
        }
      }
    });
  }

  void _onBackspacePressed() {
    if (_isSuccess) return;
    HapticFeedback.lightImpact();

    setState(() {
      if (_isError) {
        _isError = false;
        _pin = '';
        _confirmPin = '';
        _isConfirming = false;
        _errorMessage = '';
        return;
      }
      if (!_isConfirming) {
        if (_pin.isNotEmpty) {
          _pin = _pin.substring(0, _pin.length - 1);
        }
      } else {
        if (_confirmPin.isNotEmpty) {
          _confirmPin = _confirmPin.substring(0, _confirmPin.length - 1);
        }
      }
    });
  }

  Future<void> _verifyPin() async {
    try {
      bool success;
      if (widget.entityType == 'folder') {
        success = await LockService.unlockFolder(widget.fileId, _pin);
      } else {
        success = await LockService.unlockFile(widget.fileId, _pin);
      }
      if (!mounted) return;
      if (success) {
        _complete(true);
      } else {
        _showError('Incorrect PIN. Please try again.');
      }
    } catch (e) {
      _showError('Error: ${e.toString()}');
    }
  }

  Future<void> _confirmPinAndLock() async {
    if (_pin != _confirmPin) {
      _showError('PINs do not match. Please try again.');
      return;
    }
    try {
      if (widget.entityType == 'folder') {
        await LockService.lockFolder(widget.fileId, _pin);
      } else {
        await LockService.lockFile(widget.fileId, _pin);
      }
      _complete(true);
    } catch (e) {
      _showError('Failed to lock: ${e.toString()}');
    }
  }

  void _complete(bool success) {
    if (_didComplete) return;
    _didComplete = true;
    setState(() => _isSuccess = success);
    HapticFeedback.mediumImpact();
    Future.delayed(const Duration(milliseconds: 500), () {
      if (mounted) Navigator.pop(context, success);
    });
  }

  void _showError(String message) {
    setState(() {
      _isError = true;
      _errorMessage = message;
      _pin = '';
      _confirmPin = '';
      _isConfirming = false;
    });
    HapticFeedback.heavyImpact();
    _shakeController.forward().then((_) => _shakeController.reset());
  }

  void _startConfirm() {
    setState(() {
      _isConfirming = true;
      _confirmPin = '';
    });
  }

  String get _title {
    if (_isSuccess) return 'Access Granted!';
    if (_isError) return 'PIN Mismatch';
    if (widget.mode == PinMode.create) {
      return _isConfirming ? 'Confirm Your PIN' : 'Create Safe PIN';
    } else {
      return 'Enter Your PIN';
    }
  }

  String get _subtitle {
    if (_isSuccess) return 'Your PIN was verified successfully.';
    if (_isError) return _errorMessage;
    if (widget.mode == PinMode.create) {
      return _isConfirming
          ? 'Please re-enter your 4-digit PIN'
          : 'Set a 4-digit PIN to secure your files';
    } else {
      return 'Enter your 4-digit PIN to unlock';
    }
  }

  IconData get _icon {
    if (_isSuccess) return Icons.check_circle_outline;
    if (_isError) return Icons.error_outline;
    return Icons.lock_outline;
  }

  Color get _iconColor {
    if (_isSuccess) return Colors.green;
    if (_isError) return Colors.red;
    return Colors.amber;
  }

  String get _pinDisplay {
    if (_isConfirming) return _confirmPin;
    return _pin;
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return WillPopScope(
      onWillPop: () async {
        if (!_didComplete) {
          Navigator.pop(context, false);
        }
        return false;
      },
      child: Scaffold(
        backgroundColor: isDark ? Colors.grey.shade900 : Colors.grey.shade50,
        appBar: AppBar(
          elevation: 0,
          backgroundColor: Colors.transparent,
          leading: IconButton(
            icon: Icon(Icons.arrow_back_ios_new_rounded, size: 18),
            onPressed: () {
              if (!_didComplete) Navigator.pop(context, false);
            },
          ),
          title: const Text('Secure Vault'),
          centerTitle: true,
        ),
        body: SafeArea(
          child: Column(
            children: [
              const Spacer(flex: 1),
              AnimatedSwitcher(
                duration: const Duration(milliseconds: 300),
                child: Container(
                  key: ValueKey(_icon),
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: _iconColor.withOpacity(0.1),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(_icon, size: 48, color: _iconColor),
                ),
              ),
              const SizedBox(height: 20),
              AnimatedSwitcher(
                duration: const Duration(milliseconds: 200),
                child: Text(
                  _title,
                  key: ValueKey(_title),
                  style: const TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.bold,
                    letterSpacing: -0.5,
                  ),
                ),
              ),
              const SizedBox(height: 8),
              AnimatedSwitcher(
                duration: const Duration(milliseconds: 200),
                child: Text(
                  _subtitle,
                  key: ValueKey(_subtitle),
                  style: TextStyle(
                    fontSize: 14,
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                  textAlign: TextAlign.center,
                ),
              ),
              const SizedBox(height: 30),
              AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                transform: Matrix4.translationValues(
                  _isError ? _shakeAnimation.value : 0,
                  0,
                  0,
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: List.generate(_pinLength, (index) {
                    final bool filled = index < _pinDisplay.length;
                    final bool isErrorState =
                        _isError && index == _pinDisplay.length - 1;
                    return Container(
                      margin: const EdgeInsets.symmetric(horizontal: 10),
                      width: 18,
                      height: 18,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: filled
                            ? (isErrorState ? Colors.red : Colors.amber)
                            : Colors.transparent,
                        border: Border.all(
                          color: filled
                              ? (isErrorState ? Colors.red : Colors.amber)
                              : theme.dividerColor,
                          width: 2,
                        ),
                      ),
                    );
                  }),
                ),
              ),
              const SizedBox(height: 40),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 40),
                child: Column(
                  children: [
                    _buildNumberRow(['1', '2', '3']),
                    const SizedBox(height: 20),
                    _buildNumberRow(['4', '5', '6']),
                    const SizedBox(height: 20),
                    _buildNumberRow(['7', '8', '9']),
                    const SizedBox(height: 20),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const SizedBox(width: 70),
                        _buildNumberButton('0'),
                        const SizedBox(width: 20),
                        _buildBackspaceButton(),
                      ],
                    ),
                  ],
                ),
              ),
              const Spacer(flex: 1),
              if (widget.mode == PinMode.create &&
                  !_isConfirming &&
                  _pin.length == _pinLength)
                Padding(
                  padding: const EdgeInsets.only(bottom: 20),
                  child: SizedBox(
                    width: 200,
                    child: ElevatedButton(
                      onPressed: _startConfirm,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.amber,
                        foregroundColor: Colors.black,
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      child: const Text('Confirm PIN'),
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildNumberRow(List<String> digits) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: digits.map((digit) => _buildNumberButton(digit)).toList(),
    );
  }

  Widget _buildNumberButton(String digit) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 6),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: () => _onDigitPressed(digit),
          borderRadius: BorderRadius.circular(40),
          splashColor: Colors.amber.withOpacity(0.1),
          highlightColor: Colors.amber.withOpacity(0.05),
          child: Container(
            width: 70,
            height: 70,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              border: Border.all(color: Colors.grey.shade300, width: 0.5),
            ),
            child: Text(
              digit,
              style: const TextStyle(fontSize: 28, fontWeight: FontWeight.w300),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildBackspaceButton() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 6),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: _onBackspacePressed,
          borderRadius: BorderRadius.circular(40),
          splashColor: Colors.grey.withOpacity(0.1),
          highlightColor: Colors.grey.withOpacity(0.05),
          child: Container(
            width: 70,
            height: 70,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              border: Border.all(color: Colors.grey.shade300, width: 0.5),
            ),
            child: const Icon(
              Icons.backspace_outlined,
              size: 26,
              color: Colors.grey,
            ),
          ),
        ),
      ),
    );
  }
}
