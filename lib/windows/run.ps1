param(
    [Parameter(Mandatory,HelpMessage='podman version to be tested')]
    $podmanVersion,
    [Parameter(Mandatory,HelpMessage='folder on target host where assets are copied')]
    $targetFolder,
    [Parameter(Mandatory,HelpMessage='junit results filename')]
    $junitResultsFilename,
    [Parameter(HelpMessage='backed for podman. crc or podman-machine')]
    $backend="podman-machine"
)

function Backend-CRC {
   crc config set preset podman
   crc setup
   crc start
   # SSH expands a terminal but due to how crc recognized the shell 
   # it does not recognize powershell but other process so we force it
   $env:SHELL="powershell"
   & crc podman-env | Invoke-Expression
}

function Backend-Podman-Machine {
   # Install podman machine
    wsl --install

    # Install podman
    curl -LO "https://github.com/containers/podman/releases/download/v$podmanVersion/podman-v$podmanVersion.msi"
    Start-Process C:\Windows\System32\msiexec.exe -ArgumentList "/qb /i podman-v$podmanVersion.msi /norestart" -wait
    $env:PATH="$env:PATH;C:\Program Files\RedHat\Podman"

    # Start podman machine
    podman machine init
    podman machine start
}

# Setup backend
If ($backend -eq 'crc') 
{
    Backend-CRC
} Else {
    Backend-Podman-Machine
}

# Prepare run e2e
mv $targetFolder/podman-backend-e2e $targetFolder/podman-backend-e2e.exe
$env:PODMAN_BINARY="podman"
mkdir $targetFolder/tmp
$env:TMPDIR="$env:HOME\$targetFolder/tmp"
$env:E2E_JUNIT_OUTPUTFILE="$targetFolder/$junitResultsFilename"

# Run e2e
$env:PATH="$env:PATH;$env:HOME\$targetFolder;"
podman-backend-e2e.exe