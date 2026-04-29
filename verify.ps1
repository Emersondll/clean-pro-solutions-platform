$services = @(
    "clean-pro-solutions-auth-service",
    "clean-pro-solutions-availability-service",
    "clean-pro-solutions-bff",
    "clean-pro-solutions-catalog",
    "clean-pro-solutions-contract-service",
    "clean-pro-solutions-notification-service",
    "clean-pro-solutions-payment-service",
    "clean-pro-solutions-rating-service",
    "clean-pro-solutions-scheduling-service",
    "clean-pro-solutions-service-registry",
    "clean-pro-solutions-user-service"
)

Write-Host "Starting test and coverage verification across all microservices (Threshold: 80%)..." -ForegroundColor Cyan

$failedServices = @()

foreach ($svc in $services) {
    Write-Host "`n==================================================" -ForegroundColor Blue
    Write-Host "Running tests for $svc..." -ForegroundColor Blue
    Write-Host "==================================================" -ForegroundColor Blue
    
    Push-Location $svc
    # Use call to execute maven command to ensure we get proper exit code in Windows
    cmd /c "mvn verify"
    $exitCode = $LASTEXITCODE
    Pop-Location
    
    if ($exitCode -ne 0) {
        Write-Host "X Tests failed in $svc" -ForegroundColor Red
        $failedServices += $svc
    } else {
        Write-Host "V Tests passed in $svc" -ForegroundColor Green
    }
}

Write-Host "`n==================================================" -ForegroundColor Cyan
if ($failedServices.Count -gt 0) {
    Write-Host "VERIFICATION FAILED! The following services have failing tests:" -ForegroundColor Red
    foreach ($failed in $failedServices) {
        Write-Host " - $failed" -ForegroundColor Red
    }
} else {
    Write-Host "ALL TESTS PASSED SUCCESSFULLY! The sanitization did not break the builds." -ForegroundColor Green
}
Write-Host "==================================================" -ForegroundColor Cyan
