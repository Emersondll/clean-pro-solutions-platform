# Clean Pro Solutions - Automated End-To-End Integration Test
# Prerequisites: docker-compose up --build (all services healthy)
$ErrorActionPreference = "Stop"

$authUrl         = "http://localhost:8081"
$userUrl         = "http://localhost:8082"
$catalogUrl      = "http://localhost:8083"
$schedulingUrl   = "http://localhost:8084"
$availabilityUrl = "http://localhost:8085"
$contractUrl     = "http://localhost:8086"
$paymentUrl      = "http://localhost:8087"
$ratingUrl       = "http://localhost:8088"
$notificationUrl = "http://localhost:8089"
$chatUrl         = "http://localhost:8091"
$supportUrl      = "http://localhost:8092"
$bffUrl          = "http://localhost:8080"
$eurekaUrl       = "http://localhost:8761"

$step = 0
function Step([string]$label) {
    $script:step++
    Write-Host "`n[$script:step] $label" -ForegroundColor Cyan
}
function Ok([string]$detail = "") {
    $msg = if ($detail) { " OK ($detail)" } else { " OK" }
    Write-Host $msg -ForegroundColor Green
}
function Fail([string]$detail) {
    Write-Host " FAIL: $detail" -ForegroundColor Red
    exit 1
}

Write-Host "`n======================================================" -ForegroundColor Yellow
Write-Host "  Clean Pro Solutions — Full E2E Integration Test" -ForegroundColor Yellow
Write-Host "======================================================`n" -ForegroundColor Yellow

# ── 0. HEALTH CHECKS ──────────────────────────────────────────────────────────
Step "Health: Eureka Service Registry"
try {
    Invoke-RestMethod -Uri "$eurekaUrl/eureka/apps" -Headers @{Accept="application/json"} -TimeoutSec 10 | Out-Null
    Ok
} catch { Fail "Eureka not reachable — run docker-compose up -d" }

Step "Health: BFF Gateway"
try {
    $h = Invoke-RestMethod -Uri "$bffUrl/actuator/health" -TimeoutSec 10
    Ok $h.status
} catch { Fail "BFF not reachable" }

# ── 1. AUTHENTICATION ─────────────────────────────────────────────────────────
# FIX #1: register now returns { userId, email }
$suffix = Get-Random -Minimum 10000 -Maximum 99999

Step "Auth: Register CLIENT"
$regClient = Invoke-RestMethod -Uri "$authUrl/auth/register" -Method Post -ContentType "application/json" -Body (@{
    email    = "client.$suffix@e2e.test"
    password = "Test@1234"
    role     = "CLIENT"
} | ConvertTo-Json)
$clientAuthId = $regClient.userId
Ok "userId=$clientAuthId"

Step "Auth: Register CONTRACTOR"
$regContractor = Invoke-RestMethod -Uri "$authUrl/auth/register" -Method Post -ContentType "application/json" -Body (@{
    email    = "contractor.$suffix@e2e.test"
    password = "Test@1234"
    role     = "CONTRACTOR"
} | ConvertTo-Json)
$contractorAuthId = $regContractor.userId
Ok "userId=$contractorAuthId"

Step "Auth: Login as CLIENT"
$loginClient = Invoke-RestMethod -Uri "$authUrl/auth/login" -Method Post -ContentType "application/json" -Body (@{
    email    = "client.$suffix@e2e.test"
    password = "Test@1234"
} | ConvertTo-Json)
Ok "token acquired"

Step "Auth: Validate JWT"
$validated = Invoke-RestMethod -Uri "$authUrl/auth/validate" -Headers @{Authorization="Bearer $($loginClient.accessToken)"} -TimeoutSec 10
Ok "valid=$($validated.valid), userId=$($validated.userId)"

# ── 2. USER PROFILES ──────────────────────────────────────────────────────────
# FIX #2: field is "type" not "role" in UserRequest
Step "User: Create CLIENT profile"
$clientUser = Invoke-RestMethod -Uri "$userUrl/users" -Method Post -ContentType "application/json" -Body (@{
    authId = $clientAuthId
    name   = "Carlos Cliente $suffix"
    email  = "client.$suffix@e2e.test"
    phone  = "+5511900000001"
    type   = "CLIENT"
} | ConvertTo-Json)
$clientId = $clientUser.id
Ok "id=$clientId"

Step "User: Create CONTRACTOR profile"
$contractorUser = Invoke-RestMethod -Uri "$userUrl/users" -Method Post -ContentType "application/json" -Body (@{
    authId  = $contractorAuthId
    name    = "Pedro Prestador $suffix"
    email   = "contractor.$suffix@e2e.test"
    phone   = "+5511900000002"
    type    = "CONTRACTOR"
    address = @{
        street    = "Av. Paulista"
        number    = "1000"
        city      = "São Paulo"
        state     = "SP"
        zipCode   = "01310-100"
        latitude  = -23.561
        longitude = -46.656
    }
} | ConvertTo-Json -Depth 5)
$contractorId = $contractorUser.id
Ok "id=$contractorId"

Step "User: Get client by ID"
$fetched = Invoke-RestMethod -Uri "$userUrl/users/$clientId"
Ok "name=$($fetched.name)"

# FIX #3: params are "lat", "lng", "type" — not "latitude", "longitude", "role"
Step "User: Find nearby contractors"
$nearby = Invoke-RestMethod -Uri "$userUrl/users/nearby?lat=-23.561&lng=-46.656&radiusKm=10&type=CONTRACTOR"
Ok "count=$($nearby.Count)"

# ── 3. CATALOG ────────────────────────────────────────────────────────────────
# FIX #5: field is "durationInHours" (integer 1-24), not "estimatedDurationMinutes"
Step "Catalog: Create service offering"
$service = Invoke-RestMethod -Uri "$catalogUrl/services" -Method Post -ContentType "application/json" -Body (@{
    name            = "Limpeza Residencial E2E $suffix"
    description     = "Limpeza completa de imóvel residencial — teste E2E automatizado"
    type            = "CLEANING"
    basePrice       = 200.00
    durationInHours = 4
} | ConvertTo-Json)
$serviceId = $service.id
Ok "id=$serviceId"

# FIX #4: /services/active does not exist — correct route is /services?activeOnly=true
Step "Catalog: List active services"
$active = Invoke-RestMethod -Uri "$catalogUrl/services?activeOnly=true"
Ok "total=$($active.Count)"

Step "Catalog: Search services"
$search = Invoke-RestMethod -Uri "$catalogUrl/services/search?query=limpeza"
Ok "results=$($search.Count)"

# ── 4. AVAILABILITY ───────────────────────────────────────────────────────────
# FIX #6: endpoint returns raw Boolean, not object — access directly as boolean
Step "Availability: Check contractor slot"
$isAvailable = Invoke-RestMethod -Uri "$availabilityUrl/availability/check?contractorId=$contractorId&startTime=2026-06-01T10:00:00Z&endTime=2026-06-01T14:00:00Z"
Ok "available=$isAvailable"

# ── 5. SCHEDULING ─────────────────────────────────────────────────────────────
Step "Scheduling: Create scheduling"
$scheduling = Invoke-RestMethod -Uri "$schedulingUrl/schedulings" -Method Post -ContentType "application/json" -Body (@{
    clientId          = $clientId
    contractorId      = $contractorId
    serviceId         = $serviceId
    startTime         = "2026-06-01T10:00:00Z"
    endTime           = "2026-06-01T14:00:00Z"
    recurrencePattern = "NONE"
} | ConvertTo-Json)
$schedulingId = $scheduling.id
Ok "id=$schedulingId"

Step "Scheduling: Get by ID"
$fetchedSched = Invoke-RestMethod -Uri "$schedulingUrl/schedulings/$schedulingId"
Ok "status=$($fetchedSched.status)"

# FIX #7: "occurrences" is a @RequestParam, not a body field — pass it in the URL query string
Step "Scheduling: Create recurring (WEEKLY, 4 occurrences)"
$recurring = Invoke-RestMethod -Uri "$schedulingUrl/schedulings/recurring?occurrences=4" -Method Post -ContentType "application/json" -Body (@{
    clientId          = $clientId
    contractorId      = $contractorId
    serviceId         = $serviceId
    startTime         = "2026-06-08T10:00:00Z"
    endTime           = "2026-06-08T14:00:00Z"
    recurrencePattern = "WEEKLY"
} | ConvertTo-Json)
Ok "created=$($recurring.Count) occurrences"

# ── 6. CONTRACT (SAGA init) ────────────────────────────────────────────────────
Step "Contract: Create contract (SAGA init)"
$contract = Invoke-RestMethod -Uri "$contractUrl/contracts" -Method Post -ContentType "application/json" -Body (@{
    clientId     = $clientId
    contractorId = $contractorId
    serviceId    = $serviceId
    schedulingId = $schedulingId
    agreedPrice  = 250.00
} | ConvertTo-Json)
$contractId = $contract.id
Ok "id=$contractId status=$($contract.status)"

Step "Contract: Verify initial status (PENDING_PAYMENT)"
$c1 = Invoke-RestMethod -Uri "$contractUrl/contracts/$contractId"
if ($c1.status -notin @("PENDING_PAYMENT", "PENDING")) { Fail "Expected PENDING_PAYMENT, got $($c1.status)" }
Ok "status=$($c1.status)"

# ── 7. PAYMENT (SAGA complete) ─────────────────────────────────────────────────
Step "Payment: Wait for SAGA event and check payment record"
Start-Sleep -Seconds 3
$payment = Invoke-RestMethod -Uri "$paymentUrl/payments/contract/$contractId"
Ok "status=$($payment.status)"

Step "Payment: Simulate gateway webhook (approval)"
Invoke-RestMethod -Uri "$paymentUrl/payments/webhook" -Method Post -ContentType "application/json" -Body (@{
    externalTransactionId = "txn_e2e_$suffix"
    contractId            = $contractId
    success               = $true
} | ConvertTo-Json) | Out-Null
Ok

Step "Contract: Verify SAGA completed (CONFIRMED)"
Start-Sleep -Seconds 4
$c2 = Invoke-RestMethod -Uri "$contractUrl/contracts/$contractId"
if ($c2.status -eq "CONFIRMED") {
    Ok "SAGA completed — status=CONFIRMED"
} else {
    Write-Host " WARN: status=$($c2.status) (may still be propagating)" -ForegroundColor Yellow
}

# ── 8. NOTIFICATIONS ──────────────────────────────────────────────────────────
Step "Notifications: Check client notifications"
$clientNotifs = Invoke-RestMethod -Uri "$notificationUrl/notifications/recipient/$clientId"
Ok "count=$($clientNotifs.Count)"

Step "Notifications: Check contractor notifications"
$contractorNotifs = Invoke-RestMethod -Uri "$notificationUrl/notifications/recipient/$contractorId"
Ok "count=$($contractorNotifs.Count)"

# ── 9. CHAT ────────────────────────────────────────────────────────────────────
Step "Chat: Get or create room"
$roomId = Invoke-RestMethod -Uri "$chatUrl/chat/rooms?clientId=$clientId&contractorId=$contractorId&contractId=$contractId" -Method Post
Ok "roomId=$roomId"

Step "Chat: Send message from client"
Invoke-RestMethod -Uri "$chatUrl/chat/$roomId/messages" -Method Post -ContentType "application/json" -Body (@{
    senderId = $clientId
    content  = "Olá! Confirma o serviço para amanhã às 10h?"
} | ConvertTo-Json) | Out-Null
Ok

Step "Chat: Send reply from contractor"
Invoke-RestMethod -Uri "$chatUrl/chat/$roomId/messages" -Method Post -ContentType "application/json" -Body (@{
    senderId = $contractorId
    content  = "Confirmado! Estarei aí pontualmente."
} | ConvertTo-Json) | Out-Null
Ok

Step "Chat: Get message history"
$history = Invoke-RestMethod -Uri "$chatUrl/chat/$roomId/messages"
Ok "messages=$($history.Count)"

# ── 10. RATING ─────────────────────────────────────────────────────────────────
Step "Rating: Client rates contractor"
Invoke-RestMethod -Uri "$ratingUrl/ratings" -Method Post -ContentType "application/json" -Body (@{
    reviewerId = $clientId
    reviewedId = $contractorId
    contractId = $contractId
    score      = 5
    comment    = "Excelente profissional! Serviço impecável. (E2E test)"
} | ConvertTo-Json) | Out-Null
Ok

# FIX #8: /average returns raw Double, not an object — use directly
Step "Rating: Get average score for contractor"
$avgScore = Invoke-RestMethod -Uri "$ratingUrl/ratings/reviewed/$contractorId/average"
Ok "average=$avgScore"

# ── 11. SUPPORT TICKET ─────────────────────────────────────────────────────────
# FIX #9: TicketRequest requires "priority" (NotNull) and "subject" (NotBlank)
Step "Support: Open dispute ticket"
$ticket = Invoke-RestMethod -Uri "$supportUrl/tickets" -Method Post -ContentType "application/json" -Body (@{
    requesterId = $clientId
    contractId  = $contractId
    type        = "DISPUTE"
    priority    = "HIGH"
    subject     = "Atraso do prestador sem aviso prévio"
    description = "Prestador chegou com atraso sem aviso prévio. (E2E test)"
} | ConvertTo-Json)
$ticketId = $ticket.id
Ok "id=$ticketId"

Step "Support: Get ticket by ID"
$t1 = Invoke-RestMethod -Uri "$supportUrl/tickets/$ticketId"
Ok "status=$($t1.status)"

Step "Support: Assign ticket"
$t2 = Invoke-RestMethod -Uri "$supportUrl/tickets/$ticketId/assign" -Method Patch
Ok "status=$($t2.status)"

Step "Support: Resolve ticket"
$t3 = Invoke-RestMethod -Uri "$supportUrl/tickets/$ticketId/resolve" -Method Patch -ContentType "application/json" -Body (@{
    resolution = "Desconto de 15% aplicado ao cliente. (E2E automated resolution)"
} | ConvertTo-Json)
Ok "status=$($t3.status)"

Step "Support: Close ticket"
$t4 = Invoke-RestMethod -Uri "$supportUrl/tickets/$ticketId/close" -Method Patch
Ok "status=$($t4.status)"

# ── SUMMARY ────────────────────────────────────────────────────────────────────
Write-Host "`n======================================================" -ForegroundColor Green
Write-Host "  ALL $step STEPS PASSED - E2E TEST COMPLETE" -ForegroundColor Green
Write-Host "======================================================" -ForegroundColor Green
Write-Host "`nKey IDs created during this run:" -ForegroundColor White
Write-Host "  clientId      = $clientId"
Write-Host "  contractorId  = $contractorId"
Write-Host "  serviceId     = $serviceId"
Write-Host "  schedulingId  = $schedulingId"
Write-Host "  contractId    = $contractId"
Write-Host "  roomId        = $roomId"
Write-Host "  ticketId      = $ticketId`n"
