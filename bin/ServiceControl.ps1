<#:::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
:: Program	: ServiceControl.ps1
:: Title	: Service Start / Stop Function (Power shell)
::
:: Argument	: 1. Hostname
:: 		  2. Services name
:: 		  3. Start or Stop mode
:: ReturnCode	: 0=Success, Other=Error
:: Purpose	: Perform start or stop services of windows server.
::
:: Version	: v01
:: Author	: Naruhiro Ikeya
:: CreationDate	: 10/08/2023
::
:: Copyright (c) 2023 BeeX Inc. All rights reserved.
:::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::#>
function ServiceControl($server, $service, $mode) {

    #::::::::::::::::::::::::::::::
    # Initial setting
    #::::::::::::::::::::::::::::::
    $cntr = 0

    #::::::::::::::::::::::::::::::
    # Server connection check
    #::::::::::::::::::::::::::::::
    if (Test-Connection $server -quiet) {
        do {
            #::::::::::::::::::::::::::::::
            # Get Services information
            #::::::::::::::::::::::::::::::
            $result = Get-Service $service -ComputerName $server -ErrorVariable getServiceError -ErrorAction SilentlyContinue
            if ($getServiceError -and ($getServiceError | foreach {$_.FullyQualifiedErrorId -like "*NoServiceFoundForGivenName*"})) {
                $nowfmt = Get-Date -Format "yyyy/MM/dd HH:mm:ss.ff"
                Write-Host "[$nowfmt] $server $service not found.`r`n"
                return 9
            }
            #::::::::::::::::::::::::::::::
            # Start mode execute
            #::::::::::::::::::::::::::::::
            if (($mode -match "START") -or ($mode -match "start")) {
                $status = "Running", "Started"
                if ($result.Status -eq "Stopped") {
                    $rc = (Get-WmiObject -computer $server Win32_Service -Filter "Name='$service'").InvokeMethod("StartService",$null)
                    if ($rc -ne 0) {
                        $message = $service + " Service not " + $status[1] + ".`r`n"
                        $message = $message + "RC=" + $rc
                        $nowfmt = Get-Date -Format "yyyy/MM/dd HH:mm:ss.ff"
                        Write-Host "[$nowfmt] $server $message`r`n"
                        return $rc
                    }
                    Start-Sleep 5
                }
            #::::::::::::::::::::::::::::::
            # Stop mode execute
            #::::::::::::::::::::::::::::::
            } elseif (($mode -match "STOP") -or ($mode -match "stop")) {
                $status = "Stopped", "Stopped"
                if ($result.Status -eq "Running") {
                    $rc = (Get-WmiObject -computer $server Win32_Service -Filter "Name='$service'").InvokeMethod("StopService",$null)
                    if ($rc -ne 0) {
                        $message = $service + " Service not " + $status[1] + ".`r`n"
                        $message = $message + "RC=" + $rc
                        $nowfmt = Get-Date -Format "yyyy/MM/dd HH:mm:ss.ff"
                        Write-Host "[$nowfmt] $server $message`r`n"
                        return $rc
                    }
                    Start-Sleep 5
                }
            #::::::::::::::::::::::::::::::
            # Execute mode unknown
            #::::::::::::::::::::::::::::::
            } else {
                return 2
            }
            $result = Get-Service $service -ComputerName $server
            $cntr++
            #::::::::::::::::::::::::::::::
            # 20 times retry check
            #::::::::::::::::::::::::::::::
            if ($cntr -gt 20) { 
                $message = $service + " Service not" + $status[1] + ".`r`n"
                $nowfmt = Get-Date -Format "yyyy/MM/dd HH:mm:ss.ff"
                Write-Host "[$nowfmt] $server $message`r`n"
                return 3
            } else { 
                $message = $service + " Service Processing..."
                $nowfmt = Get-Date -Format "yyyy/MM/dd HH:mm:ss.ff"
                Write-Host "[$nowfmt] $server $message`r`n"
                Start-Sleep 5
            }
        } while ($result.Status -ne $status[0])
    #::::::::::::::::::::::::::::::
    # Server unknown
    #::::::::::::::::::::::::::::::
    } else { return 1 } 

    #::::::::::::::::::::::::::::::
    # Post setting
    #::::::::::::::::::::::::::::::
    $message = $service + " Service " + $status[1] + ".`r`n"
    $nowfmt = Get-Date -Format "yyyy/MM/dd HH:mm:ss.ff"
    Write-Host "[$nowfmt] $server $message"

    return 0
}