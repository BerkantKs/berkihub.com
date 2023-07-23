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

function LogMessage([string]$message){
    $message = "$([DateTime]::Now) - $message"
    Write-Host $message
    $message | Out-File -FilePath $env:TEMP\LocalAdmin.log
}

#Script to remove the user which enrolled the device to AAD from local admin
try {
    $LocalAdminGroup = Get-LocalGroup -SID "S-1-5-32-544"
    $Localadmingroupname = $LocalAdminGroup.name

    #Get the UPN of the user that enrolled the computer to AAD
    $AADInfoPath = "HKLM:/SYSTEM/CurrentControlSet/Control/CloudDomainJoin/JoinInfo"
    $AADInfo = Get-Item $AADInfoPath
    $guid = ($AADInfo | Get-ChildItem | Where-Object { $_.Property -contains "UserEmail" }).PSChildName
    $UPN = (Get-Item "$AADInfoPath/$guid").GetValue("UserEmail")

    if (-not $UPN) {
        throw "Failed to find enrolled User email in registry."
    }

    # Detect if local admin needs to be removed
    $localAdminsPath = "HKLM:\Software\IntuneManaged\LocalAdmins"
    $LocalAdminExists = (Get-ItemProperty $localAdminsPath -EA 0)."$UPN"

    if ($LocalAdminExists -eq "1") {
        LogMessage "Removing AzureAD\$UPN as a local administrator."
        Remove-LocalGroupMember -Group $Localadmingroupname -member "Azuread\$UPN" -ErrorAction Stop
        LogMessage "Removed AzureAD\$UPN as a local administrator."
        Remove-ItemProperty -Path $localAdminsPath -Name $UPN -ErrorAction Stop
    }
    else {
        LogMessage "AzureAD\$UPN is already removed as a local administrator."
    }
}
catch {
    $errorMessage = $_.Exception.Message
    LogMessage "Error - $errorMessage"
}