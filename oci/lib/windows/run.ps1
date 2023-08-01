param(
    [Parameter(Mandatory,HelpMessage='podman version to be tested')]
    $podmanVersion,
    [Parameter(Mandatory,HelpMessage='folder on target host where assets are copied')]
    $targetFolder,
    [Parameter(Mandatory,HelpMessage='junit results filename')]
    $junitResultsFilename,
    [Parameter(HelpMessage='pullsecret filename at target folder')]
    $pullsecretFilename,
    [Parameter(HelpMessage='backend for podman. podman, crc-podman, crc-microshift or crc-openshift')]
    $backend="podman",
    [Parameter(HelpMessage='Check if podman backend should be installed, default false.')]
    $podmanInstall="false",
    [Parameter(HelpMessage='Check if podman machine should be started, default false.')]
    $podmanStart="false"
)

function Backend-CRC-Podman {
   crc config set preset podman
   crc setup
   crc start
   # SSH expands a terminal but due to how crc recognized the shell 
   # it does not recognize powershell but other process so we force it
   $env:SHELL="powershell"
   & crc podman-env | Invoke-Expression
}

function Backend-CRC-Microshift {
    crc config set preset microshift
    crc setup
    crc start -p $targetFolder/$pullsecretFilename
    # SSH expands a terminal but due to how crc recognized the shell 
    # it does not recognize powershell but other process so we force it
    $env:SHELL="powershell"
    & crc podman-env | Invoke-Expression
 }

 function Backend-CRC-Openshift {
    crc config set preset openshift
    crc setup
    crc start -p $targetFolder/$pullsecretFilename
    # SSH expands a terminal but due to how crc recognized the shell 
    # it does not recognize powershell but other process so we force it
    $env:SHELL="powershell"
    & crc podman-env | Invoke-Expression
 }

function Backend-Podman {
    # Force install just in case
    wsl -l -v
    $installed=$?

    if (!$installed) {
        Write-Host "installing wsl2"
        wsl --install  
    }

    # Install podman
    if ( $podmanInstall -match 'true' )
    {
        curl -LO "https://github.com/containers/podman/releases/download/v$podmanVersion/podman-v$podmanVersion.msi"
        Start-Process C:\Windows\System32\msiexec.exe -ArgumentList "/qb /i podman-v$podmanVersion.msi /norestart" -wait
        $env:PATH="$env:PATH;C:\Program Files\RedHat\Podman"
    }

    if ( $podmanStart -match 'true' )
    {
        # Start podman machine
        podman machine init
        podman machine start
    }
}

function CleanUp-Backend-Podman {
    podman machine stop
    podman machine rm -f

    wsl --unregister podman-machine-default
}

function CleanUp-Backend-CRC {
    crc stop
    crc cleanup
}

switch ($backend)
{
    "podman" {
        Backend-Podman
    }
    "crc-podman" {
        Backend-CRC-Podman
    }
    "crc-microshift" {
        Backend-CRC-Microshift
    }
    "crc-openshift" {
        Backend-CRC-Openshift
    }
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

# Cleanup backend
switch ($backend)
{
    "podman" {
        CleanUp-Backend-Podman
    }
    "crc-podman" {
        CleanUp-Backend-CRC
    }
    "crc-microshift" {
        CleanUp-Backend-CRC
    }
    "crc-openshift" {
        CleanUp-Backend-CRC
    }
}