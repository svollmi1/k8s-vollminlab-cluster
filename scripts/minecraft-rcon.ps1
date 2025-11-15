# Minecraft RCON Helper Script
# Usage: .\minecraft-rcon.ps1 "command here"
# Example: .\minecraft-rcon.ps1 "worldborder set 30000"

param(
    [Parameter(Mandatory=$true)]
    [string]$Command,
    
    [string]$Namespace = "dmz"
)

# Get the Minecraft pod name
$podName = kubectl get pods -n $Namespace -l app=minecraft-minecraft -o jsonpath='{.items[0].metadata.name}' 2>$null

if (-not $podName) {
    Write-Error "Could not find Minecraft pod in namespace $Namespace"
    exit 1
}

Write-Host "Executing RCON command on pod: $podName" -ForegroundColor Green
Write-Host "Command: $Command" -ForegroundColor Yellow

# Execute the RCON command
kubectl exec $podName -n $Namespace -- rcon-cli "$Command"

