function Get-M365InactiveUsers {
  <#
  .SYNOPSIS
    Reports on inactive Microsoft 365 user accounts.

  .DESCRIPTION
    Flags users who have not signed in within the specified number of days.
    Accounts that have never signed in are also included. Exports results
    to a CSV report.

  #>

    param(
        # Number of days of inactivity to flag — defaults to 30 if not specified
        [int]$Days = 30
    )
    
    #Calculate the cutoff date based on the number of days specified
    $cutOffDate = (Get-Date).AddDays(-$Days)

    # Pull all users with their sign-in activity
    $allUsers = Get-MgUser -All -Property "DisplayName,UserPrincipalName,SignInActivity"

    $inactiveUsers = @()

    foreach($user in $allUsers){
        # Get the user's last sign-in date
        $lastSignIn = $user.SignInActivity.LastSignInDateTime

         # Flag the user if they have never signed in or haven't signed in since the cutoff
         if(-not $lastSignIn -or $lastSignIn -lt $cutoffDate){
            $inactiveUsers += [PSCustomObject]@{
                DisplayName = $user.DisplayName
                Email = $user.UserPrincipalName
                LastSignIn  = if ($lastSignIn) { 
                    $lastSignIn.ToString("yyyy-MM-dd")
                    } else { 
                        "Never"
                        }

                DaysSinceSignIn = if ($lastSignIn) { 
                    ((Get-Date) - $lastSignIn).Days 
                    } else { 
                        "N/A" 
                        }

            }

         }
    }
    # Export the full report to CSV
    $reportPath = "$env:USERPROFILE\Logs\M365Automation\InactiveUsersReport.csv"
    $inactiveUsers | Export-Csv -Path $reportPath -NoTypeInformation
    Write-Log -Message "Inactive users report exported to $reportPath. $($inactiveUsers.Count) inactive accounts found." -Level 'INFO'

}