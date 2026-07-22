[CmdletBinding()]
param(
    [ValidateSet("Auto", "Cuda126", "Cuda130", "CPU")]
    [string]$Backend = "Auto",
    [switch]$SkipModelDownload
)

$ErrorActionPreference = "Stop"
$UvVersion = "0.11.30"
$UvInstallerSha256 = "c0ef721dc22c4a992b3218091cc7658e968194b7952e67945a71fa0bdce2b2c1"
$TorchVersion = "2.12.0"
$QwenAsrVersion = "0.0.6"
$HuggingFaceHubVersion = "1.24.0"
$SoundDeviceVersion = "0.5.5"
$NumpyVersion = "2.5.1"
$AsrRevision = "5eb144179a02acc5e5ba31e748d22b0cf3e303b0"
$Root = Join-Path $env:LOCALAPPDATA "CoveType"
$Tools = Join-Path $Root "tools"
$Runtime = Join-Path $Root "runtime"
$PythonBuilds = Join-Path $Root "python-builds"
$Cache = Join-Path $Root "uv-cache"
$Models = Join-Path $Root "models"
$AsrModel = Join-Path $Models "Qwen3-ASR-0.6B"
$Uv = Join-Path $Tools "uv.exe"
$Python = Join-Path $Runtime "Scripts\python.exe"

if ([System.Environment]::OSVersion.Platform -ne [System.PlatformID]::Win32NT) {
    throw "This installer must run on Windows."
}
if ([System.Runtime.InteropServices.RuntimeInformation]::OSArchitecture -ne "X64") {
    throw "The current Windows bootstrap supports x64 machines only."
}

New-Item -ItemType Directory -Force -Path $Root, $Tools, $PythonBuilds, $Cache, $Models | Out-Null
$env:UV_PYTHON_INSTALL_DIR = $PythonBuilds
$env:UV_CACHE_DIR = $Cache

if (-not (Test-Path $Uv)) {
    Write-Host "Installing uv $UvVersion..."
    $UvInstaller = Join-Path $env:TEMP "covetype-uv-install.ps1"
    Invoke-WebRequest "https://astral.sh/uv/$UvVersion/install.ps1" -UseBasicParsing -OutFile $UvInstaller
    $ActualUvHash = (Get-FileHash -Algorithm SHA256 -Path $UvInstaller).Hash.ToLowerInvariant()
    if ($ActualUvHash -ne $UvInstallerSha256) {
        Remove-Item -Force $UvInstaller
        throw "uv installer checksum verification failed."
    }
    $env:UV_UNMANAGED_INSTALL = $Tools
    try {
        & powershell.exe -NoProfile -ExecutionPolicy Bypass -File $UvInstaller
    } finally {
        Remove-Item -Force -ErrorAction SilentlyContinue $UvInstaller
    }
}
if (-not (Test-Path $Uv)) {
    throw "uv installation failed."
}

if (-not (Test-Path $Python)) {
    Write-Host "Installing private CPython 3.12..."
    & $Uv venv --python 3.12 $Runtime
}

if ($Backend -eq "Auto") {
    if (Get-Command nvidia-smi.exe -ErrorAction SilentlyContinue) {
        $Backend = "Cuda126"
    } else {
        $Backend = "CPU"
    }
}

switch ($Backend) {
    "Cuda126" { $TorchIndex = "https://download.pytorch.org/whl/cu126" }
    "Cuda130" { $TorchIndex = "https://download.pytorch.org/whl/cu130" }
    "CPU"     { $TorchIndex = "https://download.pytorch.org/whl/cpu" }
}

Write-Host "Installing PyTorch $TorchVersion backend: $Backend"
& $Uv pip install --python $Python "torch==$TorchVersion" --index-url $TorchIndex
& $Uv pip install --python $Python --upgrade `
    "qwen-asr==$QwenAsrVersion" `
    "huggingface-hub==$HuggingFaceHubVersion" `
    "sounddevice==$SoundDeviceVersion" `
    "numpy==$NumpyVersion"

if (-not $SkipModelDownload) {
    Write-Host "Downloading Qwen3-ASR 0.6B..."
    $DownloadCode = @'
import sys
import json
from pathlib import Path
from huggingface_hub import snapshot_download

root = Path(sys.argv[1])
revision = sys.argv[2]
snapshot_download(repo_id="Qwen/Qwen3-ASR-0.6B", revision=revision, local_dir=root)
if not (root / "config.json").is_file():
    raise SystemExit("Qwen3-ASR config is missing")
index_path = root / "model.safetensors.index.json"
if index_path.is_file():
    shards = set(json.loads(index_path.read_text(encoding="utf-8")).get("weight_map", {}).values())
    if not shards or any(not (root / shard).is_file() or (root / shard).stat().st_size == 0 for shard in shards):
        raise SystemExit("Qwen3-ASR weights are incomplete")
elif not (root / "model.safetensors").is_file() or (root / "model.safetensors").stat().st_size == 0:
    raise SystemExit("Qwen3-ASR weights are missing")
'@
    & $Python -c $DownloadCode $AsrModel $AsrRevision
}

$HealthCode = @'
import torch
import qwen_asr
print("WINDOWS_BACKEND=PASS")
print("TORCH_VERSION=" + torch.__version__)
print("CUDA_AVAILABLE=" + str(torch.cuda.is_available()))
'@
& $Python -c $HealthCode

$Launcher = Join-Path $Root "Start Qwen3-ASR Demo.ps1"
$DeviceMap = if ($Backend -eq "CPU") { "cpu" } else { "cuda:0" }
$DType = if ($Backend -eq "CPU") { "float32" } else { "bfloat16" }
$LauncherBody = @"
`$ErrorActionPreference = "Stop"
& "$Runtime\Scripts\qwen-asr-demo.exe" ``
  --asr-checkpoint "$AsrModel" ``
  --backend transformers ``
  --ip 127.0.0.1 ``
  --port 8000 ``
  --backend-kwargs '{"device_map":"$DeviceMap","dtype":"$DType","max_inference_batch_size":1,"max_new_tokens":512}'
"@
Set-Content -Path $Launcher -Value $LauncherBody -Encoding UTF8

Write-Host ""
Write-Host "Qwen3-ASR Windows backend installation completed."
Write-Host "Demo launcher: $Launcher"
Write-Host "This installs the tested CoveType model backend, not yet a native Windows global-input client."
