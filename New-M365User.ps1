
 function New-M365User {
    <#
    .SYNOPSIS
      Creates new Microsoft 365 user accounts from a CSV file.

    .DESCRIPTION
      Reads a CSV file containing new hire information, creates their Microsoft 365
      account, adds them to their department group, and sends a welcome email with
      their temporary password to their personal email address.


#>
# Read the CSV file
$users = Import-Csv -Path ".\New-Users-Template.csv"
foreach ($user in $users) {
    # Builr the email address from first name, lastname and domain
    $email = "$($user.FirstName).$($user.LastName)@($script:config.TenantDomain)"
   
    #Checck if the user already exists
    $existingUser = Get-MgUser -Filter "mail eq '$email'" -erroraction SilentlyContinue
    # If they already exist,  log it and skip to the next user
    if ($existingUser) {
        Write-Log -Message "User with email $email already exists. Skipping." -Level 'WARN'
            continue
    }
    #Generate a random password
    $password = -join (Get-Random -InputObject([char[]]65..90)),(Get-Random -InputObject([char[]]97..122)),(Get-Random -InputObject([char[]]48..57)),(Get-Random -InputObject([char[]]33..47)),(Get-Random -InputObject ([char[]](48..122)) -Count 6)

    #Build the users full name
    $displayName = "$($user.FirstName) $($user.LastName)"

    #Create the the user in Entra ID
    $newUser = New-MgUser -DisplayName $displayName -UserPrincipalName $email -MailNickname "$($user.FirstName)$($user.LastName)" -JobTitle $user.JobTitle -Department $user.Department -UsageLocation $script:config.DefaultUsageLocation -PasswordProfile @{ ForceChangePasswordNextSignIn = $true; Password = $password } -GivenName $user.FirstName -Surname $user.LastName

    #Find the department groups
    $groups = Get-MgGroup -Filter "displayName eq '$($user.Department) Department'"
    if($groups){
            New-MgGroupMember -GroupId $group.Id -DirectoryObjectId $newUser.Id
            Write-Log -Message "Added $email to $($user.Department) group." -Level 'INFO'
    } else{
        Write-Log -Message "Department group '$($user.Department)' not found. Skipping group assignment." -Level 'WARN'
    }

    # Welcome email to the new user asking them to change their password upon signing in. 
    $emailBody = @{
        $message = @{
            subject = "Welcome to the company, $($user.FirstName)!"
            body = @{
                contentType = "Text"
                content = "Hello $($user.FirstName),`n`nWelcome to the company! Your account has been created with the following credentials:`n`nUsername: $email`nPassword: $password`n`nPlease change your password upon your first sign-in. If you have any questions, feel free to reach out to IT support.`n`nBest regards,`nThe IT Team"
            }
            toRecipients = @(
                @{
                    emailAddress = @{
                        address = $user.personalEmail
                    }
                }
            )
        }
    }

    #Send the message to the user using the Azure Graph API
    Send-MgUserMessage -UserId $newUser.Id -BodyParameter $emailBody
    Write-EventLog -Message "Welcome email sent to $($user.personalEmail) for $email." -Level 'INFO'
    }
 }