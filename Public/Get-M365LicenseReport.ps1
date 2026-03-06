function Get-M365LicenseReport {
    # Pull all users from the tenant with the properties we need for the report
    $allUsers = Get-MgUser -All -Property "DisplayName,UserPrincipalName,AssignedLicenses,SignInActivity"

    # Pull all license SKUs once so we can look up readable names inside the loop
    $allSkus = Get-MgSubscribedSku -All

    # Start with an empty array to collect each user's report row
    $report = @()

    foreach ($user in $allUsers) {
        # Build one row per user
        $row = [PSCustomObject]@{
            DisplayName = $user.DisplayName
            Email       = $user.UserPrincipalName

            # If the user has licenses, translate each SKU ID to a readable name — otherwise show None
            LicensesOwned = if ($user.AssignedLicenses) {
                              ($user.AssignedLicenses | ForEach-Object {
                                  ($allSkus | Where-Object { $_.SkuId -eq $_.SkuId }).SkuPartNumber
                              }) -join ", "
                          } else { "None" }

            # If the user has a recorded sign-in, show the date — otherwise show Never
            LastSignIn  = if ($user.SignInActivity.LastSignInDateTime) {
                              $user.SignInActivity.LastSignInDateTime.ToString("yyyy-MM-dd")
                          } else { "Never" }
        }

        # Add the row to the report
        $report += $row
    }

    # Export the full report to CSV
    $reportPath = "$env:USERPROFILE\Logs\M365Automation\LicenseReport.csv"
    $report | Export-Csv -Path $reportPath -NoTypeInformation
    Write-Log -Message "License report exported to $reportPath." -Level 'INFO'
}
