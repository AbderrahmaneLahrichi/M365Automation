function Remove-M365User {
  <#
  .SYNOPSIS
    Permanently deletes a Microsoft 365 user account.

  .DESCRIPTION
    Removes a single user by email or all users with -All. Strips licenses
    before deletion so they return to the available pool immediately.
    The admin account is always skipped during bulk deletion.

  #>

    param(
        #The email of the user you want to delete. 
        [string]$Email, 
        #This switch is to delete all users. 
        [switch]$All
    )
    # If neither -Email or -All was provided, instruct the user to specify.
    if(-not $Email -and -not $All){
        Write-Log -Message " Please specify an email with -Email or use -All to delete all users." -Level 'WARN'
        return
    }
    if($email){
        
        $existingUser = Get-MgUser -Filter "userPrincipalName eq '$Email'" -ErrorAction SilentlyContinue
        if($existingUser){
            # Remove licenses before deleting so they return to the pool immediately
            $userLicenses = Get-MgUserLicenseDetail -UserId $Email
            if($userLicenses){
                Set-MgUserLicense -UserId $Email -RemoveLicenses ($userLicenses.SkuId) -AddLicenses @()
                Write-Log -Message "License removed from $Email before deletion." -Level 'INFO'
            }
            Remove-MgUser -UserId $Email
            Write-Log -Message "The user $Email has been removed." -Level 'INFO'
        } else{
            Write-Log -Message "User not found" -Level 'WARN'
        }
    }
       
    #Now we check if there are any users
    if($all){
        $allUsers = Get-MgUser -All -Property "DisplayName,UserPrincipalName"
        foreach($user in $allUsers){
            # This will skip the admin account.
            if ($user.UserPrincipalName -eq (Get-MgContext).Account) {
                continue
            }
            # Remove licenses before deleting so they return to the pool immediately
            $userLicenses = Get-MgUserLicenseDetail -UserId $user.UserPrincipalName
            if($userLicenses){
                Set-MgUserLicense -UserId $user.UserPrincipalName -RemoveLicenses ($userLicenses.SkuId) -AddLicenses @()
                Write-Log -Message "License removed from $($user.UserPrincipalName) before deletion." -Level 'INFO'
            }
            Remove-MgUser -UserId $user.UserPrincipalName
            Write-Log -Message "Deleted $($user.DisplayName) - $($user.UserPrincipalName)." -Level 'INFO'
        }

    }
}