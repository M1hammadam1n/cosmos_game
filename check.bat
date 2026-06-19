@echo off
setlocal EnableDelayedExpansion

echo [1/7] Cleaning project...
call flutter clean
if ERRORLEVEL 1 (
  echo Clean failed - folder may be locked. Continuing...
)

echo [2/7] Getting dependencies...
call flutter pub get
if ERRORLEVEL 1 (
  echo Failed to get dependencies. Check your connection or run 'flutter pub get' manually.
  exit /b %ERRORLEVEL%
)

echo [3/7] Formatting code...
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

echo [4/7] Analyzing code...
call flutter analyze

echo [5/7] Running tests...
if exist test (
  call flutter test
) else (
  echo No test directory found, skipping tests.
)

echo [6/7] Building APK...
call flutter build apk --release
if ERRORLEVEL 1 (
  echo APK build failed. Fix issues above and retry.
  exit /b %ERRORLEVEL%
)

echo [7/7] Done!
endlocal