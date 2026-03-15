<#
.SYNOPSIS
    Cleans up OSDCloud deployment leftovers, enables OEM Product Key, enables BitLocker and downloads CMTrace to the system for easy log viewing.
.DESCRIPTION
    This script is automatically downloaded in combination with the TenantSelectorAutopilotHashUpload.ps1 script during the WinPE phase of OSDCloud deployment.
    It is designed to be executed before the OOBE phase of Windows setup, and performs several post-deployment configuration tasks to ensure the device is properly set up and secured before the user starts using it.
 
    It performs the following functions:
        1. Cleans up OSDCloud leftovers and copies all logs to the Intune Management Extension log folder for easier troubleshooting.
        2. Enables the OEM Product Key if available.
        3. Enables BitLocker on all internal drives with TPM and XTS-AES 256 encryption.
        4. Downloads CMTrace to the system for easy log viewing.
.NOTES
    File Name: SetupComplete.ps1
    Author: https://github.com/MEMthusiast
#>

# Transcript log file name with timestamp

    $Global:Transcript = "$((Get-Date).ToString('yyyy-MM-dd-HHmmss'))-StartupComplete-Script.log"
    Start-Transcript -Path (Join-Path "$env:ProgramData\Microsoft\IntuneManagementExtension\Logs\OSD\" $Global:Transcript) -ErrorAction Ignore

#region cleanup OSDCloud

    Write-Host "Cleaning up OSDCloud leftovers"

    # Copying OSDCloud Logs
    If (Test-Path -Path 'C:\OSDCloud\Logs') {
        Move-Item 'C:\OSDCloud\Logs\*.*' -Destination 'C:\ProgramData\Microsoft\IntuneManagementExtension\Logs\OSD' -Force

    If (Test-Path -Path 'C:\Windows\Temp\osdcloud-logs') {
        Get-ChildItem 'C:\Windows\Temp\osdcloud-logs' | Copy-Item -Destination 'C:\ProgramData\Microsoft\IntuneManagementExtension\Logs\OSD' -Force
    }
    
    If (Test-Path -Path 'C:\ProgramData\OSDeploy') {
        Get-ChildItem 'C:\ProgramData\OSDeploy' | Copy-Item -Destination 'C:\ProgramData\Microsoft\IntuneManagementExtension\Logs\OSD' -Force
    }

    If (Test-Path -Path 'C:\Temp') {
        Get-ChildItem 'C:\Temp' -Filter *OOBE* | Copy-Item -Destination 'C:\ProgramData\Microsoft\IntuneManagementExtension\Logs\OSD' -Force
        Get-ChildItem 'C:\Windows\Temp' -Filter *Events* | Copy-Item -Destination 'C:\ProgramData\Microsoft\IntuneManagementExtension\Logs\OSD' -Force
        Get-ChildItem 'C:\Windows\Temp' -Filter *OOBE* | Copy-Item -Destination 'C:\ProgramData\Microsoft\IntuneManagementExtension\Logs\OSD' -Force
    }

    # Cleanup directories
    If (Test-Path -Path 'C:\OSDCloud') { Remove-Item -Path 'C:\OSDCloud' -Recurse -Force }
    If (Test-Path -Path 'C:\Drivers') { Remove-Item 'C:\Drivers' -Recurse -Force }
    If (Test-Path -Path 'C:\Intel') { Remove-Item 'C:\Intel' -Recurse -Force }
    If (Test-Path -Path 'C:\ProgramData\OSDeploy') { Remove-Item 'C:\ProgramData\OSDeploy' -Recurse -Force }

    # Cleanup Scripts
    Remove-Item C:\Windows\Setup\Scripts\*.* -Exclude *.TAG -Force | Out-Null

#endregion cleanup OSDCloud

#region Enable WIndows Product Key

    Write-Host "Enabling OEM Product Key"

    $key = (Get-CimInstance SoftwareLicensingService).OA3xOriginalProductKey; if ($key) { Write-Host "Installing $key"; changepk.exe /ProductKey $key } else { Write-Host "No key present" }

#endregion Enable WIndows Product Key

#region Enable BitLocker

    Write-Host "Enabling BitLocker"

    # Get driveletters from Internaldrives
    $disks = Get-Disk | Where-Object -FilterScript {$_.Bustype -ne "USB"}
    $driveletters = @()

    foreach ($disk in $disks)  {
        $partitions = Get-Partition -DiskNumber $disk.Number

        foreach ($partition in $partitions) {

            if ($($partition.DriveLetter)) {
                $driveletters += "$($partition.DriveLetter)"
                }
        }
    }

    # Check if TPM chip is available
    $TPM = Get-TPM

    If ($TPM.TpmPresent -like "False"){
            Write-Host -Message "No TPM-chip detected"
            Exit 1
        }

    ForEach ($DriveLetter in $DriveLetters) {
        $DriveLetter2 = "$DriveLetter"+":"
        $BitlockerStatus = Get-BitLockerVolume -MountPoint $DriveLetter
        
        If ($BitlockerStatus.ProtectionStatus -like "*off*" -or $BitlockerStatus.EncryptionMethod -ne "XtsAes256")  {
            # Set registery keys to newest encryption method
            $Key = "HKLM:\SOFTWARE\Policies\Microsoft\FVE"

            # Ensure the registry key exists
            if (!(Test-Path $Key)) {
                New-Item -Path $Key -Force | Out-Null
            }

            New-ItemProperty -Path $Key -Name "EncryptionMethod" -PropertyType DWord -Value 7 -Force | Out-Null
            New-ItemProperty -Path $Key -Name "EncryptionMethodWithXtsOs" -PropertyType DWord -Value 7 -Force | Out-Null
            New-ItemProperty -Path $Key -Name "EncryptionMethodWithXtsFdv" -PropertyType DWord -Value 7 -Force | Out-Null
            
            #Disable bitlocker if not decrypted
            if ($BitlockerStatus.VolumeStatus -ne "FullyDecrypted"){
                try {
                    Clear-BitLockerAutoUnlock
                    Disable-Bitlocker -MountPoint $DriveLetter
                }
                catch{Write-Host -Message "Error disabling bitlocker"}
            }
            
            # Wait until decryption is complete
            $DecryptionComplete = $false
            while (-not $DecryptionComplete) {
                Start-Sleep -Seconds 10
                $BitlockerStatus = Get-BitLockerVolume -MountPoint $DriveLetter
                if ($BitlockerStatus.VolumeStatus -eq "FullyDecrypted") {
                    $DecryptionComplete = $true
                }
                # View process in log
                Write-Host -Message "DecryptionPercentage $($BitlockerStatus.EncryptionPercentage)"
            }
            
            # Add TPM chip for autounlock OS-disk
            if ($BitlockerStatus.VolumeType -eq "OperatingSystem"){
                try {Add-BitLockerKeyProtector -MountPoint $DriveLetter -TpmProtector}
                catch {Write-Host -Message "Error TPM add to OperatingSystem drive"}
            }

            # Encrypt disk
            try {Enable-Bitlocker -MountPoint $DriveLetter -SkipHardwareTest -RecoveryPasswordProtector}
            catch {Write-Host -Message "Error enabling bitlocker"}

            # Wait until encryption status 100%
            $EncryptionComplete = $false
            $maxRetries = 60
            $retryCount = 0
            while (-not $EncryptionComplete -and $retryCount -lt $maxRetries) {
                Start-Sleep -Seconds 10
                $BitlockerStatus = Get-BitLockerVolume -MountPoint $DriveLetter
                if (($BitlockerStatus.EncryptionPercentage -eq 100) -and ($BitlockerStatus.VolumeStatus -eq "FullyEncrypted")) {
                    $EncryptionComplete = $true
                }
                # view process in log
                Write-Host -Message "EncryptionPercentage $($BitlockerStatus.EncryptionPercentage)"
            }
                $retryCount++
            }

            # Check if device is Entra ID or Hybrid Entra ID joined
                $dsreg = dsregcmd /status | Out-String

                $IsEntraJoined = $false
                if ($dsreg -match "AzureAdJoined\s*:\s*YES" -or ($dsreg -match "DomainJoined\s*:\s*YES" -and $dsreg -match "AzureAdPrt\s*:\s*YES")) {
                    $IsEntraJoined = $true
                }
                if ($IsEntraJoined) {
                    Write-Host "Entra ID join detected, running BitLocker key backup"

                    # Get BitLocker status for the drive
                    $DriveLetter = "C:"  # Adjust if needed
                    $BitlockerStatus = Get-BitLockerVolume -MountPoint $DriveLetter

                    # Find RecoveryPassword protector explicitly
                    $RecoveryKey = $BitlockerStatus.KeyProtector | Where-Object { $_.KeyProtectorType -eq "RecoveryPassword" }

                    if ($RecoveryKey) {
                        try {
                            BackupToAAD-BitLockerKeyProtector -MountPoint $DriveLetter -KeyProtectorId $RecoveryKey.KeyProtectorId
                            Write-Host "BitLocker key successfully backed up to Entra ID"
                        }
                        catch {
                            Write-Host "Error backing up BitLocker key to Entra ID: $_"
                        }
                    }
                    else {
                        Write-Host "No Recovery Password protector found on drive $DriveLetter"
                    }
                }
                else {
                    Write-Host "Device not joined to Entra ID, skipping BitLocker key backup"
                }
                
            # Resume and enable bitlocker
            try {Resume-BitLocker -MountPoint $DriveLetter}
            catch {Write-Host -Message "error resuming bitlocker"}

            # Autounlock bitlocker Data-drives
            If ($BitlockerStatus.VolumeType -ne "OperatingSystem")  {
                try {Enable-BitLockerAutoUnlock -MountPoint $DriveLetter}
                catch {Write-Host -Message "Error autounlock"}
            }
        }
        Else  {
            Write-Host -Message "Bitlocker already enabled $($DriveLetter)"
        }
    }

    if (Test-Path "C:\Program Files (x86)\Microsoft Intune Management Extension\Microsoft.Management.Services.IntuneWindowsAgent.exe") {
        Start-Process -FilePath "C:\Program Files (x86)\Microsoft Intune Management Extension\Microsoft.Management.Services.IntuneWindowsAgent.exe" -ArgumentList "intunemanagementextension://synccompliance"
    }
    
#endregion Enable Bitlocker

#region Download CMTrace

    Write-Host "Downloading CMTrace..."

    $Url               = "https://github.com/MEMthusiast/Intune-Autopilot-MultiTenant/raw/refs/heads/main/SetupComplete/cmtrace.exe"
    $DestinationFolder = "C:\Windows\System32"

    try {
        # Ensure TLS 1.2+
        [Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12

        # Extract filename and construct destination path
        $FileName        = Split-Path -Path $Url -Leaf
        $DestinationFile = Join-Path -Path $DestinationFolder -ChildPath $FileName

        # Download only if file doesn't already exist
        if (-not (Test-Path -Path $DestinationFile)) {

            Invoke-WebRequest -Uri $Url -OutFile $DestinationFile -UseBasicParsing -ErrorAction Stop

            Write-Host "CMTrace downloaded successfully to $DestinationFile"
        }
        else {
            Write-Host "CMTrace already exists at $DestinationFile"
        }

    }
    catch {
        Write-Error "Failed to download CMTrace: $($_.Exception.Message)"
    }

#endregion Download CMTrace

Stop-Transcript