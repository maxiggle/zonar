import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'features/battle_map/data/repositories/game_repository_impl.dart';
import 'features/battle_map/domain/services/midnight_service.dart';
import 'features/battle_map/presentation/bloc/battle_map_bloc.dart';
import 'features/battle_map/presentation/views/battle_map_screen.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  SystemChrome.setPreferredOrientations([
    DeviceOrientation.portraitUp,
    DeviceOrientation.portraitDown,
  ]);
  SystemChrome.setSystemUIOverlayStyle(
    const SystemUiOverlayStyle(
      statusBarColor: Colors.transparent,
      statusBarIconBrightness: Brightness.light,
    ),
  );
  runApp(const ZonarApp());
}

class ZonarApp extends StatefulWidget {
  const ZonarApp({super.key});

  @override
  State<ZonarApp> createState() => _ZonarAppState();
}

class _ZonarAppState extends State<ZonarApp> {
  late final MidnightService _midnightService;
  late final GameRepositoryImpl _repository;

  @override
  void initState() {
    super.initState();
    _midnightService = MidnightService();
    _midnightService.initializeEngine();
    _repository = GameRepositoryImpl(_midnightService);
  }

  @override
  void dispose() {
    _repository.dispose();
    _midnightService.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      // BlocProvider closes the bloc automatically on dispose
      create: (_) => BattleMapBloc(_repository),
      child: MaterialApp(
        title: 'Zonar',
        debugShowCheckedModeBanner: false,
        theme: ThemeData(
          colorScheme: const ColorScheme.dark(
            surface: Color(0xFF0D1B2A),
            primary: Color(0xFF00FFD1),
          ),
          scaffoldBackgroundColor: const Color(0xFF0D1B2A),
        ),
        home: const BattleMapScreen(),
      ),
    );
  }
}
