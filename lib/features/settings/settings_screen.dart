import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../data/services/storage_service.dart';
import '../onboarding/onboarding_screen.dart';

class SettingsScreen extends ConsumerWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Scaffold(
      appBar: AppBar(title: const Text('Ajustes')),
      body: ListView(
        children: [
          const ListTile(
            title: Text('ScanPro'),
            subtitle: Text('Versión 1.0.0'),
            leading: Icon(Icons.info_outline),
          ),
          const Divider(),
          ListTile(
            leading: const Icon(Icons.cleaning_services_outlined),
            title: const Text('Tamaño de almacenamiento'),
            subtitle: FutureBuilder<int>(
              future: StorageService().getStorageSize(),
              builder: (context, snap) {
                if (!snap.hasData) return const Text('Calculando...');
                final mb = (snap.data! / 1024 / 1024).toStringAsFixed(2);
                return Text('$mb MB usados');
              },
            ),
          ),
          const Divider(),

          // ⬇️ NUEVO: ver tutorial
          ListTile(
            leading: const Icon(Icons.play_circle_outline),
            title: const Text('Ver tutorial de bienvenida'),
            trailing: const Icon(Icons.chevron_right),
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => const OnboardingScreen(),
                ),
              );
            },
          ),

          // ⬇️ NUEVO: resetear onboarding (se verá la próxima vez)
          ListTile(
            leading: const Icon(Icons.refresh, color: Colors.orange),
            title: const Text('Resetear bienvenida'),
            subtitle: const Text(
              'La próxima vez que abras la app, verás el tutorial',
            ),
            onTap: () async {
              final confirm = await showDialog<bool>(
                context: context,
                builder: (_) => AlertDialog(
                  title: const Text('¿Resetear bienvenida?'),
                  content: const Text(
                    'La próxima vez que abras la app, '
                    'verás el tutorial de nuevo.',
                  ),
                  actions: [
                    TextButton(
                      onPressed: () => Navigator.pop(context, false),
                      child: const Text('Cancelar'),
                    ),
                    FilledButton(
                      onPressed: () => Navigator.pop(context, true),
                      child: const Text('Resetear'),
                    ),
                  ],
                ),
              );
              if (confirm == true) {
                final prefs = await SharedPreferences.getInstance();
                await prefs.setBool('onboarding_done', false);
                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('Bienvenida reseteada'),
                    ),
                  );
                }
              }
            },
          ),
          const Divider(),
          const ListTile(
            leading: Icon(Icons.privacy_tip_outlined),
            title: Text('Política de privacidad'),
            trailing: Icon(Icons.chevron_right),
          ),
        ],
      ),
    );
  }
}