param(
  [string]$FlutterProjectPath = "frontend/tour2tour_app",
  [string]$OutputPath = "frontend/tour2tour_app/build-web.tar.gz",
  [string]$ApiBaseUrl = "https://api.24tour2tour.ru",
  [string]$PremiumCheckoutUrl = ""
)

$ErrorActionPreference = "Stop"

function Assert-LastExitCode {
  param([string]$Step)
  if ($LASTEXITCODE -ne 0) {
    throw "[build-web-archive] $Step failed with exit code $LASTEXITCODE"
  }
}

Write-Host "[build-web-archive] Building Flutter web"
Push-Location $FlutterProjectPath
try {
  flutter pub get
  Assert-LastExitCode "flutter pub get"

  $resolvedPremiumCheckoutUrl = if (-not [string]::IsNullOrWhiteSpace($PremiumCheckoutUrl)) {
    $PremiumCheckoutUrl
  } else {
    $env:PREMIUM_CHECKOUT_URL
  }

  $flutterBuildArgs = @(
    "build",
    "web",
    "--release",
    "--dart-define=API_BASE_URL=$ApiBaseUrl"
  )

  if (-not [string]::IsNullOrWhiteSpace($resolvedPremiumCheckoutUrl)) {
    $flutterBuildArgs += "--dart-define=PREMIUM_CHECKOUT_URL=$resolvedPremiumCheckoutUrl"
  }

  flutter @flutterBuildArgs
  Assert-LastExitCode "flutter build web"
} finally {
  Pop-Location
}

$resolvedOutputPath = if ([System.IO.Path]::IsPathRooted($OutputPath)) {
  $OutputPath
} else {
  Join-Path (Get-Location) $OutputPath
}

$outputDirectory = Split-Path -Parent $resolvedOutputPath
if (-not [string]::IsNullOrWhiteSpace($outputDirectory) -and -not (Test-Path $outputDirectory)) {
  New-Item -ItemType Directory -Path $outputDirectory | Out-Null
}

if (Test-Path $resolvedOutputPath) {
  Remove-Item -LiteralPath $resolvedOutputPath -Force
}

Write-Host "[build-web-archive] Creating archive: $resolvedOutputPath"
tar -czf $resolvedOutputPath -C "$FlutterProjectPath/build/web" .
Assert-LastExitCode "Create web archive"

$archive = Get-Item -LiteralPath $resolvedOutputPath
Write-Host "[build-web-archive] Archive ready: $($archive.FullName) ($([math]::Round($archive.Length / 1MB, 2)) MB)"
