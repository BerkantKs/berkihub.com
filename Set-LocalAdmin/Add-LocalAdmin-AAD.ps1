#restart script in 64 bit environment
If (!([Environment]::Is64BitProcess)) {
    if ([Environment]::Is64BitOperatingSystem) {
        Write-Output "Running 32 bit Powershell on 64 bit OS, restarting as 64 bit process..."
        $arguments = "-NoProfile -ExecutionPolicy ByPass -WindowStyle Hidden -File `"" + $myinvocation.mycommand.definition + "`""
        $path = (Join-Path $Env:SystemRoot -ChildPath "\sysnative\WindowsPowerShell\v1.0\powershell.exe")
        Start-Process $path -ArgumentList $arguments -wait
        Write-Output "finished x64 version of PS"
        Exit
    }
    else {
        Write-Output "Running 32 bit Powershell on 32 bit OS"
    }
}
$ErrorActionPreference = "Stop"

function LogMessage([string]$message) {
    $message = "$([DateTime]::Now) - $message"
    Write-Host $message
    $message | Out-File -FilePath $env:TEMP\LocalAdmin.log
}

# Script to make the user which enrolled the device to AAD a local admin
try {

    #Get local Administrators group
    $LocalAdminGroup = Get-LocalGroup -SID "S-1-5-32-544"
    $Localadmingroupname = $LocalAdminGroup.name

    #Get the UPN of the user who enrolled the computer to AAD
    $AADInfoPath = "HKLM:/SYSTEM/CurrentControlSet/Control/CloudDomainJoin/JoinInfo"
    $AADInfo = Get-Item $AADInfoPath
    $guid = ($AADInfo | Get-ChildItem | Where-Object { $_.Property -contains "UserEmail" }).PSChildName
    $UPN = (Get-Item "$AADInfoPath/$guid").GetValue("UserEmail")

    if (-not $UPN) {
        throw "Failed to find enrolled User email in registry."
    }

    #localadmin path for detection
    $localAdminsPath = "HKLM:\Software\IntuneManaged\LocalAdmins"
    $LocalAdminExists = (Get-ItemProperty $localAdminsPath -EA 0)."$UPN"

    if (!($LocalAdminExists -eq "1")) {
        Add-LocalGroupMember -Group $Localadmingroupname -Member "Azuread\$UPN" -EA 0
        LogMessage "Added AzureAD\$UPN as local administrator."
        #add registry key for detection
        & REG add "HKLM\Software\IntuneManaged\LocalAdmins" /v "$UPN" /t REG_DWORD /d 1 /f /reg:64 | Out-Null
    }
    else {
        LogMessage "AzureAD\$UPN is already a local administrator."
    }
}
catch {
    $errorMessage = $_.Exception.Message
    LogMessage "Error - $errorMessage"
}