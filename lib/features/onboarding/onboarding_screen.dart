import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../home/home_screen.dart';

class OnboardingScreen extends StatefulWidget {
  const OnboardingScreen({super.key});

  @override
  State<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends State<OnboardingScreen> {
  final PageController _controller = PageController();
  int _currentPage = 0;

  final List<_OnboardingPage> _pages = const [
    _OnboardingPage(
      icon: Icons.document_scanner,
      title: 'Bienvenido a ScanPro',
      description:
          'La forma más fácil de escanear, organizar y exportar tus '
          'documentos desde tu móvil.\n\nTodo 100% offline y privado.',
      color: Color(0xFF1E6FFF),
      illustration: _IllustrationType.welcome,
    ),
    _OnboardingPage(
      icon: Icons.document_scanner_outlined,
      title: 'Escanea con la cámara',
      description:
          'Pulsa el botón "+" y elige "Escanear documento".\n\n'
          'ML Kit detecta los bordes automáticamente, corrige la '
          'perspectiva y mejora la imagen.',
      color: Color(0xFF00C853),
      illustration: _IllustrationType.scan,
    ),
    _OnboardingPage(
      icon: Icons.folder_special,
      title: 'Organiza con carpetas',
      description:
          'Crea carpetas desde la pestaña "Carpetas".\n\n'
          'Mantén pulsado un documento para moverlo a una o varias '
          'carpetas.',
      color: Color(0xFFFF6D00),
      illustration: _IllustrationType.folders,
    ),
    _OnboardingPage(
      icon: Icons.picture_as_pdf,
      title: 'Exporta y comparte',
      description:
          'Abre un documento y pulsa ⋮ → "Exportar".\n\n'
          'Guarda como PDF, JPG o PNG. Elige la carpeta de destino '
          'o comparte con quien quieras.',
      color: Color(0xFF9C27B0),
      illustration: _IllustrationType.export,
    ),
  ];

  Future<void> _finish() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('onboarding_done', true);

    if (!mounted) return;
    Navigator.pushReplacement(
      context,
      MaterialPageRoute(builder: (_) => const HomeScreen()),
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isLastPage = _currentPage == _pages.length - 1;

    return Scaffold(
      body: SafeArea(
        child: Column(
          children: [
            // ── Botón "Saltar" ──
            SizedBox(
              height: 48,
              child: Align(
                alignment: Alignment.centerRight,
                child: AnimatedOpacity(
                  duration: const Duration(milliseconds: 200),
                  opacity: isLastPage ? 0 : 1,
                  child: TextButton(
                    onPressed: isLastPage ? null : _finish,
                    child: const Text(
                      'Saltar',
                      style: TextStyle(fontSize: 15),
                    ),
                  ),
                ),
              ),
            ),

            // ── Contenido de las páginas ──
            Expanded(
              child: PageView.builder(
                controller: _controller,
                itemCount: _pages.length,
                onPageChanged: (i) => setState(() => _currentPage = i),
                itemBuilder: (context, i) => _OnboardingPageView(
                  page: _pages[i],
                  isActive: _currentPage == i,
                ),
              ),
            ),

            // ── Indicadores ──
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: List.generate(
                _pages.length,
                (i) => AnimatedContainer(
                  duration: const Duration(milliseconds: 300),
                  margin: const EdgeInsets.symmetric(horizontal: 4),
                  width: _currentPage == i ? 28 : 8,
                  height: 8,
                  decoration: BoxDecoration(
                    color: _currentPage == i
                        ? _pages[_currentPage].color
                        : Colors.grey.shade300,
                    borderRadius: BorderRadius.circular(4),
                  ),
                ),
              ),
            ),
            const SizedBox(height: 32),

            // ── Botón Siguiente / Empezar ──
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 32),
              child: SizedBox(
                width: double.infinity,
                height: 56,
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 300),
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(16),
                    boxShadow: [
                      BoxShadow(
                        color: _pages[_currentPage]
                            .color
                            .withOpacity(0.3),
                        blurRadius: 12,
                        offset: const Offset(0, 4),
                      ),
                    ],
                  ),
                  child: FilledButton(
                    style: FilledButton.styleFrom(
                      backgroundColor: _pages[_currentPage].color,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16),
                      ),
                    ),
                    onPressed: () {
                      if (isLastPage) {
                        _finish();
                      } else {
                        _controller.nextPage(
                          duration: const Duration(milliseconds: 400),
                          curve: Curves.easeInOut,
                        );
                      }
                    },
                    child: Text(
                      isLastPage ? 'Empezar ahora' : 'Siguiente',
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                        color: Colors.white,
                      ),
                    ),
                  ),
                ),
              ),
            ),
            const SizedBox(height: 32),
          ],
        ),
      ),
    );
  }
}

// ═════════════════════════════════════════════════════════════
// MODELO DE PÁGINA
// ═════════════════════════════════════════════════════════════
enum _IllustrationType { welcome, scan, folders, export }

class _OnboardingPage {
  final IconData icon;
  final String title;
  final String description;
  final Color color;
  final _IllustrationType illustration;

  const _OnboardingPage({
    required this.icon,
    required this.title,
    required this.description,
    required this.color,
    required this.illustration,
  });
}

// ═════════════════════════════════════════════════════════════
// VISTA DE UNA PÁGINA
// ═════════════════════════════════════════════════════════════
class _OnboardingPageView extends StatelessWidget {
  final _OnboardingPage page;
  final bool isActive;

  const _OnboardingPageView({
    required this.page,
    required this.isActive,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 32),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          // ── Ilustración animada ──
          AnimatedScale(
            duration: const Duration(milliseconds: 400),
            scale: isActive ? 1.0 : 0.8,
            curve: Curves.easeOutBack,
            child: AnimatedOpacity(
              duration: const Duration(milliseconds: 400),
              opacity: isActive ? 1 : 0,
              child: _buildIllustration(),
            ),
          ),
          const SizedBox(height: 48),

          // ── Título ──
          AnimatedSlide(
            duration: const Duration(milliseconds: 400),
            offset: isActive ? Offset.zero : const Offset(0, 0.2),
            child: AnimatedOpacity(
              duration: const Duration(milliseconds: 400),
              opacity: isActive ? 1 : 0,
              child: Text(
                page.title,
                textAlign: TextAlign.center,
                style: const TextStyle(
                  fontSize: 28,
                  fontWeight: FontWeight.bold,
                  height: 1.2,
                ),
              ),
            ),
          ),
          const SizedBox(height: 20),

          // ── Descripción ──
          AnimatedSlide(
            duration: const Duration(milliseconds: 500),
            offset: isActive ? Offset.zero : const Offset(0, 0.2),
            child: AnimatedOpacity(
              duration: const Duration(milliseconds: 500),
              opacity: isActive ? 1 : 0,
              child: Text(
                page.description,
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 15,
                  color: Colors.grey.shade700,
                  height: 1.6,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildIllustration() {
    return Container(
      width: 200,
      height: 200,
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            page.color.withOpacity(0.2),
            page.color.withOpacity(0.05),
          ],
        ),
        shape: BoxShape.circle,
      ),
      child: Center(
        child: Container(
          width: 140,
          height: 140,
          decoration: BoxDecoration(
            color: page.color,
            shape: BoxShape.circle,
            boxShadow: [
              BoxShadow(
                color: page.color.withOpacity(0.4),
                blurRadius: 20,
                offset: const Offset(0, 8),
              ),
            ],
          ),
          child: Icon(
            page.icon,
            size: 70,
            color: Colors.white,
          ),
        ),
      ),
    );
  }
}