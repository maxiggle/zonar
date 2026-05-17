import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../../bloc/battle_map_bloc.dart';

class GameControlsOverlay extends StatelessWidget {
  const GameControlsOverlay({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<BattleMapBloc, BattleMapState>(
      builder: (context, state) {
        final shotsLeft = 100 - state.hitCount - state.missCount;
        return Padding(
          padding: const EdgeInsets.fromLTRB(12, 0, 12, 10),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(12),
            child: BackdropFilter(
              filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 10,
                ),
                decoration: BoxDecoration(
                  color: const Color(0xFF0D1B2A).withValues(alpha: 0.62),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: const Color(0xFFE0F4FF).withValues(alpha: 0.09),
                  ),
                ),
                child: Row(
                  children: [
                    const Icon(
                      Icons.radar_outlined,
                      color: Color(0xFF4A6E8A),
                      size: 14,
                    ),
                    const SizedBox(width: 8),
                    const Expanded(
                      child: Text(
                        'TAP A GRID COORDINATE TO DEPLOY STRIKE',
                        style: TextStyle(
                          color: Color(0xFF6B8CAE),
                          fontSize: 9,
                          letterSpacing: 1.6,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 3,
                      ),
                      decoration: BoxDecoration(
                        color: const Color(0xFF1A3B5C).withValues(alpha: 0.5),
                        borderRadius: BorderRadius.circular(5),
                      ),
                      child: Text(
                        '$shotsLeft SECTORS',
                        style: const TextStyle(
                          color: Color(0xFF4A6E8A),
                          fontSize: 9,
                          letterSpacing: 1.0,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
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
