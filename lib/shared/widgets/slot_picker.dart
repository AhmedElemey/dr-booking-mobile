import 'package:flutter/material.dart';

import '../../core/format/clinic_time.dart';
import '../../features/doctor/domain/doctor_slots.dart';

/// A date strip plus a grid of the selected day's open slots. Everything is
/// shown in clinic time, taken from the API's `date` and `local` fields.
class SlotPicker extends StatefulWidget {
  const SlotPicker({
    super.key,
    required this.slots,
    required this.selected,
    required this.onSelected,
  });

  final DoctorSlots slots;
  final Slot? selected;
  final ValueChanged<Slot> onSelected;

  @override
  State<SlotPicker> createState() => _SlotPickerState();
}

class _SlotPickerState extends State<SlotPicker> {
  late List<SlotDay> _days;
  late int _dayIndex;

  @override
  void initState() {
    super.initState();
    _days = _nonEmptyDays();
    _dayIndex = _indexOfSelected();
  }

  @override
  void didUpdateWidget(SlotPicker oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.slots != widget.slots) {
      _days = _nonEmptyDays();
      _dayIndex = _dayIndex.clamp(0, _days.length - 1);
    }
  }

  List<SlotDay> _nonEmptyDays() => [
    for (final day in widget.slots.days)
      if (day.slots.isNotEmpty) day,
  ];

  int _indexOfSelected() {
    final selected = widget.selected;
    if (selected == null) return 0;
    final index = _days.indexWhere(
      (d) => d.slots.any((s) => s.id == selected.id),
    );
    return index < 0 ? 0 : index;
  }

  @override
  Widget build(BuildContext context) {
    final locale = Localizations.localeOf(context).languageCode;
    final theme = Theme.of(context);
    final day = _days[_dayIndex];
    final date = ClinicTime.parseDate(day.date);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          height: 82,
          child: ListView.separated(
            padding: const EdgeInsetsDirectional.symmetric(horizontal: 16),
            scrollDirection: Axis.horizontal,
            itemCount: _days.length,
            separatorBuilder: (context, _) => const SizedBox(width: 8),
            itemBuilder: (context, index) {
              final d = ClinicTime.parseDate(_days[index].date);
              final selected = index == _dayIndex;
              final scheme = theme.colorScheme;
              return Material(
                color: selected ? scheme.primary : Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14),
                  side: BorderSide(
                    color: selected ? scheme.primary : scheme.outlineVariant,
                  ),
                ),
                child: InkWell(
                  key: Key('day-${_days[index].date}'),
                  borderRadius: BorderRadius.circular(14),
                  onTap: () => setState(() => _dayIndex = index),
                  child: SizedBox(
                    width: 64,
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text(
                          ClinicTime.weekday(d, locale),
                          style: theme.textTheme.labelMedium?.copyWith(
                            color: selected
                                ? scheme.onPrimary
                                : scheme.onSurfaceVariant,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          ClinicTime.dayNumber(d, locale),
                          style: theme.textTheme.titleLarge?.copyWith(
                            color: selected ? scheme.onPrimary : null,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              );
            },
          ),
        ),
        Padding(
          padding: const EdgeInsetsDirectional.fromSTEB(16, 16, 16, 8),
          child: Text(
            ClinicTime.date(date, locale),
            style: theme.textTheme.titleSmall,
          ),
        ),
        Expanded(
          child: GridView.builder(
            padding: const EdgeInsetsDirectional.fromSTEB(16, 4, 16, 16),
            gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
              maxCrossAxisExtent: 110,
              mainAxisExtent: 46,
              crossAxisSpacing: 10,
              mainAxisSpacing: 10,
            ),
            itemCount: day.slots.length,
            itemBuilder: (context, index) {
              final slot = day.slots[index];
              final label = ClinicTime.time(
                ClinicTime.parseTime(slot.local),
                locale,
              );
              return ChoiceChip(
                key: Key('slot-${slot.id}'),
                label: SizedBox(
                  width: double.infinity,
                  child: Text(label, textAlign: TextAlign.center),
                ),
                selected: widget.selected?.id == slot.id,
                showCheckmark: false,
                onSelected: (_) => widget.onSelected(slot),
              );
            },
          ),
        ),
      ],
    );
  }
}
