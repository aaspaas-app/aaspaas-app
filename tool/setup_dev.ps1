# One-time setup for Windows. Run from the app folder in the VS Code terminal:
#   powershell -ExecutionPolicy Bypass -File tool\setup_dev.ps1
$ErrorActionPreference = 'Stop'

if (-not (Get-Command flutter -ErrorAction SilentlyContinue)) {
    Write-Host 'Flutter was not found. Install Flutter 3.47.8 and add its bin folder to PATH first (see README).' -ForegroundColor Red
    exit 1
}

if (Test-Path 'android') {
    Write-Host 'The android folder already exists, skipping the create step.'
} else {
    flutter create --org app.aaspaas --project-name aaspaas_app --platforms=android --no-pub _shell
    Move-Item -Path '_shell\android' -Destination 'android'
    Remove-Item -Path '_shell' -Recurse -Force
}

dart tool/prepare_android.dart
flutter pub get
Write-Host ''
Write-Host 'Done. Pick a device at the bottom right of VS Code, then press F5.' -ForegroundColor Green
