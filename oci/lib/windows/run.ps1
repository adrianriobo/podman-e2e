param(
    [Parameter(HelpMessage='podman version to be tested in case we want to install it')]
    $podmanVersion="",
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
    $podmanStart="false",
    [Parameter(HelpMessage='Passing possible options for the podman machine init (i.e --rootful --user-mode-networking). default empty')]
    $podmanOpts="",
    [Parameter(HelpMessage='Set the podman machine provider (wsl or hyperv)), default wsl ')]
    $podmanProvider="wsl",
    [Parameter(HelpMessage='Check if wsl is installed if not it will install, default false.')]
    $wslInstallFix="false",
    [Parameter(HelpMessage=' If enable it will run node exporter insde the guest machine, default false.')]
    $monitoringEnable="false"
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
    if ( $wslInstallFix -match 'true' )
    {
        wsl -l -v
        $installed=$?

        if (!$installed) {
            Write-Host "installing wsl2"
            wsl --install 
        }
    }
   
    # Install podman
    if ( $podmanInstall -match 'true' )
    {
        cd $targetFolder
        curl -LO "https://github.com/containers/podman/releases/download/v$podmanVersion/podman-v$podmanVersion.msi"
        Start-Process C:\Windows\System32\msiexec.exe -ArgumentList "/qb /i podman-v$podmanVersion.msi /norestart" -wait
        $env:PATH="$env:PATH;C:\Program Files\RedHat\Podman"
        cd ..
    }

    if ( $podmanStart -match 'true' )
    {
        # Start podman machine
        set CONTAINERS_MACHINE_PROVIDER=$podmanProvider
        podman machine init $podmanOpts
        podman machine start

        if ( $monitoringEnable -match 'true' )
        {
            # Enable monitoring on target host
            # https://github.com/prometheus-community/windows_exporter

            # Enable monitoring on guest machine
            podman machine ssh 'curl -LO https://github.com/prometheus/node_exporter/releases/download/v1.7.0/node_exporter-1.7.0.linux-amd64.tar.gz'
            podman machine ssh 'tar -xzvf node_exporter-1.7.0.linux-amd64.tar.gz --strip-components 1'
            # https://github.com/prometheus/node_exporter?tab=readme-ov-file#perf-collector
            podman machine ssh 'sudo sysctl -w kernel.perf_event_paranoid=0'
            podman machine ssh 'nohup ./node_exporter --web.listen-address=:52200 > nohup.out 2> nohup.err < /dev/null &'
            # https://github.com/containers/gvisor-tap-vsock?tab=readme-ov-file#port-forwarding
            podman machine ssh "curl gateway.containers.internal/services/forwarder/expose -X POST -d '{\"local\":\":52200\",\"remote\":\"192.168.127.2:52200\"}'"
        }
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
# $env:E2E_JUNIT_OUTPUTFILE="$targetFolder/$junitResultsFilename"

# Run e2e
$env:PATH="$env:PATH;$env:HOME\$targetFolder;"
podman-backend-e2e.exe --ginkgo.vv --ginkgo.junit-report="$targetFolder/$junitResultsFilename"

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