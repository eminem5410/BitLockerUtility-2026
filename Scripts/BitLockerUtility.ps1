<#Carlos Martinez Date: 11/16/2019 GitHub @cmartinezone
Modernized by Pablo & AI - 2024
DESCRIPTION: Manipulate BitLocker from WinPE Enviroment
BitLockerUtility 3.1
#>

#Set the power scheme to high performance
powercfg /s 8c5e7fda-e8bf-4a96-9a85-a6e23a8c635c

function GetDrivesEncryption {
    [cmdletBinding()]
    Param(
        [Parameter(Mandatory = $false)]
        [ValidateSet("Locked", "Unlocked", "Off", "All")]
        [string]$Status = "All"
    )

    $BitLockerDrives = Get-CimInstance -Namespace "Root\cimv2\Security\MicrosoftVolumeEncryption" -ClassName "Win32_EncryptableVolume"
    $KeyProtectorType = 3 

    $Volumes = Get-Volume | Where-Object { $null -ne $_.DriveLetter -and $_.DriveType -ne 'CD-ROM' }

    $ListOfDrives = foreach ($Vol in $Volumes) {
        $BitLockerVol = $BitLockerDrives | Where-Object { $_.DriveLetter -eq "$($Vol.DriveLetter):" }

        $Encrypted        = 'False'
        $ProtectorStatus  = 'None'
        $EncryptionMethod = 'None'
        $RecoveryKeyID    = 'None'

        if ($BitLockerVol) {
            $Encrypted = $BitLockerVol.IsVolumeInitializedForProtection
            
            $ProtectorStatus = switch ($BitLockerVol.ProtectionStatus) {
                0 { 'Off' }
                1 { 'On (UnLocked)' }
                2 { 'On (Locked)' }
                default { 'Unknown' }
            }

            $EncryptionMethod = switch ($BitLockerVol.EncryptionMethod) {
                0 { 'None' }
                1 { 'AES 128 WITH DIFFUSER' }
                2 { 'AES 256 WITH DIFFUSER' }
                3 { 'AES 128' }
                4 { 'AES 256' }
                5 { 'Hardware Encryption' }
                6 { 'XTS-AES 128' }
                7 { 'XTS-AES 256' }
                default { 'Unknown' }
            }

            $RecoveryKeyID = ($BitLockerVol | Invoke-CimMethod -MethodName GetKeyProtectors -Arguments @{KeyProtectorType = $KeyProtectorType}).VolumeKeyProtectorID
        }

        [PSCustomObject]@{
            DriveLetter       = $Vol.DriveLetter
            FileSystemType    = $Vol.FileSystemType
            DriveType         = $Vol.DriveType
            HealthStatus      = $Vol.HealthStatus
            OperationalStatus = $Vol.OperationalStatus
            'Size / GB'       = if ($Vol.Size -gt 0) { [math]::truncate($Vol.Size / 1GB) } else { 'Unknown' }
            Encrypted         = $Encrypted
            ProtectorStatus   = $ProtectorStatus
            EncryptionMethod  = $EncryptionMethod
            RecoveryKeyID     = $RecoveryKeyID
        }
    }
   
    switch ($Status) {
        "Unlocked" { return $ListOfDrives | Where-Object { $_.Encrypted -eq $true -and $_.ProtectorStatus -ne 'On (Locked)' } }
        "Locked"   { return $ListOfDrives | Where-Object { $_.ProtectorStatus -eq 'On (Locked)' } }
        "Off"      { return $ListOfDrives | Where-Object { $_.Encrypted -eq $false } }
        default    { return $ListOfDrives }
    }
}

function UnLockDrive {
    $EncryptedDrives = GetDrivesEncryption -Status Locked | Sort-Object -Property DriveLetter
    
    if ($null -ne $EncryptedDrives) {
        if ($EncryptedDrives.Count -gt 1) { Clear-Host }

        Write-Host "`r`nLocked Drive Volumes Detected:" -ForegroundColor Yellow
        $EncryptedDrives | Format-List -GroupBy Encrypted 
        
        Write-Host "Enter the Drive Volume Letter to Unlock:" -ForegroundColor Black -BackgroundColor Yellow -NoNewline
        $EnterDriveLetter = Read-Host  

        # Validacion moderna con Regex: debe ser exactamente una letra A-Z
        if ($EnterDriveLetter -notmatch '^[a-zA-Z]$') {
            Write-Host "`r`nInvalid Drive Letter, Please try again.`r`n"  -ForegroundColor Red
            return
        }

        $GetDrive = $EncryptedDrives | Where-Object { $_.DriveLetter -eq $EnterDriveLetter.ToUpper() }
        
        if ($null -eq $GetDrive) {
            Write-Host "`r`nNo Drive Volume Letter Found, Please try again.`r`n"  -ForegroundColor Red
            return
        }

        Clear-Host
        Write-Host "`r`nDrive Volume selected: " -ForegroundColor Yellow
        $GetDrive
        Write-Host "Recovery Key Password IDs: "  -ForegroundColor Yellow -NoNewline
        Write-Host $GetDrive.RecoveryKeyID -ForegroundColor Green
        Write-Host "Enter the Recovery Key Password in the below format:" -ForegroundColor Yellow
        Write-Host "Recovery Key: XXXXXX-XXXXXX-XXXXXX-XXXXXX-XXXXXX-XXXXXX-XXXXXX-XXXXXX" -BackgroundColor Yellow -ForegroundColor Black
        $Key = Read-Host "Recovery Key" 
        $DriveLetter = $GetDrive.DriveLetter + ":"

        # Validacion moderna con Regex: 8 grupos de 6 numeros separados por guion
        if ($Key -notmatch '^(\d{6}-){7}\d{6}$') {
            Write-Host "`r`nThe Recovery Key Password format is not correct, Please try again. `r`n" -ForegroundColor Red
            return
        }

        $null = manage-bde -Unlock $DriveLetter -RecoveryPassword $Key
        
        if ($LASTEXITCODE -eq 0) {
            Write-Host "`r`nThe Recovery Password successfully unlocked volume: $DriveLetter `r`n" -ForegroundColor Green
        } else {
            Write-Host "`r`nFailed to unlock volume: $DriveLetter. Check the recovery key.`r`n" -ForegroundColor Red
        }
    }
    else {
        Write-Host "`r`nNo Encrypted and Locked drive detected" -ForegroundColor Yellow
        Write-Host "Please make sure the Drive is connected!`r`n" -ForegroundColor Yellow
    }
}

function TurnOffBitLockerAndSuspend {
    $UnlockDrives = GetDrivesEncryption -Status Unlocked | Sort-Object -Property DriveLetter 
    
    if ($null -ne $UnlockDrives) {
        if ($UnlockDrives.Count -gt 1) { Clear-Host }
        
        Write-Host "`r`nUnlocked Drive Volumes Detected:" -ForegroundColor Yellow
        $UnlockDrives | Format-List -GroupBy ProtectorStatus

        Write-Host "Enter the Drive Volume Letter:" -ForegroundColor Black -BackgroundColor Yellow -NoNewline
        $EnterDriveLetter = Read-Host 

        if ($EnterDriveLetter -notmatch '^[a-zA-Z]$') {
            Write-Host "`r`nInvalid Drive Letter, Please try again.`r`n" -ForegroundColor Red
            return
        }

        $GetDrive = $UnlockDrives | Where-Object { $_.DriveLetter -eq $EnterDriveLetter.ToUpper() }

        if ($null -eq $GetDrive) {
            Write-Host "`r`nNo Drive Volume Letter Found, Please try again.`r`n" -ForegroundColor Red
            return
        }

        Clear-Host
        Write-Host "`nDrive Volume selected: " -ForegroundColor Yellow
        $GetDrive
        $DriveLetter = $GetDrive.DriveLetter + ":"
        
        Write-Host "BitLocker Options:`r`n" -ForegroundColor Yellow
        Write-Host "  -> Press 1: Turn OFF"  -ForegroundColor Yellow 
        Write-Host "  -> Press 2: Suspend "  -ForegroundColor Yellow
        Write-Host "`r`nEnter one option:" -ForegroundColor Black -BackgroundColor Yellow -NoNewline
        $SelectOption = Read-Host 
          
        if ($SelectOption -eq "1") {
            $null = manage-bde -off $DriveLetter
            Write-Host "`r`nDecryption is now in progress. `r`n" -ForegroundColor Yellow
            
            do {
                Clear-Host
                Write-Host "`r`nDecryption in Progress... `r`n" -ForegroundColor Yellow
                $DecrypProgress = manage-bde -status $DriveLetter
                
                # Mostrar el estado completo de manage-bde en la consola
                $DecrypProgress | ForEach-Object { Write-Host $_ }
                
                if ($DecrypProgress -match "ERROR:") { 
                    Write-Host "`r`nDecryption Interrupted :(`r`n" -ForegroundColor Red
                    return
                }
                
                Start-Sleep 5 # 5 segundos de refresco para no saturar la CPU
            } until ($DecrypProgress -match "Fully Decrypted" -and $DecrypProgress -match "Percentage Encrypted: 0.0%")

            Write-Host "`r`nThe Drive Volume has been Fully Decrypted :)`r`n" -ForegroundColor Green
            pause
        }
        elseif ($SelectOption -eq "2") {
            $null = manage-bde -protectors -disable $DriveLetter
            if ($LASTEXITCODE -eq 0) {
                Write-Host "`r`nKey protectors are disabled for volume: $DriveLetter `r`n" -ForegroundColor Green
            } else {
                Write-Host "`r`nFailed to suspend BitLocker on volume: $DriveLetter `r`n" -ForegroundColor Red
            }
        } else {
            Write-Host "`r`nNo Option selected, Please try again..`r`n" -ForegroundColor Red
        }
    }
    else {
        Write-Host "`r`nNo Encrypted and Unlocked drive detected" -ForegroundColor Yellow
        Write-Host "Please UnLock the Drive first and try again!`r`n" -ForegroundColor Yellow
    }
}

Function Set-WindowSize {
    Param([int]$x=$host.ui.rawui.windowsize.width,
          [int]$y=$host.ui.rawui.windowsize.heigth)
        $size=New-Object System.Management.Automation.Host.Size($x,$y)
        $host.ui.rawui.WindowSize=$size   
}

###MAIN MENU 
function WindowsTile ( $title ) { $Host.UI.RawUI.WindowTitle = $title }
function MenuOption ($Option) {  
    Write-Host  "`t $Option "
    write-Host "--------------------------------------------------------"  -ForegroundColor yellow
}

function MainMenu {
    WindowsTile ("BitLockerUtility 3.1 - Modernized")
    $MenuTitle = 'BitLockerUtility 3.1' 
    $MenuOptions = @(
        "-> Press 1: Show All Drives"
        "-> Press 2: UnLock BitLocker Drive"
        "-> Press 3: Turn OFF | Suspend BitLocker"
        "-> Press 4: Go to the CMD"
        "-> Press Q: To Quit" 
    )

    Write-Host "`n================= $MenuTitle =================`n" -ForegroundColor yellow
    $MenuOptions | ForEach-Object { MenuOption( $_ ) }
    Write-Host "`n================= $MenuTitle =================`n" -ForegroundColor yellow
}  

 $UserInput = $null
while ($UserInput -ne "q") {
    Clear-Host
    MainMenu
    Write-Host "Enter one option:" -ForegroundColor Black -BackgroundColor Yellow -NoNewline
    $UserInput = Read-Host

    switch ($UserInput) {
        1 { Write-Host "`nDrives Detected:" -ForegroundColor Yellow ; $GetDrives = GetDrivesEncryption; if ($null -eq $GetDrives) { Write-Host "`r`nNo Encrypted Drives Detected :(`r`n" -ForegroundColor Red } else { $GetDrives | Sort-Object -Property DriveLetter | Format-List }; Pause }
        2 { UnLockDrive ; Pause }
        3 { TurnOffBitLockerAndSuspend ; Pause }
        4 { $UserInput = "q"; Clear-Host; cmd }
        Default { }
    }
}

# Quit Execution safely
Stop-Process -Name cmd -Force -ErrorAction SilentlyContinue
