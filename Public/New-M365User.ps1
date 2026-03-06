function New-M365User {
  <#
  .SYNOPSIS
    Creates new Microsoft 365 user accounts from a CSV file.

  .DESCRIPTION
    Reads a CSV file containing new hire information, creates their Microsoft 365
    account, adds them to their department group, and sends a welcome email with
    their temporary password to their personal email address.

  #>

  param(
    # Path to the CSV file containing new hire information — required
    [Parameter(Mandatory)]
    [string]$CsvPath
  )

  # Make sure the file actually exists before doing anything
  if (-not (Test-Path $CsvPath)) {
    Write-Log -Message "CSV file not found at path: $CsvPath" -Level 'WARN'
    return
  }

  # Grab the tenant domain directly from the active Microsoft Graph session
  $tenantDomain = ((Get-MgContext).Account -split '@')[1]

  # Read the CSV file containing new hire information
  $users = Import-Csv -Path $CsvPath

  # Pull all license SKUs from the tenant that have at least one license remaining
  $availableSku = Get-MgSubscribedSku -All | Where-Object {
      ($_.PrepaidUnits.Enabled - $_.ConsumedUnits) -gt 0
  } | Select-Object -First 1

  # Track remaining licenses so we know when we've run out
  if ($availableSku) {
      $remainingLicenses = $availableSku.PrepaidUnits.Enabled - $availableSku.ConsumedUnits
  } else {
      $remainingLicenses = 0
      Write-Log -Message "No available licenses found in tenant. Users will be created without licenses." -Level 'WARN'
  }

  # Go through each user in the CSV one at a time
  foreach ($user in $users) {

    # Build the work email address from first name, last name, and tenant domain
    $email = "$($user.FirstName).$($user.LastName)@$tenantDomain"

    # Check if a user with this email already exists in the tenant
    $existing = Get-MgUser -Filter "userPrincipalName eq '$email'" -ErrorAction SilentlyContinue

    # If the user already exists, log a warning and skip to the next row
    if ($existing) {
      Write-Log -Message "User $email already exists. Skipping." -Level 'WARN'
      continue
    }

    # Generate a random temporary password that meets Microsoft's requirements
    $password = -join (@(
      (Get-Random -InputObject ([char[]](65..90))),   # One uppercase letter
      (Get-Random -InputObject ([char[]](97..122))),  # One lowercase letter
      (Get-Random -InputObject ([char[]](48..57))),   # One number
      (Get-Random -InputObject ([char[]](33..47)))    # One symbol
    ) + (Get-Random -InputObject ([char[]](48..122)) -Count 6))

    # Build the user's full display name
    $displayName = "$($user.FirstName) $($user.LastName)"

    # Create the user account in Entra ID via Microsoft Graph
    $newUser = New-MgUser -BodyParameter @{
      DisplayName       = $displayName
      UserPrincipalName = $email
      MailNickname      = "$($user.FirstName).$($user.LastName)"
      JobTitle          = $user.JobTitle
      Department        = $user.Department
      UsageLocation     = $script:config.DefaultUsageLocation
      AccountEnabled    = $true
      PasswordProfile   = @{
        Password                      = $password
        ForceChangePasswordNextSignIn = $true
      }
    }

    # Log that the account was created successfully
    Write-Log -Message "Created account for $email." -Level 'INFO'

    # Assign a license to the new user if one is available
    if ($availableSku -and $remainingLicenses -gt 0) {
      try {
        Set-MgUserLicense -UserId $email -AddLicenses @{SkuId = $availableSku.SkuId} -RemoveLicenses @()
        $remainingLicenses--
        Write-Log -Message "License assigned to $email." -Level 'INFO'
      } catch {
        Write-Host "License assignment failed for $email : $($_.Exception.Message)" -ForegroundColor Red
        Write-Log -Message "License assignment failed for $email : $($_.Exception.Message)" -Level 'WARN'
      }
    } else {
      Write-Log -Message "No licenses available. $email created without a license." -Level 'WARN'
    }

    # Look up the department group in Entra ID by name
    $group = Get-MgGroup -Filter "displayName eq '$($user.Department)'"

    # If the group exists, add the user to it
    if ($group) {
      New-MgGroupMember -GroupId $group.Id -DirectoryObjectId $newUser.Id
      Write-Log -Message "Added $email to $($user.Department) group." -Level 'INFO'

    # If the group is not found, log a warning and continue
    } else {
      Write-Log -Message "Department group '$($user.Department)' not found. Skipping group assignment." -Level 'WARN'
    }

    # Build the welcome email to send to the new user's personal email
    $emailBody = @{
      Message = @{
        Subject = "Welcome to the team - Your Microsoft 365 Account"
        Body    = @{
          ContentType = "Text"
          Content     = "Hi $($user.FirstName),

Welcome to the team. Your Microsoft 365 account has been created.

Your login details are below:

Email: $email
Temporary Password: $password

Please log in at portal.office.com and change your password immediately.

If you have any issues logging in, contact your IT administrator.

Welcome aboard."
        }
        ToRecipients = @(
          @{
            EmailAddress = @{
              # Send to the personal email address from the CSV
              Address = $user.PersonalEmail
            }
          }
        )
      }
    }

    # Attempt to send the welcome email from the admin account
    try {
      $adminEmail = (Get-MgContext).Account
      Send-MgUserMail -UserId $adminEmail -BodyParameter $emailBody
      Write-Log -Message "Welcome email sent to $($user.PersonalEmail) for $email." -Level 'INFO'
    } catch {
      # If email fails, log the credentials to the console so the admin still has them
      Write-Log -Message "Email failed for $email. Credentials below:" -Level 'WARN'
      Write-Host "-----------------------------" -ForegroundColor Yellow
      Write-Host "User:     $email" -ForegroundColor Cyan
      Write-Host "Password: $password" -ForegroundColor Cyan
      Write-Host "-----------------------------" -ForegroundColor Yellow
    }

  }

}
