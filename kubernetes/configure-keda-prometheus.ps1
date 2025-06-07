#!/usr/bin/env pwsh

# Configure-KEDA-Prometheus.ps1
# This script detects KEDA and Prometheus configurations in your Kubernetes cluster
# and updates n8n worker ScaledObject configuration accordingly

# Parameters with default values that can be overridden
param(
    [string]$Namespace = "n8n",
    [string]$PromNamespace = "prometheus",
    [string]$ScaledObjectPatchFile = "overlays/production/n8n-worker-scaledobject-patch.yaml",
    [int]$MinReplicas = 2,
    [int]$MaxReplicas = 20,
    [string]$MetricName = "n8n_queue_waiting_jobs",
    [int]$Threshold = 5,
    [string]$Query = "sum(n8n_queue_waiting_jobs)"
)

Write-Host "===== n8n KEDA & Prometheus Configuration Script ====="
Write-Host "Detecting environment and configuring autoscaling..."

# Function to check if a Kubernetes resource exists
function Test-K8sResource {
    param (
        [string]$Resource,
        [string]$Name,
        [string]$Namespace = ""
    )
    
    $nsParam = ""
    if ($Namespace) {
        $nsParam = "-n $Namespace"
    }
    
    $result = kubectl get $Resource $Name $nsParam 2>&1
    return $LASTEXITCODE -eq 0
}

# Check if KEDA is installed in the cluster
Write-Host "Checking for KEDA installation..."
$kedaExists = Test-K8sResource -Resource "crd" -Name "scaledobjects.keda.sh"

if (-not $kedaExists) {
    Write-Host "ERROR: KEDA is not installed in the cluster. Please install KEDA first." -ForegroundColor Red
    Write-Host "Installation instructions: https://keda.sh/docs/latest/deploy/" -ForegroundColor Yellow
    exit 1
}

Write-Host "✅ KEDA is installed properly" -ForegroundColor Green

# Detect Prometheus server URL
Write-Host "Detecting Prometheus server..."
$prometheusSvc = $null

# First check in the provided namespace
$promSvcInNamespace = kubectl get svc -n $PromNamespace -o jsonpath="{.items[?(@.metadata.name=='prometheus-server' || @.metadata.name=='prometheus')].metadata.name}" 2>&1
if ($promSvcInNamespace) {
    $prometheusSvc = "$promSvcInNamespace.$PromNamespace.svc.cluster.local"
    Write-Host "Found Prometheus service in $PromNamespace namespace: $prometheusSvc" -ForegroundColor Green
}

# If not found, check for kube-prometheus-stack installation
if (-not $prometheusSvc) {
    $kubePromSvc = kubectl get svc -n $PromNamespace -o jsonpath="{.items[?(@.metadata.name=='prometheus-kube-prometheus-prometheus')].metadata.name}" 2>&1
    if ($kubePromSvc) {
        $prometheusSvc = "$kubePromSvc.$PromNamespace.svc.cluster.local"
        Write-Host "Found kube-prometheus-stack service in $PromNamespace namespace: $prometheusSvc" -ForegroundColor Green
    }
}

# If still not found, search in all namespaces
if (-not $prometheusSvc) {
    Write-Host "Searching for Prometheus in all namespaces (this may take a moment)..." -ForegroundColor Yellow
    $allPromSvcs = kubectl get svc --all-namespaces -o jsonpath="{range .items[?(@.metadata.name=='prometheus-server' || @.metadata.name=='prometheus' || @.metadata.name=='prometheus-kube-prometheus-prometheus')]}{.metadata.namespace}/{.metadata.name}{'\n'}{end}" 2>&1
    
    if ($allPromSvcs) {
        $firstPromSvc = $allPromSvcs -split "`n" | Select-Object -First 1
        $promParts = $firstPromSvc -split "/"
        if ($promParts.Length -eq 2) {
            $promNamespace = $promParts[0]
            $promName = $promParts[1]
            $prometheusSvc = "$promName.$promNamespace.svc.cluster.local"
            Write-Host "Found Prometheus service in $promNamespace namespace: $prometheusSvc" -ForegroundColor Green
        }
    }
}

if (-not $prometheusSvc) {
    Write-Host "WARNING: Could not automatically detect Prometheus service." -ForegroundColor Yellow
    $prometheusSvc = Read-Host "Please enter the Prometheus service URL (e.g., prometheus-server.prometheus.svc.cluster.local)"
    
    if (-not $prometheusSvc) {
        Write-Host "No Prometheus service provided. Exiting." -ForegroundColor Red
        exit 1
    }
}

# Determine Prometheus port
Write-Host "Detecting Prometheus port..."
$promPort = "9090" # Default Prometheus port
$foundPort = kubectl get svc -n $promNamespace $prometheusSvc.Split(".")[0] -o jsonpath="{.spec.ports[?(@.name=='http')].port}" 2>&1
if ($foundPort) {
    $promPort = $foundPort
}

$prometheusUrl = "http://${prometheusSvc}:${promPort}"
Write-Host "Using Prometheus URL: $prometheusUrl" -ForegroundColor Green

# Check if n8n namespace exists
Write-Host "Checking n8n namespace..."
$n8nNamespace = Test-K8sResource -Resource "namespace" -Name $Namespace
if (-not $n8nNamespace) {
    Write-Host "Creating namespace $Namespace..."
    kubectl create namespace $Namespace
}

# Check path to ScaledObject patch file
$fullPath = Join-Path -Path (Get-Location) -ChildPath $ScaledObjectPatchFile
if (-not (Test-Path $fullPath)) {
    Write-Host "ERROR: ScaledObject patch file not found at $fullPath" -ForegroundColor Red
    exit 1
}

# Create or update the n8n-worker-scaledobject-patch.yaml file
Write-Host "Updating ScaledObject patch file with Prometheus configuration..."
$scaleObjectPatch = @"
apiVersion: keda.sh/v1alpha1
kind: ScaledObject
metadata:
  name: n8n-worker-scaler
spec:
  scaleTargetRef:
    name: n8n-worker
  minReplicaCount: $MinReplicas
  maxReplicaCount: $MaxReplicas
  triggers:
  - type: prometheus
    metadata:
      serverAddress: $prometheusUrl
      metricName: $MetricName
      threshold: "$Threshold"
      query: $Query
"@

# Write the updated content to the file
Set-Content -Path $fullPath -Value $scaleObjectPatch

Write-Host "✅ ScaledObject patch file updated successfully!" -ForegroundColor Green
Write-Host "   Path: $fullPath" -ForegroundColor Green
Write-Host "   Prometheus URL: $prometheusUrl" -ForegroundColor Green
Write-Host "   Metric Name: $MetricName" -ForegroundColor Green
Write-Host "   Threshold: $Threshold" -ForegroundColor Green
Write-Host "   Min/Max Replicas: $MinReplicas/$MaxReplicas" -ForegroundColor Green

Write-Host "`nTo apply the configuration, run:"
Write-Host "kubectl apply -k kubernetes/overlays/production" -ForegroundColor Cyan

Write-Host "`n===== Configuration Complete ====="
