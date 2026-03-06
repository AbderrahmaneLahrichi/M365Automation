function Invoke-M365Offboard{
  <#
  .SYNOPSIS
    Offboards a Microsoft 365 user account.

  .DESCRIPTION
    Disables sign-in, removes the user from all groups, and strips their
    license so it returns to the pool. The account is not deleted — it
    remains in Entra ID in a disabled state for audit and compliance purposes.
    An offboard audit record is exported to CSV after each run.

  #>

    param(
        # The work email of the user being offboarded
        [string]$Email

    )
    # Make sure an email was provided
    if(-not $Email){
        Write-Log -Message " Please specify an email with -Email." -Level 'WARN'
        return
    }
    if($Email){
        #Check the user exists before doing anything.
        $existingUser = Get-MgUser -Filter "userPrincipalName eq '$Email'" -Property "Id,DisplayName,UserPrincipalName" -ErrorAction SilentlyContinue
        if(-not $existingUser){
            Write-Log -Message "User $Email not found." -Level 'WARN'
            return  
         }
         Update-MgUser -UserId $Email -BodyParameter @{AccountEnabled = $false}
         Write-Log -Message "Sign-in blocked for $Email." -Level 'INFO'
        #Get all the groups the user is a memeber of.
        
        $groups = Get-MgUserMemberof -UserId $Email
        
        # Track which groups the user was removed from for the audit report
        $removedGroups = @()
        
        foreach($group in $groups){
            try{
                Remove-MgGroupMemberByRef -GroupId $group.Id -DirectoryObjectId $existingUser.Id
                $removedGroups += $group.AdditionalProperties.DisplayName
                Write-Log -Message "Removed $Email from group $($group.Id)." -Level 'INFO'
            }catch{
                Write-Log -Message "Could not remove $Email from group $($group.Id): $($_.Exception.Message)" -Level 'WARN'
            }
        }
        $licenses = Get-MgUserLicenseDetail -UserId $Email
        if($licenses){
            Set-MgUserLicense -UserId $Email -RemoveLicenses ($licenses.SkuId) -AddLicenses @()
            Write-Log -Message "Licenses removed from $Email." -Level 'INFO'
        }
        Write-Log -Message "Offboarding complete for $($existingUser.DisplayName) - $Email." -Level 'INFO'

         # Build the audit record and export to CSV
         $auditRecord = [PsCustomObject]@{
            DisplayName = $existingUser.DisplayName
           Email = $Email
           DateofOffboard = (Get-Date -Format "yyyy-MM-dd, HH:mm")
           GroupsRemoved = ($removedGroups -join ", ")
           LicenseRemoved = ($licenses.SkuPartNumber -join ", ")
           OffboardedBy = (Get-MgContext).Account  
         }
         $auditPath = "$env:USERPROFILE\Logs\M365Automation\OffboardAudit.csv"
         $auditRecord | Export-Csv -Path $auditPath -Append -NoTypeInformation
         Write-Log -Message "Audit record exported to $auditPath." -Level 'INFO'
    }
       
}