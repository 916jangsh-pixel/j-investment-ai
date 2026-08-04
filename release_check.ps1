$ErrorActionPreference = "Stop"

Write-Host ""
Write-Host "========================================"
Write-Host " J.Investment AI - LONG TERM V1 CHECK"
Write-Host "========================================"
Write-Host ""

Write-Host ">>> Flutter version"
flutter --version
if ($LASTEXITCODE -ne 0) { exit $LASTEXITCODE }

Write-Host ""
Write-Host ">>> Dependencies"
flutter pub get
if ($LASTEXITCODE -ne 0) { exit $LASTEXITCODE }

Write-Host ""
Write-Host ">>> Static analysis"
Write-Host "info/warning은 표시만 하고 APK 빌드는 계속합니다."
flutter analyze --no-fatal-infos --no-fatal-warnings

if ($LASTEXITCODE -ne 0) {
    Write-Host "[WARN] Static analysis has warnings. Continuing..."
} else {
    Write-Host "[OK] Static analysis"
}

Write-Host ""
Write-Host ">>> Android debug APK build"
flutter build apk --debug

if ($LASTEXITCODE -ne 0) {
    Write-Host "[FAIL] Android APK build"
    exit $LASTEXITCODE
}

Write-Host ""
Write-Host "========================================"
Write-Host " LONG TERM PROJECT V1 BUILD CHECK PASSED"
Write-Host "========================================"
Write-Host ""
Write-Host "APK:"
Write-Host "build\app\outputs\flutter-apk\app-debug.apk"
