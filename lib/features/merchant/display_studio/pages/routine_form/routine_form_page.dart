import 'package:flutter/material.dart';

import '../../../../../core/theme/appColors.dart';
import '../../../../../core/theme/appRadius.dart';
import '../../../../../core/theme/appSpacing.dart';
import '../../models/display_device.dart';
import '../../models/display_layout.dart';
import '../../models/display_routine.dart';
import '../../services/display_studio_service.dart';

class RoutineFormPage extends StatefulWidget {
  const RoutineFormPage({
    super.key,
    required this.service,
    required this.layouts,
    required this.devices,
    this.existing,
  });

  final DisplayStudioService service;
  final List<DisplayLayout> layouts;
  final List<DisplayDevice> devices;
  final DisplayRoutine? existing;

  @override
  State<RoutineFormPage> createState() => _RoutineFormPageState();
}

class _RoutineFormPageState extends State<RoutineFormPage> {
  final _titleCtrl = TextEditingController();
  final Set<int> _days = {}; // 1=Mo … 7=So
  TimeOfDay _startTime = const TimeOfDay(hour: 8, minute: 0);
  TimeOfDay _endTime = const TimeOfDay(hour: 20, minute: 0);
  final Set<String> _selectedDeviceIds = {};
  final Set<String> _selectedLayoutIds = {};
  bool _isActive = true;
  String _animation = 'fade';
  bool _isSaving = false;

  static const _dayNames = ['Mo', 'Di', 'Mi', 'Do', 'Fr', 'Sa', 'So'];

  @override
  void initState() {
    super.initState();
    final e = widget.existing;
    if (e != null) {
      _titleCtrl.text = e.title;
      _days.addAll(e.days);
      _startTime = _parseTime(e.startTime);
      _endTime = _parseTime(e.endTime);
      _selectedDeviceIds.addAll(e.deviceIds);
      _selectedLayoutIds.addAll(e.layoutIds);
      _isActive = e.isActive;
      _animation = e.animation;
    }
  }

  @override
  void dispose() {
    _titleCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isEdit = widget.existing != null;

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.background,
        elevation: 0,
        scrolledUnderElevation: 0,
        title: Text(isEdit ? 'Routine bearbeiten' : 'Routine erstellen',
            style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 18)),
        actions: [
          if (_isSaving)
            const Padding(
              padding: EdgeInsets.symmetric(horizontal: 16),
              child: Center(child: SizedBox(width: 18, height: 18,
                  child: CircularProgressIndicator(strokeWidth: 2))),
            )
          else
            TextButton(
              onPressed: _save,
              child: const Text('Speichern',
                  style: TextStyle(color: AppColors.black, fontWeight: FontWeight.w900)),
            ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(AppSpacing.md),
        children: [
          _card([
            TextFormField(
              controller: _titleCtrl,
              decoration: InputDecoration(
                labelText: 'Titel der Routine',
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                isDense: true,
              ),
            ),
          ], title: 'Allgemein'),

          const SizedBox(height: AppSpacing.md),

          _card([
            const Text('Tage', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w800, color: AppColors.gray500)),
            const SizedBox(height: 10),
            Wrap(
              spacing: 8, runSpacing: 6,
              children: List.generate(7, (i) {
                final day = i + 1;
                final sel = _days.contains(day);
                return GestureDetector(
                  onTap: () => setState(() => sel ? _days.remove(day) : _days.add(day)),
                  child: Container(
                    width: 40, height: 40,
                    decoration: BoxDecoration(
                      color: sel ? AppColors.black : AppColors.gray50,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: sel ? AppColors.black : AppColors.border),
                    ),
                    child: Center(
                      child: Text(_dayNames[i],
                          style: TextStyle(
                              fontSize: 12, fontWeight: FontWeight.w900,
                              color: sel ? AppColors.white : AppColors.gray700)),
                    ),
                  ),
                );
              }),
            ),
            const SizedBox(height: AppSpacing.md),
            Row(children: [
              Expanded(child: _TimePicker(
                label: 'Startzeit',
                time: _startTime,
                onChanged: (t) => setState(() => _startTime = t),
              )),
              const SizedBox(width: 10),
              Expanded(child: _TimePicker(
                label: 'Endzeit',
                time: _endTime,
                onChanged: (t) => setState(() => _endTime = t),
              )),
            ]),
          ], title: 'Zeitplan'),

          const SizedBox(height: AppSpacing.md),

          _card([
            if (widget.devices.isEmpty)
              const Text('Noch keine Displays verbunden.',
                  style: TextStyle(color: AppColors.gray500))
            else
              ...widget.devices.map((d) => _CheckRow(
                    label: d.name,
                    sublabel: d.status.label,
                    selected: _selectedDeviceIds.contains(d.id),
                    onToggle: () => setState(() => _selectedDeviceIds.contains(d.id)
                        ? _selectedDeviceIds.remove(d.id)
                        : _selectedDeviceIds.add(d.id)),
                  )),
          ], title: 'Displays'),

          const SizedBox(height: AppSpacing.md),

          _card([
            if (widget.layouts.isEmpty)
              const Text('Noch keine Layouts erstellt.',
                  style: TextStyle(color: AppColors.gray500))
            else
              ...widget.layouts.map((l) => _CheckRow(
                    label: l.title.isEmpty ? 'Ohne Titel' : l.title,
                    sublabel: l.type.label,
                    selected: _selectedLayoutIds.contains(l.id),
                    onToggle: () => setState(() => _selectedLayoutIds.contains(l.id)
                        ? _selectedLayoutIds.remove(l.id)
                        : _selectedLayoutIds.add(l.id)),
                  )),
          ], title: 'Layouts'),

          const SizedBox(height: AppSpacing.md),

          _card([
            const Text('Animation', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w800, color: AppColors.gray500)),
            const SizedBox(height: 8),
            Wrap(spacing: 8, runSpacing: 6,
              children: const {
                'fade': 'Fade', 'slide': 'Slide',
                'softZoom': 'Soft Zoom', 'cardSwitch': 'Card Switch',
              }.entries.map((e) {
                return _SegChip(
                  label: e.value,
                  selected: _animation == e.key,
                  onTap: () => setState(() => _animation = e.key),
                );
              }).toList(),
            ),
            const SizedBox(height: AppSpacing.md),
            Row(children: [
              const Expanded(child: Text('Routine aktiv', style: TextStyle(fontWeight: FontWeight.w800))),
              Switch(
                value: _isActive, activeThumbColor: AppColors.black,
                onChanged: (v) => setState(() => _isActive = v),
              ),
            ]),
          ], title: 'Optionen'),

          const SizedBox(height: AppSpacing.xl),

          FilledButton(
            onPressed: _isSaving ? null : _save,
            style: FilledButton.styleFrom(
              backgroundColor: AppColors.black,
              minimumSize: Size.zero,
              tapTargetSize: MaterialTapTargetSize.shrinkWrap,
              padding: const EdgeInsets.symmetric(vertical: 15),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppRadius.large)),
            ),
            child: Text(isEdit ? 'Änderungen speichern' : 'Routine erstellen',
                style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 16)),
          ),
        ],
      ),
    );
  }

  Widget _card(List<Widget> children, {required String title}) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(title,
            style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w800, color: AppColors.gray500)),
        const SizedBox(height: 8),
        Container(
          padding: const EdgeInsets.all(AppSpacing.md),
          decoration: BoxDecoration(
            color: AppColors.surface,
            borderRadius: BorderRadius.circular(AppRadius.xl),
            border: Border.all(color: AppColors.border),
          ),
          child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: children),
        ),
      ],
    );
  }

  String _fmt(TimeOfDay t) =>
      '${t.hour.toString().padLeft(2, '0')}:${t.minute.toString().padLeft(2, '0')}';

  TimeOfDay _parseTime(String s) {
    final parts = s.split(':');
    if (parts.length < 2) return const TimeOfDay(hour: 8, minute: 0);
    return TimeOfDay(
        hour: int.tryParse(parts[0]) ?? 8,
        minute: int.tryParse(parts[1]) ?? 0);
  }

  Future<void> _save() async {
    if (_titleCtrl.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Bitte einen Titel eingeben.')));
      return;
    }
    setState(() => _isSaving = true);

    try {
      final routine = DisplayRoutine(
        id: widget.existing?.id ?? '',
        title: _titleCtrl.text.trim(),
        deviceIds: _selectedDeviceIds.toList(),
        layoutIds: _selectedLayoutIds.toList(),
        days: _days.toList()..sort(),
        startTime: _fmt(_startTime),
        endTime: _fmt(_endTime),
        isActive: _isActive,
        animation: _animation,
        createdAt: widget.existing?.createdAt,
        updatedAt: null,
      );

      if (widget.existing == null) {
        await widget.service.createRoutine(routine);
      } else {
        await widget.service.updateRoutine(routine);
      }

      if (mounted) Navigator.of(context).pop();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Fehler: $e')));
      }
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }
}

class _TimePicker extends StatelessWidget {
  const _TimePicker({required this.label, required this.time, required this.onChanged});
  final String label;
  final TimeOfDay time;
  final void Function(TimeOfDay) onChanged;

  @override
  Widget build(BuildContext context) {
    final fmt =
        '${time.hour.toString().padLeft(2, '0')}:${time.minute.toString().padLeft(2, '0')}';
    return GestureDetector(
      onTap: () async {
        final picked = await showTimePicker(context: context, initialTime: time);
        if (picked != null) onChanged(picked);
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
        decoration: BoxDecoration(
          color: AppColors.gray50,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: AppColors.border),
        ),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(label,
              style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: AppColors.gray500)),
          const SizedBox(height: 3),
          Text(fmt, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w900)),
        ]),
      ),
    );
  }
}

class _CheckRow extends StatelessWidget {
  const _CheckRow({required this.label, required this.sublabel,
      required this.selected, required this.onToggle});
  final String label;
  final String sublabel;
  final bool selected;
  final VoidCallback onToggle;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: InkWell(
        onTap: onToggle,
        borderRadius: BorderRadius.circular(10),
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 4),
          child: Row(children: [
            Container(
              width: 22, height: 22,
              decoration: BoxDecoration(
                color: selected ? AppColors.black : Colors.transparent,
                borderRadius: BorderRadius.circular(6),
                border: Border.all(color: selected ? AppColors.black : AppColors.gray300),
              ),
              child: selected
                  ? const Icon(Icons.check_rounded, size: 14, color: AppColors.white)
                  : null,
            ),
            const SizedBox(width: 10),
            Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(label, style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 14)),
              Text(sublabel, style: const TextStyle(color: AppColors.gray500, fontSize: 12)),
            ])),
          ]),
        ),
      ),
    );
  }
}

class _SegChip extends StatelessWidget {
  const _SegChip({required this.label, required this.selected, required this.onTap});
  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
        decoration: BoxDecoration(
          color: selected ? AppColors.black : AppColors.gray50,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: selected ? AppColors.black : AppColors.border),
        ),
        child: Text(label,
            style: TextStyle(
                fontSize: 12, fontWeight: FontWeight.w800,
                color: selected ? AppColors.white : AppColors.gray700)),
      ),
    );
  }
}
