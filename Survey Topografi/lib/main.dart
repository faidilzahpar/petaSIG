import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'ui/theme/topo_theme.dart';
import 'ui/main_navigation.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();

  // Set orientasi vertikal (portrait) untuk alat ukur survei jalon
  SystemChrome.setPreferredOrientations([
    DeviceOrientation.portraitUp,
    DeviceOrientation.portraitDown,
  ]);

  // Set style system bar (status bar & nav bar) gelap
  SystemChrome.setSystemUIOverlayStyle(
    const SystemUiOverlayStyle(
      statusBarColor: Colors.transparent,
      statusBarIconBrightness: Brightness.light,
      systemNavigationBarColor: TopoTheme.surfaceDark,
      systemNavigationBarIconBrightness: Brightness.light,
    ),
  );

  runApp(const TopoSurveyMeshApp());
}

class TopoSurveyMeshApp extends StatelessWidget {
  const TopoSurveyMeshApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'TopoMesh Geodetic Surveyor',
      debugShowCheckedModeBanner: false,
      theme: TopoTheme.themeData,
      home: const MainNavigation(),
    );
  }
}

