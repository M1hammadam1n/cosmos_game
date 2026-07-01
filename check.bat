@echo off
setlocal EnableDelayedExpansion

echo [1/8] Cleaning project...
call flutter clean
if ERRORLEVEL 1 (
  echo Clean failed - folder may be locked. Continuing...
)

echo [2/8] Getting dependencies...
call flutter pub get
if ERRORLEVEL 1 (
  echo Failed to get dependencies. Check your connection or run 'flutter pub get' manually.
  exit /b %ERRORLEVEL%
)

echo [3/8] Formatting code...
set "FORMAT_TARGETS="
for %%d in (lib test android\app\src\main\kotlin android\app\src\main\java) do (
  if exist "%%d" (
    set "FORMAT_TARGETS=!FORMAT_TARGETS! "%%d""
  )
)
if defined FORMAT_TARGETS (
  call set "FORMAT_CMD=dart format%%FORMAT_TARGETS%%"
  call %%FORMAT_CMD%%
) else (
  echo No Dart formatting targets found, skipping.
)

echo [4/8] Analyzing code...
call flutter analyze

echo [5/8] Running tests...
if exist test (
  call flutter test
) else (
  echo No test directory found, skipping tests.
)

echo [6/8] Checking ProGuard/R8 release protection...
set "ANDROID_APP_GRADLE=android\app\build.gradle.kts"
set "PROGUARD_RULES=android\app\proguard-rules.pro"

if not exist "%ANDROID_APP_GRADLE%" (
  echo Android app Gradle config not found: %ANDROID_APP_GRADLE%
  exit /b 1
)

if not exist "%PROGUARD_RULES%" (
  echo ProGuard rules file not found: %PROGUARD_RULES%
  exit /b 1
)

findstr /C:"isMinifyEnabled = true" "%ANDROID_APP_GRADLE%" >nul
if ERRORLEVEL 1 (
  echo ProGuard/R8 is not enabled for release. Expected: isMinifyEnabled = true
  exit /b 1
)

findstr /C:"isShrinkResources = true" "%ANDROID_APP_GRADLE%" >nul
if ERRORLEVEL 1 (
  echo Resource shrinking is not enabled for release. Expected: isShrinkResources = true
  exit /b 1
)

findstr /C:"proguardFiles(" "%ANDROID_APP_GRADLE%" >nul
if ERRORLEVEL 1 (
  echo ProGuard files are not configured for release.
  exit /b 1
)

findstr /C:"proguard-rules.pro" "%ANDROID_APP_GRADLE%" >nul
if ERRORLEVEL 1 (
  echo Custom ProGuard rules are not included in release build.
  exit /b 1
)

echo [7/8] Building protected APK...
if not exist build\debug-info (
  mkdir build\debug-info
)
call flutter build apk --release --obfuscate --split-debug-info=build/debug-info
if ERRORLEVEL 1 (
  echo APK build failed. Fix issues above and retry.
  exit /b %ERRORLEVEL%
)

echo [8/8] Done!
endlocal
