$githubUser = "emersondll"
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

Write-Host "Starting clone of all microservices for $githubUser..." -ForegroundColor Cyan

foreach ($svc in $services) {
    if (-not (Test-Path $svc)) {
        Write-Host "`n>>> Cloning $svc..." -ForegroundColor Cyan
        git clone "https://github.com/$githubUser/$svc.git"
    } else {
        Write-Host "`n>>> $svc already exists. Skipping..." -ForegroundColor Yellow
    }
}

Write-Host "`nEnvironment ready! You can now run 'docker-compose up -d --build'." -ForegroundColor Green
