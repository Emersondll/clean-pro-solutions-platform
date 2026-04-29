$githubUser = "emersondll"
$repoName = "clean-pro-solutions-platform"

Write-Host "Starting push to $repoName..." -ForegroundColor Cyan

# 1. Initialize Git if needed
if (-not (Test-Path ".git")) {
    git init
    git branch -M main
}

# 2. Add files
git add .gitignore
git add README.md
git add docker-compose.yml
git add test-integrated.ps1
git add verify.ps1
git add clean-pro-e2e-test.http
git add SYSTEM_ARCHITECTURE_AND_AI_SPEC.md

# 3. Commit
git commit -m "Initial commit: Platform Orchestrator with Docker Compose and E2E Tests"

# 4. Connect and Push
$remoteUrl = "https://github.com/$githubUser/$repoName.git"

# Check if remote exists, if not add it
$remotes = git remote
if ($remotes -notcontains "origin") {
    git remote add origin $remoteUrl
} else {
    git remote set-url origin $remoteUrl
}

Write-Host "Pushing to $remoteUrl..." -ForegroundColor Cyan
git push -u origin main

Write-Host "`nPlatform repository is now synced!" -ForegroundColor Green
