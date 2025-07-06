import 'package:fluent_ui/fluent_ui.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:jowid/pages/init/splash_screen.dart';
import 'package:provider/provider.dart';
import 'package:jowid/provider/functions.dart'; // Your DatabaseHelper

void main() async {
  // Ensure Flutter binding is initialized
  WidgetsFlutterBinding.ensureInitialized();

  // Initialize the database
  await DatabaseHelper.initialize();

  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return ScreenUtilInit(
      designSize: const Size(375, 812), // Design size (iPhone X/11/12 size)
      minTextAdapt: true,
      splitScreenMode: true,
      builder: (context, child) {
        return ChangeNotifierProvider(
          create: (context) => DatabaseHelper(),
          child: FluentApp(
            title: 'JOWID Enterprise',
            debugShowCheckedModeBanner: false,
            theme: FluentThemeData(
              fontFamily: 'Lora',
              accentColor: Colors.blue,
              scaffoldBackgroundColor: Colors.grey[20],
              brightness: Brightness.light,
              visualDensity: VisualDensity.adaptivePlatformDensity,
              navigationPaneTheme: NavigationPaneThemeData(
                backgroundColor: const Color(0xFF1E3A8A),
                selectedIconColor: ButtonState.all(Colors.white),
                selectedTextStyle: ButtonState.all(
                  const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
                ),
                unselectedIconColor: ButtonState.all(const Color(0xFFB3C5E8)),
                unselectedTextStyle: ButtonState.all(
                  const TextStyle(color: Color(0xFFB3C5E8)),
                ),
              ),
              buttonTheme: ButtonThemeData(
                filledButtonStyle: ButtonStyle(
                  backgroundColor: ButtonState.resolveWith((states) {
                    if (states.isDisabled) return Colors.grey[40];
                    if (states.isPressed) return const Color(0xFF1E40AF);
                    if (states.isHovered) return const Color(0xFF1E40AF);
                    return const Color(0xFF1E3A8A);
                  }),
                  foregroundColor: ButtonState.resolveWith((states) {
                    return Colors.white;
                  }),
                  shape: ButtonState.all(
                    RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
                ),
                defaultButtonStyle: ButtonStyle(
                  backgroundColor: ButtonState.resolveWith((states) {
                    if (states.isDisabled) return Colors.grey[40];
                    if (states.isPressed) return Colors.grey[30];
                    if (states.isHovered) return Colors.grey[20];
                    return Colors.transparent;
                  }),
                  foregroundColor: ButtonState.resolveWith((states) {
                    if (states.isDisabled) return Colors.grey[80];
                    return const Color(0xFF1E3A8A);
                  }),
                  shape: ButtonState.all(
                    RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                      side: const BorderSide(color: Color(0xFF1E3A8A)),
                    ),
                  ),
                ),
              ),
              // Typography styling
              typography: Typography.fromBrightness(
                brightness: Brightness.light,
                color: Colors.black,
              ),
              // Card styling will be handled by individual Card widgets
              // Dialog styling
              dialogTheme: const ContentDialogThemeData(
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.all(Radius.circular(12)),
                ),
              ),
              // Tooltip styling
              tooltipTheme: const TooltipThemeData(
                decoration: BoxDecoration(
                  color: Color(0xFF1E3A8A),
                  borderRadius: BorderRadius.all(Radius.circular(6)),
                ),
              ),
              // Divider styling
              dividerTheme: const DividerThemeData(
                thickness: 1,
              ),
              iconTheme: const IconThemeData(
                size: 16,
                color: Color(0xFF1E3A8A),
              ),
            ),
            darkTheme: FluentThemeData(
              fontFamily: 'Lora',
              accentColor: Colors.blue,
              scaffoldBackgroundColor: Colors.grey[190],
              brightness: Brightness.dark,
              visualDensity: VisualDensity.adaptivePlatformDensity,
              navigationPaneTheme: NavigationPaneThemeData(
                backgroundColor: Colors.grey[220],
                selectedIconColor: ButtonState.all(Colors.blue),
                selectedTextStyle: ButtonState.all(
                  TextStyle(color: Colors.blue, fontWeight: FontWeight.bold),
                ),
                unselectedIconColor: ButtonState.all(const Color(0xFFB3B3B3)),
                unselectedTextStyle: ButtonState.all(
                  const TextStyle(color: Color(0xFFB3B3B3)),
                ),
              ),
              buttonTheme: ButtonThemeData(
                filledButtonStyle: ButtonStyle(
                  backgroundColor: ButtonState.resolveWith((states) {
                    if (states.isDisabled) return Colors.grey[160];
                    if (states.isPressed) return Colors.blue.dark;
                    if (states.isHovered) return Colors.blue.darker;
                    return Colors.blue;
                  }),
                  foregroundColor: ButtonState.all(Colors.white),
                  shape: ButtonState.all(
                    RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
                ),
              ),
              // Card styling for dark theme will be handled by individual widgets
            ),
            home: const SplashScreen(),
            // Navigation routes for FluentApp
            routes: {
              '/splash': (context) => const SplashScreen(),
              // Add other routes as needed
              // '/home': (context) => const HomePage(),
            },
            // Add locale and other configurations as needed
            locale: const Locale('en', 'US'),
            supportedLocales: const [
              Locale('en', 'US'),
              // Add other locales if needed
            ],
          ),
        );
      },
    );
  }
}