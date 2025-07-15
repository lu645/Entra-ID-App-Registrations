<#
.SYNOPSIS
    Notifies about expiring Entra ID App Registration credential expiration.

.DESCRIPTION
    Retrieves all Entra ID App Registrations, checks password and certificate credentials
    for upcoming expiration within a defined threshold, and sends a consolidated HTML
    email report via Microsoft Graph.

.PARAMETER graphTenantID
    The Azure Tenant ID.

.PARAMETER graphClientID
    The client (application) ID for authentication.

.PARAMETER graphClientSecret
    The client secret for authentication.

.PARAMETER mailSender
    The UPN of the sending mailbox.

.PARAMETER mailRecipients
    Array of recipient email addresses.

.PARAMETER appExpirationThreshold
    The threshold in days for notifying about expiring credentials.

.EXAMPLE
    ./Send-EntraIDAppCredentialExpirationReport.ps1

.NOTES
    Requires PowerShell 7.x.
    The service principal must have application permissions:
      - Application.Read.All
      - AuditLog.Read.All
      - Mail.Send
    Grant admin consent after assigning permissions.
    You may need to set:
        Set-ExecutionPolicy -Scope Process -ExecutionPolicy Bypass
#>


# CONSTANT DECLARATION
$graphTenantID = "4bf...f05c"
$graphClientID = "173....803"
$graphClientSecret = "Wu6...a~c"

$mailSender = "sender@yourdomain.com"
$mailRecipients = @("recipient@yourdomain.com","recipient2@yourdomain.com")

$appExpirationThreshold = 30

$dateToday = Get-Date

# MAIN

    # Authenticate against Microsoft Graph
    $graphAuthBody = @{
        grant_type = "client_credentials"
        client_id = $graphClientID
        client_secret = $graphClientSecret
        scope = "https://graph.microsoft.com/.default"
    }
    try {
        $graphResponse = Invoke-RestMethod -Method POST -Uri "https://login.microsoftonline.com/$graphTenantID/oauth2/v2.0/token" -Body $graphAuthBody
    } catch {
        Write-Host "Error authenticating against Entra ID: $($_.Exception.Message)" -ForegroundColor Red
    }

    # Get all App Registrations
    $graphApps = @()
    $graphAppURI = "https://graph.microsoft.com/v1.0/applications?`$select=id,displayName,passwordCredentials,keyCredentials"
    do {
        try {
            $graphHandle = Invoke-RestMethod -Method GET -Headers @{Authorization = "Bearer $($graphResponse.access_token)"} -Uri $graphAppURI
        } catch {
            Write-Host "Error getting apps from Entra ID: $($_.Exception.Message)" -ForegroundColor Red
        }
        $graphApps += $graphHandle.value
        $graphAppURI = $graphHandle.'@odata.nextLink'
    } until ($null -eq $graphHandle.'@odata.nextLink')

    # Initialize HTML 
    $mailHTMLRows = ""

    # Iterate each App Registration
    foreach ($graphApp in $graphApps) {
        # Initialize Arrays
        $graphAppExpiringSecrets = @()
        $graphAppValidSecrets = @()

        # Iterate each App Secret
        foreach ($graphAppSecret in $graphApp.passwordCredentials) {
            $appExpirationDate = [DateTime]$graphAppSecret.endDateTime
            $appExpiresInDays = ($appExpirationDate - $dateToday).Days

            # Ensure a secret's display name
            if (-not $graphAppSecret.displayName) {
                $graphAppSecret.displayName = "<No Display Name>"
            }

            # If the secret expires in less than the threshold
            if ($appExpiresInDays -le $appExpirationThreshold) {
                $graphAppExpiringSecrets += [PSCustomObject]@{
                    displayName = $graphAppSecret.displayName
                    expirationDate = $appExpirationDate
                    daysLeft = $appExpiresInDays
                }
            } # If the secret is still valid
            else {
                $graphAppValidSecrets += [pscustomobject]@{
                    displayName    = $graphAppSecret.displayName
                    expirationDate = $appExpirationDate
                    daysLeft       = $appExpiresInDays
                }
            }
        }

        # Only show apps with at least one expiring secret
        if ($graphAppExpiringSecrets.Count -gt 0) {
            Write-Host "$($graphApp.displayName):" -ForegroundColor Cyan

            foreach ($expiringSecret in $graphAppExpiringSecrets) {
                if ($expiringSecret.daysLeft -le 0) {
                    Write-Host "`t`"$($expiringSecret.displayName)`" expired on $($expiringSecret.expirationDate)" -ForegroundColor Red
                }
                else {
                    Write-Host "`t`"$($expiringSecret.displayName)`" expires in $($expiringSecret.daysLeft) days (on $($expiringSecret.expirationDate))" -ForegroundColor Yellow
                }
            }

            if ($graphAppValidSecrets.Count -gt 0) {
                Write-Host "`tOther still valid secrets:" -ForegroundColor Green
                foreach ($validSecret in $graphAppValidSecrets) {
                    Write-Host "`t`t`"$($validSecret.displayName)`" expires in $($validSecret.daysLeft) days (on $($validSecret.expirationDate))"
                }
            }

            # Build HTML block for the iterated app
            $mailHTMLRows += "<tr style='background-color:#eee;'><td colspan='3'><strong>App: $($graphApp.displayName)</strong></td></tr>"
            foreach ($s in $graphAppExpiringSecrets) {
                $status = if ($s.daysLeft -le 0) { "Expired" } else { "$($s.daysLeft) days left" }
                $mailHTMLRows += "<tr><td>$($s.displayName)</td><td>$($s.expirationDate.ToString('yyyy-MM-dd'))</td><td>$status</td></tr>"
            }
            if ($graphAppValidSecrets.Count -gt 0) {
                foreach ($s in $graphAppValidSecrets) {
                    $mailHTMLRows += "<tr><td>$($s.displayName)</td><td>$($s.expirationDate.ToString('yyyy-MM-dd'))</td><td>$($s.daysLeft) days left</td></tr>"
                }
            }
        }
    }

    # If the HTML rows are not empty (i.e. we collected expiring apps)
    if ($mailHTMLRows.Trim()) {
        # Prepare mail HTML body
        $mailHTMLBody = @"
    <html>
    <body>
        <h2>App Credential Expiration Report</h2>
        <table border='1' cellpadding='4' cellspacing='0'>
        <tr><th>Secret Name</th><th>Expiration Date</th><th>Status</th></tr>
        $mailHTMLRows
        </table>
    </body>
    </html>
"@

        # Prepare Graph payload
        $graphMailURL  = "https://graph.microsoft.com/v1.0/users/$mailSender/sendMail"
        $graphMailBody = @{
            message = @{
                subject = "EntraID - App Registration: Credential Expiration Report"
                body = @{
                    contentType = "HTML"
                    content = $mailHTMLBody
                }
                toRecipients = $mailRecipients | ForEach-Object {
                    @{ emailAddress = @{ address = $_ } }
                }
            }
            saveToSentItems = $true
        }

        # Send mail
        try {
            Invoke-RestMethod -Method POST -Uri $graphMailURL -Headers @{ Authorization = "Bearer $($graphResponse.access_token)"; "Content-Type" = "application/json" } -Body ($graphMailBody | ConvertTo-Json -Depth 4)
        } catch {
            Write-Host "Error sending email: $($_.Exception.Message)" -ForegroundColor Red
        }
    }