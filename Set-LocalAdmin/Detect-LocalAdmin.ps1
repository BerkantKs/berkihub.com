
#Get the UPN of the user that enrolled the computer to AAD
$AADInfoPath = "HKLM:/SYSTEM/CurrentControlSet/Control/CloudDomainJoin/JoinInfo"
$AADInfo = Get-Item $AADInfoPath
$guid = ($AADInfo | Get-ChildItem | Where-Object { $_.Property -contains "UserEmail" }).PSChildName
$UPN = (Get-Item "$AADInfoPath/$guid").GetValue("UserEmail")

$localAdminsPath = "HKLM:\Software\IntuneManaged\LocalAdmins"
$LocalAdminExists = (Get-ItemProperty $localAdminsPath)."$UPN"

if($LocalAdminExists -eq "1"){
    Write-Host "Local Admin already added."
}else{
    Exit 1
}