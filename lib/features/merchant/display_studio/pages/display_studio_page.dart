import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../../core/services/authService.dart';
import '../../../../core/services/firestoreService.dart';
import '../../../../core/theme/appColors.dart';
import '../../../../core/widgets/appErrorState.dart';
import '../providers/display_studio_provider.dart';
import '../services/display_studio_service.dart';
import 'display_devices_tab.dart';
import 'display_layouts_tab.dart';
import 'display_routines_tab.dart';
import 'display_scan_tab.dart';

class DisplayStudioPage extends StatelessWidget {
  const DisplayStudioPage({super.key});

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider(
      create: (context) => DisplayStudioProvider(
        service: DisplayStudioService(
          firestoreService: context.read<FirestoreService>(),
          authService: context.read<AuthService>(),
        ),
      )..ensureConfig(),
      child: const _DisplayStudioView(),
    );
  }
}

class _DisplayStudioView extends StatefulWidget {
  const _DisplayStudioView();

  @override
  State<_DisplayStudioView> createState() => _DisplayStudioViewState();
}

class _DisplayStudioViewState extends State<_DisplayStudioView> {
  int _selectedIndex = 0;
  DisplayStudioProvider? _provider;

  @override
  void initState() {
    super.initState();
    _provider = context.read<DisplayStudioProvider>()
      ..addListener(_onProviderChanged);
  }

  @override
  void dispose() {
    _provider?.removeListener(_onProviderChanged);
    super.dispose();
  }

  // Aktions-Fehler (#8) als SnackBar zeigen statt still zu verschlucken. Per
  // Post-Frame, damit kein Re-Entrancy/Build-Konflikt entsteht.
  void _onProviderChanged() {
    final err = _provider?.error;
    if (err == null) return;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(err.replaceFirst('Exception: ', ''))),
      );
      _provider?.clearError();
    });
  }

  static const _tabs = [
    _TabEntry(icon: Icons.tv_rounded, label: 'Displays'),
    _TabEntry(icon: Icons.dashboard_rounded, label: 'Layouts'),
    _TabEntry(icon: Icons.schedule_rounded, label: 'Routine'),
    _TabEntry(icon: Icons.qr_code_scanner_rounded, label: 'Scannen'),
  ];

  static const _pages = [
    DisplayDevicesTab(),
    DisplayLayoutsTab(),
    DisplayRoutinesTab(),
    DisplayScanTab(),
  ];

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<DisplayStudioProvider>();
    final isLoading = provider.isLoading;
    final loadError = provider.loadError;

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.background,
        elevation: 0,
        scrolledUnderElevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_rounded),
          onPressed: () => Navigator.of(context).pop(),
        ),
        title: const Text(
          'Display Studio',
          style: TextStyle(fontWeight: FontWeight.w900, fontSize: 18),
        ),
        actions: [
          if (provider.isBusy)
            const Padding(
              padding: EdgeInsets.only(right: 16),
              child: Center(
                child: SizedBox(
                  width: 18,
                  height: 18,
                  child: CircularProgressIndicator(strokeWidth: 2),
                ),
              ),
            ),
        ],
      ),
      body: SafeArea(
        child: isLoading
            ? const Center(child: CircularProgressIndicator())
            : loadError != null
                ? AppErrorState(
                    message: 'Display Studio konnte nicht geladen werden.',
                    onRetry: provider.retry,
                  )
                : Row(
                children: [
                  _StudioRail(
                    selectedIndex: _selectedIndex,
                    tabs: _tabs,
                    onSelect: (i) => setState(() => _selectedIndex = i),
                  ),
                  const VerticalDivider(thickness: 1, width: 1),
                  Expanded(
                    child: IndexedStack(
                      index: _selectedIndex,
                      children: _pages,
                    ),
                  ),
                ],
              ),
      ),
    );
  }
}

class _TabEntry {
  const _TabEntry({required this.icon, required this.label});
  final IconData icon;
  final String label;
}

class _StudioRail extends StatelessWidget {
  const _StudioRail({
    required this.selectedIndex,
    required this.tabs,
    required this.onSelect,
  });

  final int selectedIndex;
  final List<_TabEntry> tabs;
  final ValueChanged<int> onSelect;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 68,
      color: AppColors.background,
      child: Column(
        children: [
          const SizedBox(height: 8),
          ...List.generate(tabs.length, (i) {
            final tab = tabs[i];
            final isActive = i == selectedIndex;
            return Tooltip(
              message: tab.label,
              preferBelow: false,
              child: GestureDetector(
                onTap: () => onSelect(i),
                child: Container(
                  width: 52,
                  margin: const EdgeInsets.symmetric(vertical: 3),
                  padding: const EdgeInsets.symmetric(vertical: 10),
                  decoration: BoxDecoration(
                    color: isActive ? AppColors.black : Colors.transparent,
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        tab.icon,
                        size: 22,
                        color: isActive ? AppColors.white : AppColors.gray500,
                      ),
                      const SizedBox(height: 4),
                      Text(
                        tab.label,
                        style: TextStyle(
                          fontSize: 9,
                          fontWeight: FontWeight.w800,
                          color: isActive ? AppColors.white : AppColors.gray500,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),
              ),
            );
          }),
        ],
      ),
    );
  }
}
