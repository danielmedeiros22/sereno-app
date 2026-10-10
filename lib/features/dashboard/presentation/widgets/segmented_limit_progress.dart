import 'package:flutter/material.dart';
import '../../../../app/theme/app_colors.dart';

class SegmentedLimitProgress extends StatelessWidget {
  const SegmentedLimitProgress({super.key, required this.percent});
  final double percent;

  @override
  Widget build(BuildContext context) {
    final value =
        percent.isFinite ? percent.clamp(0, double.infinity).toDouble() : 0.0;
    final color = AppColors.riskFor(value);
    final label = '${value.toStringAsFixed(0)}% do teto utilizado';
    return Semantics(
        label: label,
        child: ExcludeSemantics(
            child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
                children: List.generate(
                    10,
                    (index) => Expanded(
                            child: Padding(
                          padding: EdgeInsets.only(right: index == 9 ? 0 : 4),
                          child: ClipRRect(
                              borderRadius: BorderRadius.circular(3),
                              child: LinearProgressIndicator(
                                value:
                                    (value / 10 - index).clamp(0, 1).toDouble(),
                                minHeight: 9,
                                color: color,
                                backgroundColor:
                                    Theme.of(context).colorScheme.outline,
                              )),
                        )))),
            const SizedBox(height: 8),
            Text(label,
                style: Theme.of(context)
                    .textTheme
                    .labelMedium
                    ?.copyWith(color: color)),
          ],
        )));
  }
}
