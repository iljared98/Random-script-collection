# Created by   : I. Jared
# Date Created : 5/9/2023
# Purpose      : Check for graduated / transfer student accounts. Delete after 90 days of being disabled.

$excludedUPNs = @("CE_STUDENT@cowetaps.com", "SS_STUDENT@cowetaps.com", "NW_Student@cowetaps.com")

# Current date to delete graduated and transfer accounts, 
$dateForDeletion = "06/01"

try {
    foreach ($user in $usersToCreate) {
        try {
            if ((Get-Date -UFormat "%m/%d") -eq $dateForDeletion) {
                
            }
        }

        catch {

        }
    }
}

catch {
    # TODO: Log errors that appear.
    Write-Host "something went wrong"
}
