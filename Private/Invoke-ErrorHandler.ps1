function Invoke-ErrorHandler {
  param (
    [string]$Context,
    [System.Management.Automation.ErrorRecord]$ErrorRecord
  )

  $message = "$Context | $($ErrorRecord.Exception.Message)"
  Write-Log -Message $message -Level 'ERROR'
}
