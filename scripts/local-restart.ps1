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

function Wait-ForPostgres {
    param(
        [string]$Service,
        [string]$User,
        [string]$Database,
        [int]$Attempts = 30
    )

    for ($i = 1; $i -le $Attempts; $i++) {
        docker compose @composeArgs exec -T $Service pg_isready -U $User -d $Database *> $null
        if ($LASTEXITCODE -eq 0) {
            Write-Host "$Service is ready."
            return
        }
        Start-Sleep -Seconds 2
    }

    throw "$Service did not become ready in time"
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

function Seed-LocalAuthUser {
    param(
        [string]$Email,
        [string]$Password
    )

    $pythonScript = @'
from sqlalchemy import select
import os
from app.db.session import SessionLocal
from app.models.user import User
from app.core.security import hash_password

db = SessionLocal()
email = os.environ['SEED_EMAIL']
password_hash = hash_password(os.environ['SEED_PASSWORD'])

user = db.execute(select(User).where(User.email == email)).scalars().first()
if user:
    user.password_hash = password_hash
    user.totp_enabled = False
    user.is_2fa_enabled = False
    user.passkey_enabled = False
    user.totp_secret = None
else:
    db.add(
        User(
            email=email,
            phone=None,
            password_hash=password_hash,
            role='traveler',
            is_2fa_enabled=False,
            totp_enabled=False,
            passkey_enabled=False,
            totp_secret=None,
        )
    )

db.commit()
db.close()
print('OK: local test user is ready')
'@

    Write-Host "Seeding local auth user ($Email)..."
    docker compose @composeArgs exec -T -e "SEED_EMAIL=$Email" -e "SEED_PASSWORD=$Password" auth-service python -c $pythonScript
    Assert-LastExitCode "Seeding local auth user"
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

Write-Host "Waiting for databases..."
Wait-ForPostgres -Service "auth-db" -User "auth" -Database "auth"
Wait-ForPostgres -Service "trips-db" -User "trips" -Database "trips"

Write-Host "Running auth migrations..."
docker compose @composeArgs exec -T auth-service alembic upgrade head
Assert-LastExitCode "Running auth migrations"

Write-Host "Running trips migrations..."
docker compose @composeArgs exec -T trips-service alembic upgrade heads
Assert-LastExitCode "Running trips migrations"

Seed-LocalAuthUser -Email "local.test@tour2tour.dev" -Password "Test123!"

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
