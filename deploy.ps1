param (
    [string]$ImageTag = "latest",
    [string]$DockerHubUser = "aishani87"
)

$DOCKER = "C:\Users\tuhi8\AppData\Local\Programs\DockerDesktop\resources\bin\docker.exe"
$FullImage = "$DockerHubUser/lab12-node-app:$ImageTag"

$activeEnv = "none"
try {
    $res = Invoke-RestMethod -Uri "http://localhost/health" -TimeoutSec 2 -ErrorAction Stop
    $info = Invoke-RestMethod -Uri "http://localhost/" -TimeoutSec 2
    $activeEnv = $info.environment
} catch {
    $activeEnv = "none"
}

if ($activeEnv -eq "blue") {
    $targetEnv = "green"
    $targetPort = 8082
} else {
    $targetEnv = "blue"
    $targetPort = 8081
}

Write-Host "Active Environment: $activeEnv"
Write-Host "Deploying new version to target environment: $targetEnv on port $targetPort"

# 2. Stop and recreate the target container
& $DOCKER rm -f "node-app-$targetEnv" 2>$null
& $DOCKER run -d --name "node-app-$targetEnv" `
    -p "${targetPort}:3000" `
    -e "APP_ENV=$targetEnv" `
    -e "APP_VERSION=$ImageTag" `
    $FullImage

# 3. Health Check: verify target environment responds before cutting over
Write-Host "Running health check on target container at http://localhost:$targetPort/health..."
$retries = 10
$healthy = $false
for ($i = 0; $i -lt $retries; $i++) {
    Start-Sleep -Seconds 2
    try {
        $status = Invoke-RestMethod -Uri "http://localhost:$targetPort/health" -TimeoutSec 2
        if ($status.status -eq "HEALTHY") {
            $healthy = $true
            break
        }
    } catch {
        Write-Host "Waiting for container startup... ($($i+1)/$retries)"
    }
}

if (-not $healthy) {
    Write-Error "Health check failed for target environment $targetEnv. Aborting switch."
    exit 1
}

Write-Host "Target container is healthy! Performing zero-downtime cutover..."

# 4. Generate updated Nginx configuration pointing to the newly deployed container
$nginxConf = @"
events {
    worker_connections 1024;
}

http {
    upstream app_servers {
        server host.docker.internal:$targetPort;
    }

    server {
        listen 80;

        location / {
            proxy_pass http://app_servers;
            proxy_set_header Host `$host;
            proxy_set_header X-Real-IP `$remote_addr;
            proxy_set_header X-Forwarded-For `$proxy_add_x_forwarded_for;
        }
    }
}
"@

$nginxConf \vert{} Out-File -FilePath "$PSScriptRoot\nginx\nginx.conf" -Encoding ascii

# 5. Check if router container exists, otherwise run it
$routerExists = &$DOCKER ps -a -q -f "name=nginx-router"
if (-not $routerExists) {
    & $DOCKER build -t nginx-router:latest "$PSScriptRoot\nginx"
    & $DOCKER run -d --name nginx-router -p 80:80 nginx-router:latest
} else {
    # Hot-reload Nginx configuration with zero downtime
    & $DOCKER cp "$PSScriptRoot\nginx\nginx.conf" nginx-router:/etc/nginx/nginx.conf
    & $DOCKER exec nginx-router nginx -s reload
}

Write-Host "Traffic successfully redirected to $targetEnv ($FullImage)!"