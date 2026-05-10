param(
  [string]$ServerHost = "91.198.220.227",
  [string]$ServerUser = "root",
  [string]$Branch = "master",
  [string]$RepoPath = "/root/tour2tour",
  [string]$FlutterProjectPath = "frontend/tour2tour_app",
  [string]$WebRoot = "/var/www/tour2tour/web",
  [string]$KeyPath = "",
  [string]$PremiumCheckoutUrl = "",
  [string]$PremiumInn = "",
  [switch]$SkipFrontend
)

$ErrorActionPreference = "Stop"

function Invoke-Ssh {
  param([string]$Command)
  if ([string]::IsNullOrWhiteSpace($KeyPath)) {
    & ssh "$ServerUser@$ServerHost" $Command
  } else {
    & ssh -i $KeyPath "$ServerUser@$ServerHost" $Command
  }
}

function Invoke-Scp {
  param([string]$Source, [string]$Target)
  if ([string]::IsNullOrWhiteSpace($KeyPath)) {
    & scp -r $Source "$ServerUser@$ServerHost`:$Target"
  } else {
    & scp -i $KeyPath -r $Source "$ServerUser@$ServerHost`:$Target"
  }
}

Write-Host "[deploy] Server: $ServerUser@$ServerHost | Branch: $Branch"

if (-not $SkipFrontend) {
  Write-Host "[deploy] Building Flutter web"
  Push-Location $FlutterProjectPath
  try {
    flutter pub get
    $resolvedPremiumCheckoutUrl = if (-not [string]::IsNullOrWhiteSpace($PremiumCheckoutUrl)) {
      $PremiumCheckoutUrl
    } else {
      $env:PREMIUM_CHECKOUT_URL
    }
    $resolvedPremiumInn = if (-not [string]::IsNullOrWhiteSpace($PremiumInn)) {
      $PremiumInn
    } else {
      $env:PREMIUM_INN
    }
    $flutterBuildArgs = @(
      "build",
      "web",
      "--release",
      "--dart-define=API_BASE_URL=https://api.24tour2tour.ru"
    )
    if (-not [string]::IsNullOrWhiteSpace($resolvedPremiumCheckoutUrl)) {
      $flutterBuildArgs += "--dart-define=PREMIUM_CHECKOUT_URL=$resolvedPremiumCheckoutUrl"
    }
    if (-not [string]::IsNullOrWhiteSpace($resolvedPremiumInn)) {
      $flutterBuildArgs += "--dart-define=PREMIUM_INN=$resolvedPremiumInn"
    }
    flutter @flutterBuildArgs
  } finally {
    Pop-Location
  }

  Write-Host "[deploy] Uploading web build to $WebRoot"
  Invoke-Ssh "mkdir -p $WebRoot"
  Invoke-Scp "$FlutterProjectPath/build/web/." "$WebRoot/"
  Invoke-Ssh "chown -R www-data:www-data /var/www/tour2tour && chmod -R 755 /var/www/tour2tour"
}

Write-Host "[deploy] Running backend deploy on server"
Invoke-Ssh "cd $RepoPath && bash scripts/prod-deploy-remote.sh $Branch"

Write-Host "[deploy] Done"
