param(
    [switch]$Clean,
    [switch]$RunWeb
)

$ErrorActionPreference = "Stop"

function Assert-LastExitCode {
    param([string]$StepName)
    if ($LASTEXITCODE -ne 0) {
        throw "$StepName failed with exit code $LASTEXITCODE"
    }
}

function Get-GatewayHealth {
    $healthUrls = @(
        "http://127.0.0.1:8888/health",
        "http://127.0.0.1:8000/health"
    )

    foreach ($url in $healthUrls) {
        $response = curl.exe -sS --max-time 8 $url
        if ($LASTEXITCODE -eq 0 -and $response) {
            return @{
                Url = $url
                Body = $response
            }
        }
    }

    return $null
}

$root = Split-Path -Parent $PSScriptRoot
Set-Location $root

$composeArgs = @("-f", "infra/docker-compose.yml")

Write-Host "Stopping local stack..."
docker compose @composeArgs down
Assert-LastExitCode "Stopping local stack"

if ($Clean) {
    Write-Host "Removing local volumes..."
    docker compose @composeArgs down -v
    Assert-LastExitCode "Removing local volumes"
}

Write-Host "Starting local stack..."
$coreServices = @(
    "auth-db",
    "trips-db",
    "rec-db",
    "places-db",
    "interactions-db",
    "payments-db",
    "redis",
    "minio",
    "auth-service",
    "trips-service",
    "recommendations-service",
    "places-service",
    "interactions-service",
    "payments-service",
    "documents-service",
    "gateway"
)
docker compose @composeArgs up --build -d --remove-orphans $coreServices
Assert-LastExitCode "Starting local stack"

Write-Host "Running auth migrations..."
docker compose @composeArgs exec auth-service alembic upgrade head
Assert-LastExitCode "Running auth migrations"

Write-Host "Running trips migrations..."
docker compose @composeArgs exec trips-service alembic upgrade heads
Assert-LastExitCode "Running trips migrations"

Write-Host "Checking gateway health..."
$healthResult = Get-GatewayHealth
if (-not $healthResult) {
    throw "Gateway health check failed on both 8888 and 8000"
}
Write-Host "Gateway health ($($healthResult.Url)): $($healthResult.Body)"

$apiBaseUrl = if ($healthResult.Url -like "*:8888/*") {
    "http://127.0.0.1:8888"
} else {
    "http://127.0.0.1:8000"
}

if ($RunWeb) {
    $flutterDir = Join-Path $root "frontend\tour2tour_app"
    Write-Host "Starting Flutter Web in a new terminal..."
    Start-Process powershell -ArgumentList @(
        "-NoExit",
        "-ExecutionPolicy",
        "Bypass",
        "-Command",
        "Set-Location '$flutterDir'; flutter pub get; flutter run -d chrome --dart-define=API_BASE_URL=$apiBaseUrl"
    )
    Assert-LastExitCode "Starting Flutter Web terminal"
}

Write-Host "Done."
