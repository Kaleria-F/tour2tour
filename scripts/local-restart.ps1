param(
    [switch]$Clean,
    [switch]$RunWeb
)

$ErrorActionPreference = "Stop"

$root = Split-Path -Parent $PSScriptRoot
Set-Location $root

$composeArgs = @("-f", "infra/docker-compose.yml")

Write-Host "Stopping local stack..."
docker compose @composeArgs down

if ($Clean) {
    Write-Host "Removing local volumes..."
    docker compose @composeArgs down -v
}

Write-Host "Starting local stack..."
docker compose @composeArgs up --build -d

Write-Host "Running auth migrations..."
docker compose @composeArgs exec auth-service alembic upgrade head

Write-Host "Running trips migrations..."
docker compose @composeArgs exec trips-service alembic upgrade head

Write-Host "Checking gateway health..."
$health = curl.exe -s http://127.0.0.1:8888/health
Write-Host "Gateway health: $health"

if ($RunWeb) {
    $flutterDir = Join-Path $root "frontend\tour2tour_app"
    Write-Host "Starting Flutter Web in a new terminal..."
    Start-Process powershell -ArgumentList @(
        "-NoExit",
        "-ExecutionPolicy",
        "Bypass",
        "-Command",
        "Set-Location '$flutterDir'; flutter pub get; flutter run -d chrome"
    )
}

Write-Host "Done."
