import 'package:rideshare/screens/root.dart';
import 'package:rideshare/screens/login/login.dart';
import 'package:rideshare/providers/user_state.dart';
import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:zego_uikit_prebuilt_call/zego_uikit_prebuilt_call.dart';
import 'cloud_functions/firebase_options.dart';
import 'package:provider/provider.dart';
import 'package:rideshare/providers/push_notificaions/local_notification_service.dart';
import 'package:flutter/services.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Load environment variables
  // await dotenv.load(fileName: ".env");
  try {
    await dotenv.load(fileName: '.env');
    print("LOADED SUCCESSFULLY");
  } catch (e) {
    print(e.toString());
  }

  // Set preferred orientation
  SystemChrome.setPreferredOrientations([DeviceOrientation.portraitUp]);

  // Initialize Firebase
  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );

  // Initialize ZEGOCLOUD SDK
  final int appID = int.parse(dotenv.env['ZEGO_APP_ID']!);
  final String appSign = dotenv.env['ZEGO_APP_SIGN']!;
  ZegoUIKit().init(
    appID: appID,
    appSign: appSign,
  );

  // Initialize user state
  UserState userState = UserState();
  await userState.loadData();

  // Set up local notifications
  await LocalNotificationService.setup();

  runApp(
    ChangeNotifierProvider(
      create: (_) => userState,
      child: MyApp(userState: userState),
    ),
  );
}

class MyApp extends StatefulWidget {
  final UserState userState;

  const MyApp({super.key, required this.userState});

  @override
  State<MyApp> createState() => _MyAppState();
}

class _MyAppState extends State<MyApp> {
  @override
  Widget build(BuildContext context) {
    final userState = Provider.of<UserState>(context);
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'rideshare',
      theme: ThemeData(
        primarySwatch: Colors.lightBlue,
      ),
      home: userState.currentUser == null
          ? LoginScreen(userState: widget.userState)
          : RootNavigationView(userState: widget.userState),
      routes: {
        "/login": (context) => LoginScreen(userState: widget.userState),
        "/dashboard": (context) =>
            RootNavigationView(userState: widget.userState),
      },
    );
  }
}
