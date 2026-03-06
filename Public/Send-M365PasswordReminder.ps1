function Send-M365PasswordReminder {
  <#
  .SYNOPSIS
    Sends password change reminders to users who still have a temporary password.

  .DESCRIPTION
    Checks all users for the ForceChangePasswordNextSignIn flag. If set, sends
    a reminder email to their personal email address, or falls back to their
    work email if no personal email is on file.

  #>

    # Get all users and their password status
    $userInfo = Get-MgUser -All -Property "DisplayName,UserPrincipalName,PasswordProfile,OtherMails"

    # Check if the user still has the temporary password flag set
    foreach ($user in $userInfo) {
        if ($user.PasswordProfile.ForceChangePasswordNextSignIn -eq $true) {

            # Use personal email if available, otherwise fall back to work email
            $sendTo = if ($user.OtherMails) { $user.OtherMails[0] } else { $user.UserPrincipalName }

            # Build the reminder email
            $emailBody = @{
                Message = @{
                    Subject = "Action Required - Please Update Your Password!"
                    Body    = @{
                        ContentType = "Text"
                        Content     = "Hi $($user.DisplayName), Your Microsoft 365 account is active but your temporary password has not been changed yet. Please log in at portal.office.com and update your password as soon as possible. If you need assistance contact your IT administrator."
                    }
                    ToRecipients = @(
                        @{
                            EmailAddress = @{
                                Address = $sendTo
                            }
                        }
                    )
                }
            }

            # Send reminder email from admin account
            $adminEmail = (Get-MgContext).Account
            Send-MgUserMail -UserId $adminEmail -BodyParameter $emailBody
            Write-Log -Message "Password reminder sent to $sendTo for $($user.UserPrincipalName)." -Level 'INFO'
        }
    }
}
