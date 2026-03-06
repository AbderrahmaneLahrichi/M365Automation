function Connect-M365 {
  <#
  .SYNOPSIS
    Connects to Microsoft Graph using browser login and auto-detects tenant info.

  .DESCRIPTION
    Opens a browser login prompt. After signing in, automatically pulls the
    tenant ID and primary domain from the session. No need to fill anything
    in config.json besides DefaultUsageLocation.

  #>

  try {
    # Open browser login - user signs into their Microsoft 365 account
    Connect-MgGraph -Scopes @(
      'User.ReadWrite.All',
      'Group.ReadWrite.All',
      'Directory.ReadWrite.All',
      'Organization.Read.All',
      'Mail.Send',
      'AuditLog.Read.All'
    ) -NoWelcome

    # After login, grab the tenant ID and domain from the active session
    $context = Get-MgContext
    $script:config | Add-Member -NotePropertyName 'TenantId' -NotePropertyValue $context.TenantId -Force

    # Extract the domain from the signed-in account email (everything after the @)
    $primaryDomain = ($context.Account -split '@')[1]
    $script:config | Add-Member -NotePropertyName 'TenantDomain' -NotePropertyValue $primaryDomain -Force

    # Log the successful connection
    Write-Log -Message "Connected to tenant: $primaryDomain ($($context.TenantId))" -Level 'INFO'

  } catch {
    Invoke-ErrorHandler -Context 'Connect-M365' -ErrorRecord $_
  }
}
