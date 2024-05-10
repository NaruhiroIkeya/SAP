<#:::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
:: Program	: Get-SecurePassword.ps1
:: Title	: Create Encription Key and Secure Password
::
:: ReturnCode	: 0=Success, Other=Error
:: Purpose	: Create Encription Key and Secure Password
::
:: Version	: v01
:: Author	: Naruhiro Ikeya
:: CreationDate	: 10/08/2023
::
:: Copyright (c) 2023 BeeX Inc. All rights reserved.
:::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::#>
Param([parameter(mandatory=$true)] [string] $PlainPassword)


$EncryptedKey = New-Object Byte[] 24

[Security.Cryptography.RNGCryptoServiceProvider]::Create().GetBytes($EncryptedKey)
$KeyString = $EncryptedKey -join ","


$SecureString = ConvertTo-SecureString -String $PlainPassword -AsPlainText -Force
$EncryptedPassword = ConvertFrom-SecureString -SecureString $SecureString -key $EncryptedKey

Write-Host "If your password string contains special characters, please escape them with backquote (``). ex.) `$`,`&```"`'"
Write-host "<encryptedkey>$KeyString </encryptedkey>"
Write-host "<encryptedpass>$EncryptedPassword</encryptedpass>"
