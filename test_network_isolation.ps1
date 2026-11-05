[Console]::OutputEncoding = [System.Text.Encoding]::UTF8

Write-Host "=== Network Isolation Test ===" -ForegroundColor Cyan
Write-Host ""

function Test-TcpFromContainer {
    param($container, $target, $port)
    try {
        $result = docker exec $container python3 -c "import socket; s=socket.socket(); s.settimeout(2); s.connect(('$target', $port)); s.close(); print('OK')" 2>&1
        return ($result -eq "OK")
    } catch {
        return $false
    }
}

function Test-DnsFromContainer {
    param($container, $target)
    try {
        $result = docker exec $container sh -c "getent hosts $target" 2>&1
        return ($LASTEXITCODE -eq 0 -and $result -ne "")
    } catch {
        return $false
    }
}

Write-Host "1. booking-service -> postgres:5432 (Should be ALLOWED)..." -ForegroundColor Yellow
if (Test-TcpFromContainer "cinema_booking_app" "postgres" 5432) {
    Write-Host "   ALLOWED - OK" -ForegroundColor Green
} else {
    Write-Host "   DENIED - ERROR!" -ForegroundColor Red
}
Write-Host ""

Write-Host "2. booking-service -> redis:6379 (Should be ALLOWED)..." -ForegroundColor Yellow
if (Test-TcpFromContainer "cinema_booking_app" "redis" 6379) {
    Write-Host "   ALLOWED - OK" -ForegroundColor Green
} else {
    Write-Host "   DENIED - ERROR!" -ForegroundColor Red
}
Write-Host ""

Write-Host "3. booking-service -> rabbitmq:5672 (Should be ALLOWED)..." -ForegroundColor Yellow
if (Test-TcpFromContainer "cinema_booking_app" "rabbitmq" 5672) {
    Write-Host "   ALLOWED - OK" -ForegroundColor Green
} else {
    Write-Host "   DENIED - ERROR!" -ForegroundColor Red
}
Write-Host ""

Write-Host "4. postgres -> booking-service (Should be PROHIBITED)..." -ForegroundColor Yellow
if (-not (Test-DnsFromContainer "cinema_postgres" "booking-service")) {
    Write-Host "   PROHIBITED - DNS resolution failed (isolation works)" -ForegroundColor Green
} else {
    Write-Host "   ALLOWED - SECURITY ERROR!" -ForegroundColor Red
}
Write-Host ""

Write-Host "5. redis -> booking-service (Should be PROHIBITED)..." -ForegroundColor Yellow
if (-not (Test-DnsFromContainer "cinema_redis" "booking-service")) {
    Write-Host "   PROHIBITED - DNS resolution failed (isolation works)" -ForegroundColor Green
} else {
    Write-Host "   ALLOWED - SECURITY ERROR!" -ForegroundColor Red
}
Write-Host ""

Write-Host "6. rabbitmq -> booking-service (Should be PROHIBITED)..." -ForegroundColor Yellow
if (-not (Test-DnsFromContainer "cinema_rabbitmq" "booking-service")) {
    Write-Host "   PROHIBITED - DNS resolution failed (isolation works)" -ForegroundColor Green
} else {
    Write-Host "   ALLOWED - SECURITY ERROR!" -ForegroundColor Red
}
Write-Host ""

Write-Host "=== Test Complete ===" -ForegroundColor Cyan
