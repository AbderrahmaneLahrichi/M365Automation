# M365Automation

A PowerShell module for automating Microsoft 365 user lifecycle management using the Microsoft Graph PowerShell SDK. Plug-and-play — authenticate with your Microsoft account and run. No hardcoded values, no manual configuration beyond your usage location.

---

## Prerequisites

- PowerShell 5.1 or later
- Microsoft Graph PowerShell SDK

Install the SDK if you don't have it:

```powershell
Install-Module Microsoft.Graph
```

---

## Setup

Clone the repo and navigate to the module folder:

```powershell
git clone https://github.com/AbderrahmaneLahrichi/M365Automation.git
cd M365Automation
```

Import the module:

```powershell
Import-Module .\M365Automation.psd1 -Force
```

---

## Configuration

Open `Config\config.json` and set your country code:

```json
{
  "DefaultUsageLocation": "US"
}
```

That is the only value you need to set. Everything else is pulled automatically from your Microsoft Graph session after you connect.

---

## Connecting

```powershell
Connect-M365
```

This opens a browser login prompt. Sign in with your Microsoft 365 admin account. The module automatically detects your tenant domain and ID — no manual entry required.

---

## Functions

| Function | Description | Parameters |
|---|---|---|
| `Connect-M365` | Authenticates to Microsoft Graph and auto-detects tenant info | None |
| `New-M365User` | Bulk creates users from a CSV file, assigns licenses, adds to department groups, sends welcome emails | `-CsvPath` (optional — point to any CSV file, defaults to `New-Users-Template.csv`) |
| `Send-M365PasswordReminder` | Sends reminder emails to users who have not changed their temporary password | None |
| `Invoke-M365Offboard` | Disables sign-in, removes from all groups, strips license. Account remains in Entra ID for compliance | `-Email` |
| `Remove-M365User` | Permanently deletes a user or all users. Strips licenses before deletion | `-Email`, `-All` |
| `Get-M365LicenseReport` | Exports a CSV report of all users showing assigned license and last sign-in date | None |
| `Get-M365InactiveUsers` | Exports a CSV report of users who have not signed in within a specified number of days | `-Days` (default: 30) |

---

## Onboarding Users

Prepare a CSV file with the following columns:

```
FirstName,LastName,PersonalEmail,Department,JobTitle
Jane,Doe,jane.doe@gmail.com,IT,Systems Administrator
```

Then run with your CSV:

```powershell
# Use any CSV file
New-M365User -CsvPath "C:\HR\NewHires.csv"

# Or use the default template
New-M365User
```

The script will create each account, assign the first available license, add the user to their department group, and send a welcome email with their temporary password to their personal email address.

---

## Logging

All actions are logged to:

```
C:\Users\<YourUsername>\Logs\M365Automation\
```

Log files are named by date: `M365Automation_YYYY-MM-DD.log`

CSV reports are also saved to this folder:
- `OffboardAudit.csv` — record of every offboarded user
- `LicenseReport.csv` — full license and sign-in report
- `InactiveUsersReport.csv` — users flagged as inactive

---

## Built With

- [Microsoft Graph PowerShell SDK](https://learn.microsoft.com/en-us/powershell/microsoftgraph/overview)
