# Send-EntraIDAppCredentialExpirationReport

Code provided by Frondorf Digital Solutions

## Overview
This PowerShell script uses the Microsoft Graph REST API to:

- Retrieve all Azure AD app registrations in your tenant
- Check each app’s password credentials for upcoming expiration
- Generate a single consolidated HTML report of expiring and still-valid secrets  
- Send that report as an HTML email  

## Prerequisites
- PowerShell 7.x  
- An Azure AD application (client credentials flow) with a client secret  
- Microsoft Graph **application** permissions (admin consent granted):  
  - `Application.Read.All`  
  - `AuditLog.Read.All`  
  - `Mail.Send`  

## Configuration
Edit the top of `Send-EntraIDAppCredentialExpirationReport.ps1` and set your values:

```powershell
# Days before expiration to alert
$appExpirationThreshold = 30

# Sending mailbox UPN (must exist in your tenant)
$mailSender     = "sender@yourdomain.com"

# One or more recipient email addresses
$mailRecipients = @("recipient@yourdomain.com","recipient2@yourdomain.com")

# Azure AD tenant and app registration details
$graphTenantID     = "4bf...05c"
$graphClientID     = "173...803"
$graphClientSecret = "Wu6...a~c"
```

## Usage
Run the script manually:

```powershell
cd path\to\script
./Send-EntraIDAppCredentialExpirationReport.ps1
```

- Console output will list any apps with expiring secrets  
- If any are found, you will receive a single HTML email report  

## Automation
To schedule daily runs on Windows:

1. Open Task Scheduler and click **Create Task**.  
2. On the **General** tab, name the task (e.g. “Notify Expiring Secrets”).  
3. On the **Triggers** tab, create a daily trigger at your chosen time.  
4. On the **Actions** tab, create an action:  
   - **Program/script**: `pwsh.exe`  
   - **Arguments**:  
     ```
     -NoProfile -ExecutionPolicy Bypass -File "C:\Scripts\Send-EntraIDAppCredentialExpirationReport.ps1"
     ```  
5. Save the task.  

## Troubleshooting
- **Authentication errors**: verify tenant ID, client ID, client secret, and Graph permissions.  
- **No email received**: confirm `$mailRecipients` values and check spam/junk folders.   

## License
This project is licensed under the MIT License. See [LICENSE](LICENSE) for details.

## Contact
- Email: solutions@frondorf.co  
- LinkedIn: https://www.linkedin.com/in/lucas-frondorf 
