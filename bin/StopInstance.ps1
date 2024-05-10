<#:::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
:: Program	: StopInstance.ps1
:: Title	: SAP System Shutdown (Power shell)
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

#::::::::::::::::::::::::::::::::::::::::
# Execute SAP Instance Shutdown
#::::::::::::::::::::::::::::::::::::::::
$nowfmt = Get-Date -Format "yyyy/MM/dd HH:mm:ss.ff"
Write-Host "[$nowfmt] SAP All Instance Stop. `r`n"

foreach($Instance in $SAPConfig.Configuration.SAP.SID) {
    foreach($saphost in $Instance.host) {
        $nowfmt = Get-Date -Format "yyyy/MM/dd HH:mm:ss.ff"
        Write-Host "[$nowfmt]" $Instance.name $saphost.name $saphost.nr " Instance Stop.`r`n"
        If ($saphost.user) {
            $importSecureString = $saphost.encryptedpass | ConvertTo-SecureString -key $($saphost.encryptedkey).split(",")
            $bstr = [System.Runtime.InteropServices.Marshal]::SecureStringToBSTR($importSecureString)
            $PlainPassword = [System.Runtime.InteropServices.Marshal]::PtrToStringBSTR($bstr)
            $sapctrlparam = "-host " + $saphost.name + " -nr " + $saphost.nr + " -user " + $saphost.user + " """ + $PlainPassword  + """ -function StopWait " + $saphost.timeout + " " + $saphost.delay
        } else {
            $sapctrlparam = "-prot PIPE -host " + $saphost.name + " -nr " + $saphost.nr + " -function StopWait " + $saphost.timeout + " " + $saphost.delay
        }
        $result = Start-Process -FilePath "sapcontrol.exe" -ArgumentList $sapctrlparam -PassThru -Wait
        if ($result.ExitCode -ne 0) {
            $nowfmt = Get-Date -Format "yyyy/MM/dd HH:mm:ss.ff"
            Write-Host "[$nowfmt]" $Instance.name $saphost.name $saphost.nr " Stop Error. `r`n"
            exit 1
        }
    }
    Start-Sleep 5
}
$nowfmt = Get-Date -Format "yyyy/MM/dd HH:mm:ss.ff"
Write-Host "[$nowfmt] All SAP Instance Stop Completed!! `r`n"

#::::::::::::::::::::::::::::::
# Execute Services Stop
#::::::::::::::::::::::::::::::
foreach($HostInfo in $SAPConfig.Configuration.Services.Host) {
    $Hostname = $HostInfo.name
    foreach($Service in $HostInfo.service) {
        $nowfmt = Get-Date -Format "yyyy/MM/dd HH:mm:ss.ff"
        Write-Host "[$nowfmt]" $Hostname $Service.name "Stopping. `r`n"
        $rc = (ServiceControl $Hostname $Service.name "STOP")
        if ($rc -ne 0) {
            $nowfmt = Get-Date -Format "yyyy/MM/dd HH:mm:ss.ff"
            Write-Host "[$nowfmt]" $Hostname $Service.name "Stop Error.`r`n"
            exit 1
        }
        Start-Sleep $Service.delay
    }
}

#::::::::::::::::::::::::::::::::::::
# Execute ClusterServices Stop
#::::::::::::::::::::::::::::::::::::
$Hostname = $SAPConfig.Configuration.ClusterServices.Name
if ($Hostname -ne "") { 
    foreach($Resource in $SAPConfig.Configuration.ClusterServices.resource) {
        $nowfmt = Get-Date -Format "yyyy/MM/dd HH:mm:ss.ff"
        Write-Host "[$nowfmt]" $Hostname $Resource.name "Stopping. `r`n"
        $Resourcename = [String] $Resource.name
        try {
            Stop-ClusterResource -Cluster $Hostname -Name "$Resourcename"
        } catch [Exception] {
            $nowfmt = Get-Date -Format "yyyy/MM/dd HH:mm:ss.ff"
            Write-Host "[$nowfmt]" $Hostname $Resource.name "Stop Error. `r`n"
            Exit 1
        }
        Start-Sleep $Resource.delay
    }
}

#::::::::::::::::::::::::::::::
# Post setting
#::::::::::::::::::::::::::::::
$nowfmt = Get-Date -Format "yyyy/MM/dd HH:mm:ss.ff"
Write-Host "[$nowfmt] SAP System Stopped. `r`n"

Exit 0
