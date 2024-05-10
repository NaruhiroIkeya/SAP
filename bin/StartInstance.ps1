<#:::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
:: Program	: StartInstance.ps1
:: Title	: SAP System Startup (Power shell)
::
:: Argument	: 1. XML Configuration file
:: ReturnCode	: 0=Success, Other=Error
:: Purpose	: Perform SAP System Startup.
::
:: Version	: v01
:: Author	: Naruhiro Ikeya
:: CreationDate	: 10/08/2023
::
:: Copyright (c) 2023 BeeX Inc. All rights reserved.
:::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::#>
#::::::::::::::::::::::::::::::
# Initial setting
#::::::::::::::::::::::::::::::
$ErrorActionPreference = "Stop"
$scriptPath = [System.IO.Path]::GetDirectoryName($myInvocation.MyCommand.Definition)
$SAPConfig = [xml](Get-Content $Args[1])
. "$scriptPath\ServiceControl.ps1"

#::::::::::::::::::::::::::::::
# Execute Services Start
#::::::::::::::::::::::::::::::
$Hosts = $SAPConfig.Configuration.Services.Host
foreach($HostInfo in $Hosts) {
    $Hostname = $HostInfo.name
    foreach($Service in $HostInfo.service) {
        $nowfmt = Get-Date -Format "yyyy/MM/dd HH:mm:ss.ff"
        Write-Host "[$nowfmt]" $Hostname $Service.name "Start. `r`n"
        $rc = (ServiceControl $Hostname $Service.name "START")
        if ($rc -ne 0) {
            $nowfmt = Get-Date -Format "yyyy/MM/dd HH:mm:ss.ff"
            Write-Host "[$nowfmt]" $Hostname $Service.name "Start Error. `r`n"
            Exit 1
        }
        Start-Sleep $Service.delay
    }
}

#::::::::::::::::::::::::::::::::::::
# Execute ClusterServices Start
#::::::::::::::::::::::::::::::::::::
$Hostname = $SAPConfig.Configuration.ClusterServices.Name
if ($Hostname -ne "") {
    foreach($Resource in $SAPConfig.Configuration.ClusterServices.resource) {
        $nowfmt = Get-Date -Format "yyyy/MM/dd HH:mm:ss.ff"
        Write-Host "[$nowfmt]" $Hostname $Resource.name "Start. `r`n"
        $Resourcename = [String] $Resource.name
        try {
            Start-ClusterResource -Cluster $Hostname -Name "$Resourcename"
        } catch [Exception] {
            $nowfmt = Get-Date -Format "yyyy/MM/dd HH:mm:ss.ff"
            Write-Host "[$nowfmt]" $Hostname $Resource.name "Start Error. `r`n"
            Exit 1
        }
        Start-Sleep $Resource.delay
    }
}
$nowfmt = Get-Date -Format "yyyy/MM/dd HH:mm:ss.ff"
Write-Host "[$nowfmt] All Services Started.`r`n"

#::::::::::::::::::::::::::::::::::::
# Execute SAP Instance Start
#::::::::::::::::::::::::::::::::::::
$nowfmt = Get-Date -Format "yyyy/MM/dd HH:mm:ss.ff"
Write-Host "[$nowfmt] SAP Instance Start. `r`n"
foreach($Instance in $SAPConfig.Configuration.SAP.SID) {
    foreach($saphost in $Instance.host) {
        $nowfmt = Get-Date -Format "yyyy/MM/dd HH:mm:ss.ff"
        Write-Host "[$nowfmt]" $Instance.name $saphost.name $saphost.nr "Instance Start. `r`n"
        If ($saphost.user) {
            $importSecureString = $saphost.encryptedpass | ConvertTo-SecureString -key $($saphost.encryptedkey).split(",")
            $bstr = [System.Runtime.InteropServices.Marshal]::SecureStringToBSTR($importSecureString)
            $PlainPassword = [System.Runtime.InteropServices.Marshal]::PtrToStringBSTR($bstr)
            $sapctrlparam = "-host " + $saphost.name + " -nr " + $saphost.nr + " -user " + $saphost.user + " """ + $PlainPassword  + """ -function StartWait " + $saphost.timeout + " " + $saphost.delay
        } else {
            $sapctrlparam = "-prot PIPE -host " + $saphost.name + " -nr " + $saphost.nr + " -function StartWait " + $saphost.timeout + " " + $saphost.delay
        }
        $result = Start-Process -FilePath "sapcontrol.exe" -ArgumentList $sapctrlparam -PassThru -Wait
        if ($result.ExitCode -ne 0) {
            $nowfmt = Get-Date -Format "yyyy/MM/dd HH:mm:ss.ff"
            Write-Host "[$nowfmt]" $Instance.name $saphost.name $saphost.nr "Start Error. `r`n"
            Exit 1
        }
    }
    Start-Sleep 5
}

#::::::::::::::::::::::::::::::
# Post setting
#::::::::::::::::::::::::::::::
$nowfmt = Get-Date -Format "yyyy/MM/dd HH:mm:ss.ff"
Write-Host "[$nowfmt] SAP System Started. `r`n"

Exit 0
