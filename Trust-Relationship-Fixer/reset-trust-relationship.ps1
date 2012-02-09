# TODO: Make Windows XP safe.

if($args[0] -eq 'onboot')
{
    # Here, we join the domain, disable admin user, disable auto-logon, delete files
    Write-Host "Adding computer to domain..."
    
    Add-Computer -DomainName mlebk.local -Credential mlebk\Administrator  | Out-Null
    
    if((Get-WmiObject Win32_ComputerSystem).PartOfDomain -eq $true)
    {
            Write-Host "The system has been joined to the domain."
    }
    
    Set-Location "HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion\Winlogon"
    New-ItemProperty -Path .\ -Name "AutoAdminLogon" -Value 0 -PropertyType "String" -Force | Out-Null
    Write-Host "Automatic Administrator logon disabled."
    
    $LocalAdmin = (Get-WmiObject -Query 'SELECT * FROM Win32_UserAccount WHERE (LocalAccount="True" AND SID LIKE "%-500")')

    if($LocalAdmin.Disabled -eq $False)
    {
        $LocalAdmin.Disabled = $True
        $LocalAdmin.Put() | Out-Null
        Write-Host "Local Administrator account has been disabled."
    }else{
        Write-Host "Local Administrator already disabled? How can that be?"
    }
    
    Write-Host "Rebooting system..."
    
    Restart-Computer
    
}else{

    Write-Host "Trust Relationship Fixer"
    Write-Host "------------------------"
    Write-Host "This script will rejoin this system to the domain, fixing trust relationship issues that may arise from system restore."
    Write-Host "Note: You will be required to provide Domain Administrator credentials."
    Write-Host "Warning: The system will be rebooted automatically, please save and close all applications."
    Write-Host ""
    $Accept = Read-Host -Prompt "To continue with script execution, please press [Y]"

    if($Accept -eq 'Y')
    {
        Write-Host "Removing the computer from the domain."

        # Remove the computer from the domain.
        Remove-Computer -Credential mlebk\Administrator -Force | Out-Null

        # TODO: Test if this updates dynamically.
        if((Get-WmiObject Win32_ComputerSystem).PartOfDomain -eq $false)
        {
            Write-Host "The system has been removed from the domain."
        }

        # Enable the built-in Administrator account
        $LocalAdmin = (Get-WmiObject -Query 'SELECT * FROM Win32_UserAccount WHERE (LocalAccount="True" AND SID LIKE "%-500")')

        if($LocalAdmin.Disabled -eq $True)
        {
            $LocalAdmin.Disabled = $False
            $LocalAdmin.Put() | Out-Null
            Write-Host "Local Administrator account has been enabled."
        }else{
            Write-Host "Local Administrator account was already enabled."
        }

        # Setup Auto Admin Logon
        Set-Location "HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion\Winlogon"
        New-ItemProperty -Path .\ -Name "AutoAdminLogon" -Value 1 -PropertyType "String" -Force | Out-Null
        Write-Host "Automatic Administrator logon enabled."

        # Copy script to continue when reboot is finished.
        Write-Host "Continuing after reboot."
        
        Copy-Item "\\10.1.1.115\PCSetup\Scripts\Trust-Relationship-Fixer\onboot.bat" "$env:temp\onboot.bat"
        Copy-Item "\\10.1.1.115\PCSetup\Scripts\Trust-Relationship-Fixer\trust-relationship-fixer.ps1" "$env:temp\trust-relationship-fixer.ps1"
        
        Set-Location "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\RunOnce"
        New-ItemProperty -Path .\ -Name "Trust-Relationship-Fixer" -Value "$env:temp\onboot.bat"
        
        Restart-Computer
        
    }else{
        # Didn't press Y, exit.
    }
}