import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../app/glass.dart';
import '../../app/theme.dart';
import '../../core/day.dart';
import '../../core/money.dart';

/// Raised panel. Never nested inside another panel.
class Panel extends StatelessWidget {
  const Panel({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(20),
  });
  final Widget child;
  final EdgeInsetsGeometry padding;

  @override
  Widget build(BuildContext context) => SizedBox(
    width: double.infinity,
    child: Glass(padding: padding, child: child),
  );
}

class SectionTitle extends StatelessWidget {
  const SectionTitle(this.text, {super.key, this.trailing});
  final String text;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.fromLTRB(4, 28, 4, 10),
    child: Row(
      children: [
        Expanded(
          child: Semantics(
            header: true,
            child: Text(text, style: Theme.of(context).textTheme.titleMedium),
          ),
        ),
        ?trailing,
      ],
    ),
  );
}

/// A label with its value on the right: the plain-list alternative to a grid of stat tiles.
class StatRow extends StatelessWidget {
  const StatRow(
    this.label,
    this.value, {
    super.key,
    this.note,
    this.color,
    this.onTap,
  });
  final String label, value;
  final String? note;
  final Color? color;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: ConstrainedBox(
        constraints: const BoxConstraints(minHeight: 52),
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 8),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      label,
                      style: t.bodyMedium?.copyWith(
                        color: context.palette.muted,
                      ),
                    ),
                    if (note != null)
                      Text(
                        note!,
                        style: t.bodySmall?.copyWith(
                          color: context.palette.muted,
                        ),
                      ),
                  ],
                ),
              ),
              const SizedBox(width: 12),
              Text(
                value,
                style: t.titleMedium?.copyWith(
                  fontWeight: FontWeight.w700,
                  color: color,
                  fontFeatures: const [FontFeature.tabularFigures()],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Amount input that accepts commas and sums ("1200+300"). The key toggles number pad / full
/// keyboard, so dates ("26 apr 5000") can be typed too.
class AmountField extends StatefulWidget {
  const AmountField({
    super.key,
    required this.controller,
    this.label = 'Amount',
    this.onChanged,
    this.autofocus = false,
    this.errorText,
  });
  final TextEditingController controller;
  final String label;
  final ValueChanged<String>? onChanged;
  final bool autofocus;
  final String? errorText;

  @override
  State<AmountField> createState() => _AmountFieldState();
}

class _AmountFieldState extends State<AmountField> {
  bool _full = false;

  @override
  Widget build(BuildContext context) => TextField(
    controller: widget.controller,
    autofocus: widget.autofocus,
    onChanged: widget.onChanged,
    keyboardType: _full
        ? TextInputType.text
        : const TextInputType.numberWithOptions(decimal: true, signed: true),
    inputFormatters: [
      FilteringTextInputFormatter.deny(RegExp(r'[^\w\s.,+\-−]')),
    ],
    style: Theme.of(context).textTheme.titleLarge,
    decoration: InputDecoration(
      labelText: widget.label,
      errorText: widget.errorText,
      suffixIcon: IconButton(
        tooltip: _full
            ? 'Number keyboard'
            : 'Full keyboard, for sums and dates',
        icon: Icon(_full ? Icons.dialpad : Icons.keyboard_alt_outlined),
        onPressed: () => setState(() => _full = !_full),
      ),
    ),
  );
}

/// Parses an amount field that must hold a positive number.
int? positiveMoney(String text) {
  final v = parseMoney(text);
  return v != null && v > 0 ? v : null;
}

Future<Day?> pickDay(BuildContext context, Day initial, {Day? first}) async {
  final d = await showDatePicker(
    context: context,
    initialDate: initial,
    firstDate: first ?? DateTime(2000),
    lastDate: DateTime.now(),
  );
  return d == null ? null : dayOf(d);
}
