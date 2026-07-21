Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

if (Test-Path -LiteralPath Variable:PSNativeCommandUseErrorActionPreference) {
    Set-Variable -Name PSNativeCommandUseErrorActionPreference -Value $false -Scope Script
}

$script:RootDir = $PSScriptRoot
$script:ImageConfig = Join-Path (Join-Path $script:RootDir 'config') 'images.env'
$script:LabLabel = 'cloudsprocket.lab=docker'
$script:NetworkName = 'dpl-net'
$script:PortMinimum = 8200
$script:PortMaximum = 8299
$script:MinimumFreeBytes = [long](5GB)
$script:ImageConfigValues = @{}

function Write-LabError {
    param(
        [Parameter(Mandatory = $true)]
        [string]$Message
    )

    [Console]::Error.WriteLine(('Error: {0}' -f $Message))
    exit 1
}

function Import-ImageConfig {
    if (-not (Test-Path -LiteralPath $script:ImageConfig -PathType Leaf)) {
        Write-LabError ('Image configuration is missing: {0}' -f $script:ImageConfig)
    }

    $values = @{}
    foreach ($line in Get-Content -LiteralPath $script:ImageConfig) {
        $trimmed = $line.Trim()
        if ($trimmed.Length -eq 0 -or $trimmed.StartsWith('#')) {
            continue
        }

        if ($trimmed -notmatch '^([A-Z][A-Z0-9_]*)=(.+)$') {
            Write-LabError ('Image configuration contains an invalid entry: {0}' -f $trimmed)
        }

        $values[$Matches[1]] = $Matches[2].Trim()
    }

    foreach ($requiredName in @('PYTHON_IMAGE', 'NODE_IMAGE', 'NGINX_IMAGE', 'REGISTRY_IMAGE')) {
        if (-not $values.ContainsKey($requiredName) -or [string]::IsNullOrWhiteSpace([string]$values[$requiredName])) {
            Write-LabError ('Image configuration is missing {0}: {1}' -f $requiredName, $script:ImageConfig)
        }
    }

    $script:ImageConfigValues = $values
}

function Test-DockerCli {
    return $null -ne (Get-Command docker -ErrorAction SilentlyContinue)
}

function Assert-DockerCli {
    if (-not (Test-DockerCli)) {
        Write-LabError 'Docker was not found. Install Docker Engine or Docker Desktop, then try again.'
    }
}

function Get-DockerContext {
    $contextOutput = @(& docker context show 2> $null)
    if ($LASTEXITCODE -ne 0) {
        return ''
    }

    return (($contextOutput -join "`n").Trim())
}

function Assert-DockerDaemon {
    Assert-DockerCli
    & docker info > $null 2>&1
    if ($LASTEXITCODE -eq 0) {
        return
    }

    $context = Get-DockerContext
    if ($context -like 'desktop-*') {
        Write-LabError 'Docker Desktop is not reachable. Start Docker Desktop and wait until the engine is ready.'
    }

    Write-LabError 'The Docker daemon is not reachable. Start the Docker Engine service and try again.'
}

function Invoke-DockerChecked {
    param(
        [Parameter(Mandatory = $true)]
        [string[]]$DockerArguments,

        [switch]$DiscardOutput
    )

    if ($DiscardOutput) {
        & docker @DockerArguments | Out-Null
    }
    else {
        & docker @DockerArguments
    }

    $nativeExitCode = $LASTEXITCODE
    if ($nativeExitCode -ne 0) {
        exit $nativeExitCode
    }
}

function Get-NetworkLabel {
    $labelOutput = @(
        & docker network inspect --format '{{index .Labels "cloudsprocket.lab"}}' $script:NetworkName 2> $null
    )
    if ($LASTEXITCODE -ne 0) {
        return ''
    }

    return (($labelOutput -join "`n").Trim())
}

function Invoke-LabNetworkPreparation {
    & docker network inspect $script:NetworkName > $null 2>&1
    if ($LASTEXITCODE -eq 0) {
        if ((Get-NetworkLabel) -ne 'docker') {
            Write-LabError ('Network {0} already exists without the {1} ownership label. Rename or remove it yourself.' -f $script:NetworkName, $script:LabLabel)
        }

        Write-Host ('Network {0} is ready.' -f $script:NetworkName)
        return
    }

    Invoke-DockerChecked -DockerArguments @('network', 'create', '--label', $script:LabLabel, $script:NetworkName) -DiscardOutput
    Write-Host ('Created labelled network {0}.' -f $script:NetworkName)
}

function Invoke-BaseImagePreparation {
    param(
        [Parameter(Mandatory = $true)]
        [string]$Image
    )

    & docker image inspect $Image > $null 2>&1
    if ($LASTEXITCODE -eq 0) {
        Write-Host ('Base image {0} is already available.' -f $Image)
        return
    }

    Write-Host ('Pulling base image {0}. This is needed only on the first run.' -f $Image)
    Invoke-DockerChecked -DockerArguments @('pull', $Image)
}

function Get-LabelledContainerId {
    return @(
        & docker container ls --all --quiet --filter ('label={0}' -f $script:LabLabel) 2> $null |
            Where-Object { -not [string]::IsNullOrWhiteSpace([string]$_) }
    )
}

function Get-LabelledNetworkId {
    return @(
        & docker network ls --quiet --filter ('label={0}' -f $script:LabLabel) 2> $null |
            Where-Object { -not [string]::IsNullOrWhiteSpace([string]$_) }
    )
}

function Get-LabelledVolumeId {
    return @(
        & docker volume ls --quiet --filter ('label={0}' -f $script:LabLabel) 2> $null |
            Where-Object { -not [string]::IsNullOrWhiteSpace([string]$_) }
    )
}

function Get-LabelledImageId {
    return @(
        & docker image ls --all --quiet --filter ('label={0}' -f $script:LabLabel) 2> $null |
            Where-Object { -not [string]::IsNullOrWhiteSpace([string]$_) }
    )
}

function Invoke-LabelledContainerRemoval {
    $ids = @(Get-LabelledContainerId)
    if ($ids.Count -eq 0) {
        Write-Host 'No labelled lab containers to remove.'
        return
    }

    $dockerArguments = @('container', 'rm', '--force') + $ids
    Invoke-DockerChecked -DockerArguments $dockerArguments -DiscardOutput
    Write-Host ('Removed {0} labelled lab container(s).' -f $ids.Count)
}

function Invoke-LabelledNetworkRemoval {
    $ids = @(Get-LabelledNetworkId)
    if ($ids.Count -eq 0) {
        Write-Host 'No labelled lab networks to remove.'
        return
    }

    $dockerArguments = @('network', 'rm') + $ids
    Invoke-DockerChecked -DockerArguments $dockerArguments -DiscardOutput
    Write-Host ('Removed {0} labelled lab network(s).' -f $ids.Count)
}

function Invoke-LabelledVolumeRemoval {
    $ids = @(Get-LabelledVolumeId)
    if ($ids.Count -eq 0) {
        Write-Host 'No labelled lab volumes to remove.'
        return
    }

    $dockerArguments = @('volume', 'rm') + $ids
    Invoke-DockerChecked -DockerArguments $dockerArguments -DiscardOutput
    Write-Host ('Removed {0} labelled lab volume(s).' -f $ids.Count)
}

function Invoke-LabelledImageRemoval {
    $rawIds = @(Get-LabelledImageId)
    $ids = @($rawIds | Select-Object -Unique)
    if ($ids.Count -eq 0) {
        Write-Host 'No labelled lab images to remove.'
        return
    }

    # A labelled image is lab-created, so removing every tag it carries is
    # within the reset contract; without --force a multi-tagged image aborts.
    $dockerArguments = @('image', 'rm', '--force') + $ids
    Invoke-DockerChecked -DockerArguments $dockerArguments -DiscardOutput
    Write-Host ('Removed {0} labelled lab image(s).' -f $ids.Count)
}

function Format-ByteCount {
    param(
        [Parameter(Mandatory = $true)]
        [long]$Bytes
    )

    $culture = [System.Globalization.CultureInfo]::InvariantCulture
    if ($Bytes -ge 1GB) {
        return (([double]$Bytes / [double](1GB)).ToString('0.00', $culture) + ' GiB')
    }
    if ($Bytes -ge 1MB) {
        return (([double]$Bytes / [double](1MB)).ToString('0.00', $culture) + ' MiB')
    }
    if ($Bytes -ge 1KB) {
        return (([double]$Bytes / [double](1KB)).ToString('0.00', $culture) + ' KiB')
    }

    return ($Bytes.ToString($culture) + ' B')
}

function Test-ComposeVersion {
    param(
        [Parameter(Mandatory = $true)]
        [string]$RawVersion
    )

    $version = $RawVersion
    if ($version.StartsWith('v')) {
        $version = $version.Substring(1)
    }

    $suffixIndex = $version.IndexOf('-')
    if ($suffixIndex -ge 0) {
        $version = $version.Substring(0, $suffixIndex)
    }

    $parts = @($version -split '\.')
    if ($parts.Count -lt 2 -or $parts[0] -notmatch '^[0-9]+$' -or $parts[1] -notmatch '^[0-9]+$') {
        return $false
    }

    $major = 0
    $minor = 0
    if (-not [int]::TryParse($parts[0], [ref]$major) -or -not [int]::TryParse($parts[1], [ref]$minor)) {
        return $false
    }

    return ($major -gt 2 -or ($major -eq 2 -and $minor -ge 20))
}

function Get-HostListenerRecord {
    if ($null -ne (Get-Command Get-NetTCPConnection -ErrorAction SilentlyContinue)) {
        $connections = @(
            Get-NetTCPConnection -State Listen -ErrorAction SilentlyContinue |
                Where-Object {
                    $_.LocalPort -ge $script:PortMinimum -and
                    $_.LocalPort -le $script:PortMaximum
                } |
                Sort-Object -Property LocalPort
        )
        $seenPorts = @{}
        foreach ($connection in $connections) {
            $port = [int]$connection.LocalPort
            if ($seenPorts.ContainsKey($port)) {
                continue
            }
            $seenPorts[$port] = $true

            $ownerProcessId = [int]$connection.OwningProcess
            $description = '{0}:{1} PID {2}' -f $connection.LocalAddress, $port, $ownerProcessId
            $processInfo = Get-Process -Id $ownerProcessId -ErrorAction SilentlyContinue
            if ($null -ne $processInfo) {
                $description += ' ({0})' -f $processInfo.ProcessName
            }
            Write-Output ('{0}|{1}' -f $port, $description)
        }
        return
    }

    if ($null -ne (Get-Command netstat -ErrorAction SilentlyContinue)) {
        $netstatLines = @(& netstat -ano -p tcp 2> $null)
        $seenPorts = @{}
        foreach ($line in $netstatLines) {
            $text = ([string]$line).Trim()
            if ($text -notmatch '(?i)^TCP\s+\S+:(?<Port>[0-9]+)\s+\S+\s+LISTEN(?:ING)?(?:\s+\d+)?$') {
                continue
            }
            $port = [int]$Matches['Port']
            if ($port -lt $script:PortMinimum -or $port -gt $script:PortMaximum -or $seenPorts.ContainsKey($port)) {
                continue
            }
            $seenPorts[$port] = $true
            Write-Output ('{0}|{1}' -f $port, $text)
        }
    }
}

function Test-LabPort {
    $failures = 0
    $dockerPorts = @{}
    $containerRows = @(
        & docker container ls --format '{{.Names}}|{{.Ports}}|{{.Label "cloudsprocket.lab"}}' 2> $null
    )
    if ($LASTEXITCODE -ne 0) {
        exit $LASTEXITCODE
    }

    foreach ($containerRowValue in $containerRows) {
        $containerRow = [string]$containerRowValue
        if ([string]::IsNullOrWhiteSpace($containerRow)) {
            continue
        }
        $parts = @($containerRow -split '\|', 3)
        $name = $parts[0]
        $mappings = if ($parts.Count -gt 1) { $parts[1] } else { '' }
        $owner = if ($parts.Count -gt 2) { $parts[2] } else { '' }

        foreach ($mapping in @($mappings -split ',')) {
            if ($mapping -notmatch ':(?<Port>[0-9]+)->') {
                continue
            }
            $port = [int]$Matches['Port']
            if ($port -lt $script:PortMinimum -or $port -gt $script:PortMaximum) {
                continue
            }
            # Dual-stack publishing repeats one host port per address family.
            if ($dockerPorts.ContainsKey($port)) {
                continue
            }
            $dockerPorts[$port] = $true
            if ($owner -ne 'docker') {
                if ([string]::IsNullOrWhiteSpace($owner)) {
                    $owner = 'unlabelled'
                }
                Write-Host ('FAIL  Port {0} is held by container {1} ({2}). Stop it before using this lab.' -f $port, $name, $owner)
                $failures++
            }
        }
    }

    foreach ($listenerRecordValue in @(Get-HostListenerRecord)) {
        $listenerRecord = [string]$listenerRecordValue
        $parts = @($listenerRecord -split '\|', 2)
        if ($parts.Count -ne 2) {
            continue
        }
        $port = [int]$parts[0]
        if ($dockerPorts.ContainsKey($port)) {
            continue
        }
        Write-Host ('FAIL  Port {0} is held by a host process: {1}' -f $port, $parts[1])
        $failures++
    }

    if ($failures -eq 0) {
        Write-Host ('PASS  Ports {0}-{1} are available or already owned by this lab.' -f $script:PortMinimum, $script:PortMaximum)
    }

    return [int]$failures
}

function Invoke-LabDoctor {
    $failures = 0
    Write-Host 'Docker Practical Lab doctor'
    Write-Host

    if (-not (Test-DockerCli)) {
        Write-Host 'FAIL  Docker was not found. Install Docker Engine or Docker Desktop.'
        return 1
    }
    Write-Host 'PASS  Docker CLI is installed.'

    & docker info > $null 2>&1
    if ($LASTEXITCODE -ne 0) {
        $context = Get-DockerContext
        if ($context -like 'desktop-*') {
            Write-Host 'FAIL  Docker Desktop is not reachable. Start Docker Desktop and wait for its engine.'
        }
        else {
            Write-Host 'FAIL  Docker Engine is not reachable. Start the Docker service and try again.'
        }
        return 1
    }

    $serverVersionOutput = @(& docker version --format '{{.Server.Version}}')
    if ($LASTEXITCODE -ne 0) {
        exit $LASTEXITCODE
    }
    $serverVersion = (($serverVersionOutput -join "`n").Trim())
    Write-Host ('PASS  Docker daemon {0} is reachable.' -f $serverVersion)

    $composeOutput = @(& docker compose version --short 2> $null)
    $composeRaw = (($composeOutput -join "`n").Trim())
    if ([string]::IsNullOrWhiteSpace($composeRaw)) {
        Write-Host 'FAIL  The Docker Compose plugin is unavailable. Install a current Docker Compose plugin.'
        $failures++
    }
    elseif (Test-ComposeVersion -RawVersion $composeRaw) {
        Write-Host ('PASS  Docker Compose plugin {0} meets the 2.20 minimum.' -f $composeRaw)
    }
    else {
        Write-Host ('FAIL  Docker Compose plugin {0} is unsupported. Install version 2.20 or later.' -f $composeRaw)
        $failures++
    }

    & docker buildx version > $null 2>&1
    if ($LASTEXITCODE -eq 0) {
        Write-Host 'PASS  BuildKit is available through Docker Buildx.'
    }
    else {
        Write-Host 'WARN  Docker Buildx was not detected. It becomes required for exercise 09.'
    }

    $driverOutput = @(& docker info --format '{{.Driver}}')
    if ($LASTEXITCODE -ne 0) {
        exit $LASTEXITCODE
    }
    $driver = (($driverOutput -join "`n").Trim())
    $driverStatusOutput = @(& docker info --format '{{json .DriverStatus}}')
    if ($LASTEXITCODE -ne 0) {
        exit $LASTEXITCODE
    }
    $driverStatus = (($driverStatusOutput -join "`n").Trim())
    if ($driverStatus.Contains('io.containerd.snapshotter.v1')) {
        Write-Host 'INFO  Image store: containerd. Reported image sizes can differ from the classic store.'
    }
    else {
        Write-Host ('INFO  Image store: classic {0} graphdriver. Reported image sizes can differ from containerd.' -f $driver)
    }

    $availableFreeBytes = $null
    try {
        $driveRoot = [System.IO.Path]::GetPathRoot($script:RootDir)
        if (-not [string]::IsNullOrWhiteSpace($driveRoot)) {
            $driveInfo = New-Object -TypeName System.IO.DriveInfo -ArgumentList $driveRoot
            if ($driveInfo.IsReady) {
                $availableFreeBytes = [long]$driveInfo.AvailableFreeSpace
            }
        }
    }
    catch {
        $availableFreeBytes = $null
    }

    if ($null -ne $availableFreeBytes) {
        if ($availableFreeBytes -lt $script:MinimumFreeBytes) {
            Write-Host 'FAIL  Less than 5 GiB is free on the workspace drive. Free space before pulling images.'
            $failures++
        }
        else {
            Write-Host 'PASS  The workspace drive has at least 5 GiB free.'
            Write-Host 'INFO  Docker Desktop uses a separate virtual disk; confirm its allocation if pulls fail.'
        }
    }
    else {
        Write-Host 'WARN  Free disk space could not be measured. Keep at least 5 GiB available for images.'
    }

    & docker network inspect $script:NetworkName > $null 2>&1
    if ($LASTEXITCODE -eq 0 -and (Get-NetworkLabel) -ne 'docker') {
        Write-Host ('FAIL  Network {0} exists without the {1} ownership label. Rename or remove it yourself.' -f $script:NetworkName, $script:LabLabel)
        $failures++
    }

    $portFailures = Test-LabPort
    $failures += $portFailures

    $stale = 0
    $containerStates = @(
        & docker container ls --all --filter ('label={0}' -f $script:LabLabel) --format '{{.Names}}|{{.State}}'
    )
    if ($LASTEXITCODE -ne 0) {
        exit $LASTEXITCODE
    }
    foreach ($containerStateValue in $containerStates) {
        $containerState = [string]$containerStateValue
        if ([string]::IsNullOrWhiteSpace($containerState)) {
            continue
        }

        $stateParts = @($containerState -split '\|', 2)
        $name = $stateParts[0]
        $state = if ($stateParts.Count -gt 1) { $stateParts[1] } else { '' }
        if ($state -ne 'running') {
            Write-Host ('WARN  Labelled container {0} is {1}. Run .\lab.ps1 up to recover or .\lab.ps1 reset for a clean state.' -f $name, $state)
            $stale++
        }
    }
    if ($stale -eq 0) {
        Write-Host 'PASS  No stale labelled containers were found.'
    }

    if ($env:CODESPACES -eq 'true') {
        Write-Host 'PASS  Codespaces Docker-in-Docker is isolated from your local Docker daemon.'
        Write-Host 'INFO  Personal accounts include 120 core-hours and 15 GB storage monthly. Stop the Codespace when finished.'
        Write-Host 'WARN  The privileged development container is not a security boundary.'
    }

    Write-Host
    if ($failures -eq 0) {
        Write-Host 'Doctor found no blocking problems.'
    }
    else {
        Write-Host ('Doctor found {0} blocking problem(s).' -f $failures)
    }
    return [int]$failures
}

function Invoke-WorkspacePreparation {
    Write-Host
    Write-Host 'Preparing the Docker practice workspace...'
    Invoke-LabNetworkPreparation
    Invoke-BaseImagePreparation -Image ([string]$script:ImageConfigValues['PYTHON_IMAGE'])
    Invoke-BaseImagePreparation -Image ([string]$script:ImageConfigValues['NODE_IMAGE'])
    Invoke-BaseImagePreparation -Image ([string]$script:ImageConfigValues['NGINX_IMAGE'])
    Invoke-BaseImagePreparation -Image ([string]$script:ImageConfigValues['REGISTRY_IMAGE'])
    Write-Host
    Write-Host 'Workspace ready. Start with: .\lab.ps1 check 01 after completing exercise 01.'
    Write-Host 'Browse exercises/ for the learning track.'
}

function Invoke-LabStart {
    Assert-DockerDaemon
    $doctorFailures = Invoke-LabDoctor
    if ($doctorFailures -ne 0) {
        Write-LabError 'Doctor found blocking problems. Fix the reported items, then run .\lab.ps1 up.'
    }

    Invoke-WorkspacePreparation
}

function Invoke-LabStop {
    Assert-DockerDaemon
    Invoke-LabelledContainerRemoval
    Write-Host 'Lab images, volumes and the baseline network were kept.'
}

function Invoke-LabReset {
    Assert-DockerDaemon
    Write-Host ('Removing only resources carrying {0}.' -f $script:LabLabel)
    Invoke-LabelledContainerRemoval
    Invoke-LabelledNetworkRemoval
    Invoke-LabelledVolumeRemoval
    Invoke-LabelledImageRemoval
    Write-Host 'Shared upstream images and BuildKit cache were left untouched.'
    Write-Host

    # Recreate the baseline network before the doctor gate so a blocking
    # doctor finding cannot strand the learner without a clean baseline.
    Invoke-LabNetworkPreparation
    $doctorFailures = Invoke-LabDoctor
    if ($doctorFailures -ne 0) {
        Write-LabError 'Cleanup finished and the baseline network was recreated, but doctor found blocking problems. Fix the reported items, then run .\lab.ps1 up.'
    }

    Invoke-WorkspacePreparation
}

function Show-LabStatus {
    Assert-DockerDaemon
    Write-Host 'Docker Practical Lab status'
    Write-Host

    & docker network inspect $script:NetworkName > $null 2>&1
    if ($LASTEXITCODE -eq 0 -and (Get-NetworkLabel) -eq 'docker') {
        Write-Host ('Baseline network: {0} (ready)' -f $script:NetworkName)
    }
    else {
        Write-Host 'Baseline network: not ready; run .\lab.ps1 up'
    }

    $containers = @(
        & docker container ls --all --filter ('label={0}' -f $script:LabLabel) --format 'table {{.Names}}\t{{.Status}}\t{{.Ports}}'
    )
    if ($LASTEXITCODE -ne 0) {
        exit $LASTEXITCODE
    }
    if ($containers.Count -gt 1) {
        Write-Host
        foreach ($containerLine in $containers) {
            Write-Host ([string]$containerLine)
        }
    }
    else {
        Write-Host
        Write-Host 'Labelled containers: none'
    }

    $registryState = 'stopped'
    & docker container inspect dpl-registry > $null 2>&1
    if ($LASTEXITCODE -eq 0) {
        $registryOwnerOutput = @(
            & docker container inspect --format '{{index .Config.Labels "cloudsprocket.lab"}}' dpl-registry 2> $null
        )
        $registryOwner = (($registryOwnerOutput -join "`n").Trim())
        if ($registryOwner -eq 'docker') {
            $registryStateOutput = @(
                & docker container inspect --format '{{if .State.Running}}running{{else}}stopped{{end}}' dpl-registry
            )
            if ($LASTEXITCODE -ne 0) {
                exit $LASTEXITCODE
            }
            $registryState = (($registryStateOutput -join "`n").Trim())
        }
    }
    Write-Host ('Local registry: {0}' -f $registryState)

    $imageIds = @(Get-LabelledImageId)
    [long]$total = 0
    foreach ($imageIdValue in $imageIds) {
        $imageId = ([string]$imageIdValue).Trim()
        $sizeOutput = @(& docker image inspect --format '{{.Size}}' $imageId)
        if ($LASTEXITCODE -ne 0) {
            exit $LASTEXITCODE
        }
        $sizeText = (($sizeOutput -join "`n").Trim())
        [long]$size = 0
        if ([long]::TryParse($sizeText, [ref]$size)) {
            $total += $size
        }
    }
    Write-Host ('Labelled image sizes: {0} across {1} image reference(s)' -f (Format-ByteCount -Bytes $total), $imageIds.Count)
}

function Show-LabLog {
    param(
        [string]$Target = ''
    )

    Assert-DockerDaemon
    if (-not [string]::IsNullOrWhiteSpace($Target)) {
        $idOutput = @(& docker container inspect --format '{{.Id}}' $Target 2> $null)
        $id = (($idOutput -join "`n").Trim())
        if ([string]::IsNullOrWhiteSpace($id)) {
            Write-LabError ('Container {0} does not exist.' -f $Target)
        }

        $ownerOutput = @(
            & docker container inspect --format '{{index .Config.Labels "cloudsprocket.lab"}}' $id 2> $null
        )
        $owner = (($ownerOutput -join "`n").Trim())
        if ($owner -ne 'docker') {
            Write-LabError ('Container {0} is not owned by this lab.' -f $Target)
        }

        Invoke-DockerChecked -DockerArguments @('logs', '--follow', '--tail', '100', $id)
        return
    }

    $ids = @(
        & docker container ls --quiet --filter ('label={0}' -f $script:LabLabel) 2> $null |
            Where-Object { -not [string]::IsNullOrWhiteSpace([string]$_) }
    )
    if ($ids.Count -eq 0) {
        Write-Host 'No running lab containers have logs yet.'
    }
    elseif ($ids.Count -eq 1) {
        Invoke-DockerChecked -DockerArguments @('logs', '--follow', '--tail', '100', [string]$ids[0])
    }
    else {
        Write-Host 'More than one lab container is running. Choose one:'
        Invoke-DockerChecked -DockerArguments @(
            'container', 'ls', '--filter', ('label={0}' -f $script:LabLabel), '--format', '  {{.Names}}'
        )
        Write-Host 'Run .\lab.ps1 logs <container>.'
    }
}

function Invoke-ExerciseCheck {
    param(
        [string]$Exercise = ''
    )

    if ($Exercise -notmatch '^[0-9][0-9]$') {
        Write-LabError 'Provide a two-digit exercise number, for example: .\lab.ps1 check 01'
    }

    $checksDir = Join-Path $script:RootDir 'checks'
    $checkPattern = Join-Path $checksDir ($Exercise + '_*.sh')
    $checkFiles = @(Get-ChildItem -Path $checkPattern -File -ErrorAction SilentlyContinue)
    if ($checkFiles.Count -eq 0) {
        Write-LabError ('Exercise {0} is not available in this alpha yet.' -f $Exercise)
    }

    if ($null -eq (Get-Command bash -ErrorAction SilentlyContinue)) {
        Write-LabError 'Exercise checks run through bash, which was not found. Install Git for Windows (it includes Git Bash) or enable WSL, then try again.'
    }

    & bash $checkFiles[0].FullName
    if ($LASTEXITCODE -ne 0) {
        exit $LASTEXITCODE
    }
}

function Invoke-RegistryCommand {
    param(
        [string]$Action = ''
    )

    Assert-DockerDaemon
    switch -CaseSensitive ($Action) {
        'start' {
            Invoke-LabNetworkPreparation
            Invoke-BaseImagePreparation -Image ([string]$script:ImageConfigValues['REGISTRY_IMAGE'])
            & docker container inspect dpl-registry > $null 2>&1
            if ($LASTEXITCODE -eq 0) {
                $ownerOutput = @(
                    & docker container inspect --format '{{index .Config.Labels "cloudsprocket.lab"}}' dpl-registry 2> $null
                )
                $owner = (($ownerOutput -join "`n").Trim())
                if ($owner -ne 'docker') {
                    Write-LabError 'Container dpl-registry exists without the lab ownership label. Remove it yourself if it is safe to do so.'
                }
                $runningOutput = @(
                    & docker container inspect --format '{{.State.Running}}' dpl-registry
                )
                $running = (($runningOutput -join "`n").Trim())
                if ($running -eq 'true') {
                    Write-Host 'Local registry dpl-registry is already running on 127.0.0.1:8200.'
                    return
                }
                Invoke-DockerChecked -DockerArguments @('container', 'start', 'dpl-registry') | Out-Null
                Write-Host 'Started existing registry container dpl-registry.'
                return
            }

            Invoke-DockerChecked -DockerArguments @(
                'run', '-d',
                '--name', 'dpl-registry',
                '--label', $script:LabLabel,
                '--network', $script:NetworkName,
                '-p', '127.0.0.1:8200:5000',
                ([string]$script:ImageConfigValues['REGISTRY_IMAGE'])
            ) | Out-Null
            Write-Host 'Started local registry dpl-registry on 127.0.0.1:8200.'
            break
        }
        'stop' {
            & docker container inspect dpl-registry > $null 2>&1
            if ($LASTEXITCODE -ne 0) {
                Write-Host 'Local registry is not present.'
                return
            }
            $ownerOutput = @(
                & docker container inspect --format '{{index .Config.Labels "cloudsprocket.lab"}}' dpl-registry 2> $null
            )
            $owner = (($ownerOutput -join "`n").Trim())
            if ($owner -ne 'docker') {
                Write-LabError 'Container dpl-registry is not owned by this lab.'
            }
            Invoke-DockerChecked -DockerArguments @('container', 'rm', '--force', 'dpl-registry') | Out-Null
            Write-Host 'Removed local registry container dpl-registry.'
            break
        }
        '' {
            Write-LabError 'Usage: .\lab.ps1 registry start|stop'
            break
        }
        default {
            Write-LabError ("Unknown registry action '{0}'. Use start or stop." -f $Action)
            break
        }
    }
}

function Get-DrillDirectory {
    param([string]$Name = '')

    if ([string]::IsNullOrWhiteSpace($Name)) {
        Write-LabError 'Provide a drill name, for example: .\lab.ps1 break crash-loop'
    }
    $dir = Join-Path (Join-Path $script:RootDir 'drills') $Name
    if (-not (Test-Path -LiteralPath $dir -PathType Container)) {
        Write-LabError ("Unknown drill '{0}'. Run .\lab.ps1 drills." -f $Name)
    }
    return $dir
}

function Show-DrillList {
    $catalog = Join-Path (Join-Path $script:RootDir 'drills') 'catalog.tsv'
    if (-not (Test-Path -LiteralPath $catalog -PathType Leaf)) {
        Write-LabError 'Drill catalogue is missing.'
    }
    Write-Host 'Available drills:'
    Get-Content -LiteralPath $catalog | Select-Object -Skip 1 | ForEach-Object {
        if ([string]::IsNullOrWhiteSpace($_)) { return }
        $parts = $_ -split "`t"
        if ($parts.Count -ge 4) {
            Write-Host ('  {0,-14}  (difficulty {1})  {2}' -f $parts[1], $parts[2], $parts[3])
        }
    }
}

function Invoke-DrillBreak {
    param([string]$Name = '')
    Assert-DockerDaemon
    $dir = Get-DrillDirectory -Name $Name
    $breakScript = Join-Path $dir 'break.sh'
    if (-not (Test-Path -LiteralPath $breakScript -PathType Leaf)) {
        Write-LabError ("Drill '{0}' has no break.sh" -f $Name)
    }
    if ($null -eq (Get-Command bash -ErrorAction SilentlyContinue)) {
        Write-LabError 'Drills run through bash. Install Git for Windows or enable WSL.'
    }
    & bash $breakScript
    if ($LASTEXITCODE -ne 0) { exit $LASTEXITCODE }
}

function Invoke-DrillVerify {
    param([string]$Name = '')
    Assert-DockerDaemon
    if ($null -eq (Get-Command bash -ErrorAction SilentlyContinue)) {
        Write-LabError 'Drills run through bash. Install Git for Windows or enable WSL.'
    }
    # Delegate to the Bash wrapper so marker semantics stay identical.
    Push-Location $script:RootDir
    try {
        if ([string]::IsNullOrWhiteSpace($Name)) {
            & bash ./lab verify
        }
        else {
            & bash ./lab verify $Name
        }
        if ($LASTEXITCODE -ne 0) { exit $LASTEXITCODE }
    }
    finally {
        Pop-Location
    }
}

function Show-Usage {
    Write-Host @'
Usage: .\lab.ps1 <command> [argument]

Commands:
  up                 Prepare the labelled network and base images
  down               Stop and remove labelled lab containers only
  reset              Recreate the clean baseline using label-only cleanup
  status             Show lab containers, ports, registry and image sizes
  doctor             Check Docker, Compose, BuildKit, disk and ports
  check <exercise>   Run an exercise self-check (01-10)
  registry <action>  start|stop the local registry on 127.0.0.1:8200
  break <drill>      Apply a break/fix drill
  verify [drill]     Verify a drill repair (or report nothing broken)
  drills             List available drills
  logs [container]   Follow logs for a labelled lab container
  version            Print the lab version
  help               Show this help
'@
}

Import-ImageConfig
$commandName = if ($args.Count -gt 0) { [string]$args[0] } else { 'help' }
$argument = if ($args.Count -gt 1) { [string]$args[1] } else { '' }
$commandExitCode = 0

switch -CaseSensitive ($commandName) {
    'up' {
        Invoke-LabStart
        break
    }
    'down' {
        Invoke-LabStop
        break
    }
    'reset' {
        Invoke-LabReset
        break
    }
    'status' {
        Show-LabStatus
        break
    }
    'doctor' {
        $commandExitCode = Invoke-LabDoctor
        break
    }
    'check' {
        Invoke-ExerciseCheck -Exercise $argument
        break
    }
    'registry' {
        Invoke-RegistryCommand -Action $argument
        break
    }
    'break' {
        Invoke-DrillBreak -Name $argument
        break
    }
    'verify' {
        Invoke-DrillVerify -Name $argument
        break
    }
    'drills' {
        Show-DrillList
        break
    }
    'logs' {
        Show-LabLog -Target $argument
        break
    }
    'version' {
        $versionFile = Join-Path $script:RootDir 'VERSION'
        $versionText = (Get-Content -LiteralPath $versionFile -Raw) -replace '[\r\n]', ''
        Write-Host $versionText
        break
    }
    { $_ -in @('help', '-h', '--help') } {
        Show-Usage
        break
    }
    default {
        Write-LabError ("Unknown command '{0}'. Run .\lab.ps1 help." -f $commandName)
    }
}

if ($commandExitCode -ne 0) {
    exit $commandExitCode
}
