// F.R.I.D.A.Y. Mobile — Entry Point
// Inicializa o app com Provider, theme neural e conecta ao Hub salvo.

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'theme/neural_theme.dart';
import 'services/ws_service.dart';
import 'screens/home_screen.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Forçar orientação portrait
  await SystemChrome.setPreferredOrientations([
    DeviceOrientation.portraitUp,
    DeviceOrientation.portraitDown,
  ]);

  // Barra de status transparente para efeito full-bleed
  SystemChrome.setSystemUIOverlayStyle(const SystemUiOverlayStyle(
    statusBarColor: Colors.transparent,
    statusBarIconBrightness: Brightness.light,
    systemNavigationBarColor: NColor.bgVoid,
    systemNavigationBarIconBrightness: Brightness.light,
  ));

  runApp(const FridayApp());
}

class FridayApp extends StatelessWidget {
  const FridayApp({super.key});

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider(
      create: (_) {
        final ws = WebSocketService();
        // Carrega host salvo e conecta automaticamente
        ws.loadSavedHost().then((_) => ws.connect());
        return ws;
      },
      child: MaterialApp(
        title: 'F.R.I.D.A.Y.',
        debugShowCheckedModeBanner: false,
        theme: buildNeuralTheme(),
        home: const _SplashGate(),
      ),
    );
  }
}

// ── Splash de Boot ────────────────────────────────────────────────────────────
class _SplashGate extends StatefulWidget {
  const _SplashGate();

  @override
  State<_SplashGate> createState() => _SplashGateState();
}

class _SplashGateState extends State<_SplashGate>
    with SingleTickerProviderStateMixin {

  late AnimationController _ctrl;
  late Animation<double>   _fadeAnim;
  late Animation<double>   _scaleAnim;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    );
    _fadeAnim  = CurvedAnimation(parent: _ctrl, curve: Curves.easeOut);
    _scaleAnim = Tween<double>(begin: 0.85, end: 1.0).animate(
      CurvedAnimation(parent: _ctrl, curve: Curves.easeOutCubic),
    );
    _ctrl.forward().then((_) {
      Future.delayed(const Duration(milliseconds: 600), () {
        if (mounted) {
          Navigator.of(context).pushReplacement(
            PageRouteBuilder(
              pageBuilder: (_, __, ___) => const HomeScreen(),
              transitionsBuilder: (_, anim, __, child) =>
                  FadeTransition(opacity: anim, child: child),
              transitionDuration: const Duration(milliseconds: 500),
            ),
          );
        }
      });
    });
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: NColor.bgVoid,
      body: Center(
        child: FadeTransition(
          opacity: _fadeAnim,
          child: ScaleTransition(
            scale: _scaleAnim,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Glow circle
                Container(
                  width: 100, height: 100,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: NColor.bgDeep,
                    border: Border.all(color: NColor.cyan.withOpacity(0.5), width: 1.5),
                    boxShadow: glowCyan(intensity: 0.8),
                  ),
                  child: const Icon(Icons.mic_none, color: NColor.cyan, size: 40),
                ),
                const SizedBox(height: 24),
                const Text(
                  'F.R.I.D.A.Y.',
                  style: TextStyle(
                    fontFamily: 'monospace',
                    fontSize: 26,
                    fontWeight: FontWeight.w900,
                    color: NColor.cyan,
                    letterSpacing: 6,
                  ),
                ),
                const SizedBox(height: 8),
                const Text(
                  'NEURAL COMMAND INTERFACE',
                  style: TextStyle(
                    fontFamily: 'monospace',
                    fontSize: 9,
                    color: NColor.textMuted,
                    letterSpacing: 4,
                  ),
                ),
                const SizedBox(height: 32),
                SizedBox(
                  width: 120,
                  child: LinearProgressIndicator(
                    backgroundColor: NColor.border,
                    valueColor: const AlwaysStoppedAnimation(NColor.cyan),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
