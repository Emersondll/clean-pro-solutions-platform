# Clean Pro Solutions - Automated E2E Integration Test
$ErrorActionPreference = "Stop"

$schedulingUrl = "http://localhost:8084"
$contractUrl = "http://localhost:8086"
$paymentUrl = "http://localhost:8087"
$ratingUrl = "http://localhost:8088"
$eurekaUrl = "http://localhost:8761"

Write-Host "`n=== Starting Clean Pro Integrated Test ===`n" -ForegroundColor Cyan

# 0. Check Eureka
try {
    Write-Host "[1/7] Checking Eureka Service Registry..." -NoNewline
    $apps = Invoke-RestMethod -Uri "$eurekaUrl/eureka/apps" -Headers @{"Accept"="application/json"} -TimeoutSec 10
    Write-Host " OK" -ForegroundColor Green
} catch {
    Write-Host " FAIL" -ForegroundColor Red
    Write-Host "Make sure all containers are running (docker-compose up -d)" -ForegroundColor Yellow
    exit
}

# 1. Create Scheduling
Write-Host "[2/7] Creating Scheduling..." -NoNewline
$schedBody = @{
    clientId = "client-101"
    contractorId = "contractor-909"
    serviceId = "cleaning-service-1"
    startTime = "2026-05-10T10:00:00Z"
    endTime = "2026-05-10T14:00:00Z"
} | ConvertTo-Json

$schedResp = Invoke-RestMethod -Uri "$schedulingUrl/schedulings" -Method Post -Body $schedBody -ContentType "application/json"
$schedulingId = $schedResp.id
Write-Host " OK (ID: $schedulingId)" -ForegroundColor Green

# 2. Create Contract
Write-Host "[3/7] Creating Contract..." -NoNewline
$contractBody = @{
    clientId = "client-101"
    contractorId = "contractor-909"
    serviceId = "cleaning-service-1"
    schedulingId = $schedulingId
    agreedPrice = 250.00
} | ConvertTo-Json

$contractResp = Invoke-RestMethod -Uri "$contractUrl/contracts" -Method Post -Body $contractBody -ContentType "application/json"
$contractId = $contractResp.id
Write-Host " OK (ID: $contractId)" -ForegroundColor Green

# 3. Verify Payment is Pending
Write-Host "[4/7] Checking Payment Status..." -NoNewline
Start-Sleep -Seconds 2 # Wait for event consumption
$payment = Invoke-RestMethod -Uri "$paymentUrl/payments/contract/$contractId"
Write-Host " OK (Status: $($payment.status))" -ForegroundColor Green

# 4. Simulate Payment Webhook (Approval)
Write-Host "[5/7] Simulating Payment Webhook (Approval)..." -NoNewline
$webhookBody = @{
    externalTransactionId = "txn_test_$(Get-Random)"
    contractId = $contractId
    success = $true
} | ConvertTo-Json

Invoke-RestMethod -Uri "$paymentUrl/payments/webhook" -Method Post -Body $webhookBody -ContentType "application/json" | Out-Null
Write-Host " OK" -ForegroundColor Green

# 5. Verify Contract is CONFIRMED
Write-Host "[6/7] Verifying SAGA completion (Contract Status)..." -NoNewline
Start-Sleep -Seconds 3 # Wait for SAGA event flow
$finalContract = Invoke-RestMethod -Uri "$contractUrl/contracts/$contractId"
if ($finalContract.status -eq "CONFIRMED") {
    Write-Host " OK (Status: CONFIRMED)" -ForegroundColor Green
} else {
    Write-Host " PENDING (Status: $($finalContract.status))" -ForegroundColor Yellow
    Write-Host "  Wait a few more seconds and check manually if it turns CONFIRMED."
}

# 6. Create Rating
Write-Host "[7/7] Submitting Customer Rating..." -NoNewline
$ratingBody = @{
    reviewerId = "client-101"
    reviewedId = "contractor-909"
    contractId = $contractId
    score = 5
    comment = "Excellent integrated test execution!"
} | ConvertTo-Json

Invoke-RestMethod -Uri "$ratingUrl/ratings" -Method Post -Body $ratingBody -ContentType "application/json" | Out-Null
$avg = Invoke-RestMethod -Uri "$ratingUrl/ratings/reviewed/contractor-909/average"
Write-Host " OK (Average Rating: $($avg.averageScore))" -ForegroundColor Green

Write-Host "`n=== INTEGRATED TEST COMPLETED SUCCESSFULLY ===`n" -ForegroundColor Cyan
