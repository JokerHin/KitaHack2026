@echo off
REM Run Flutter app in current directory's flutter project. Open emulator first.
cd mobile\flutter
echo Running `flutter pub get`...
flutter pub get
echo Launching app (use -d to select device if needed)...
flutter run
