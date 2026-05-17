import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../../bloc/battle_map_bloc.dart';

class StatusHud extends StatelessWidget {
  const StatusHud({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<BattleMapBloc, BattleMapState>(
      builder: (context, state) {
        final isComputing = state.status == GameTurnStatus.generatingProof;
        return Padding(
          padding: const EdgeInsets.fromLTRB(12, 8, 12, 0),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(14),
            child: BackdropFilter(
              filter: ImageFilter.blur(sigmaX: 14, sigmaY: 14),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 11),
                decoration: BoxDecoration(
                  color: const Color(0xFF0D1B2A).withValues(alpha: 0.72),
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(
                    color: const Color(0xFFE0F4FF).withValues(alpha: 0.10),
                  ),
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        _TitleTag(),
                        const SizedBox(width: 12),
                        _ScoreBadge(
                          label: 'HIT',
                          count: state.hitCount,
                          color: const Color(0xFFFF4444),
                        ),
                        const SizedBox(width: 10),
                        _ScoreBadge(
                          label: 'MISS',
                          count: state.missCount,
                          color: const Color(0xFF6B8CAE),
                        ),
                        const Spacer(),
                        _StatusBadge(isComputing: isComputing),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Text(
                      state.logMessage,
                      style: TextStyle(
                        color: const Color(0xFFC9E8FF).withValues(alpha: 0.78),
                        fontSize: 11,
                        fontFamily: 'monospace',
                        letterSpacing: 0.2,
                        height: 1.4,
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}

class _TitleTag extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: const Color(0xFF1A3B5C).withValues(alpha: 0.6),
        borderRadius: BorderRadius.circular(5),
        border: Border.all(
          color: const Color(0xFF2A6B9C).withValues(alpha: 0.4),
        ),
      ),
      child: const Text(
        'ZONAR',
        style: TextStyle(
          color: Color(0xFF6BBFFF),
          fontSize: 9,
          fontWeight: FontWeight.w800,
          letterSpacing: 2.0,
        ),
      ),
    );
  }
}

class _ScoreBadge extends StatelessWidget {
  final String label;
  final int count;
  final Color color;

  const _ScoreBadge({
    required this.label,
    required this.count,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 7,
          height: 7,
          decoration: BoxDecoration(shape: BoxShape.circle, color: color),
        ),
        const SizedBox(width: 5),
        Text(
          '$label $count',
          style: TextStyle(
            color: color,
            fontSize: 11,
            fontWeight: FontWeight.w700,
            letterSpacing: 0.6,
          ),
        ),
      ],
    );
  }
}

class _StatusBadge extends StatefulWidget {
  final bool isComputing;
  const _StatusBadge({required this.isComputing});

  @override
  State<_StatusBadge> createState() => _StatusBadgeState();
}

class _StatusBadgeState extends State<_StatusBadge>
    with SingleTickerProviderStateMixin {
  late final AnimationController _pulse;

  @override
  void initState() {
    super.initState();
    _pulse = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 900),
    )..repeat(reverse: true);
  }

  @override
  void dispose() {
    _pulse.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (widget.isComputing) {
      return const Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          SizedBox(
            width: 11,
            height: 11,
            child: CircularProgressIndicator(
              strokeWidth: 1.5,
              color: Color(0xFF00FFD1),
            ),
          ),
          SizedBox(width: 7),
          Text(
            'ZKP',
            style: TextStyle(
              color: Color(0xFF00FFD1),
              fontSize: 10,
              fontWeight: FontWeight.w700,
              letterSpacing: 1.5,
            ),
          ),
        ],
      );
    }

    return AnimatedBuilder(
      animation: _pulse,
      builder: (_, child) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
        decoration: BoxDecoration(
          color: const Color(0xFF00FFD1)
              .withValues(alpha: 0.08 + _pulse.value * 0.06),
          borderRadius: BorderRadius.circular(5),
          border: Border.all(
            color: const Color(0xFF00FFD1)
                .withValues(alpha: 0.25 + _pulse.value * 0.15),
          ),
        ),
        child: const Text(
          'READY',
          style: TextStyle(
            color: Color(0xFF00FFD1),
            fontSize: 10,
            fontWeight: FontWeight.w700,
            letterSpacing: 1.5,
          ),
        ),
      ),
    );
  }
}
