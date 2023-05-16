# Created by   : I. Jared
# Date Created : 5/9/2023
# Purpose      : Check for graduated / transfer student accounts. Deletes specific disabled accounts after set cutoff date.
Import-Module $PSScriptRoot\UDFs\iljFunctions.ps1 -Force

#! To log any and all output from the terminal (errors / print statements), run the string below as 
#! a scheduled task.
# powershell ".\studentAccountPurger.ps1" > studentAccountPurger.log

#! Do not change this variable as it is the same CSV file that we use for student account creation.
$PS_EXPORT_FILE = "AZAD_Students.csv"

$AD_EXPORT_FILE = "$PSScriptRoot\csv_output\ad_active_student_export.csv"
$DISABLED_OU = "OU=Disabled_Students,OU=STUDENTS,DC=cowetaps,DC=com"

# Also add test accounts to this array, as this script will export ALL ACTIVE ACCOUNTS from AD,
# these ensure that they are not accidentally moved to the disabled OU for future deletion.
$EXCLUDED_UPNS = @("CE_STUDENT@cowetaps.com", "SS_STUDENT@cowetaps.com", "NW_Student@cowetaps.com")

#! CHANGE AS NEEDED : Cutoff date for this script to delete Disabled_Students accounts.
$DELETION_DATE = "05/16"

Write-Host "            ################################################`
            #    COWETA PUBLIC SCHOOLS STUDENT ACCOUNT     #`
            #                  DISABLER                    #`
            #                                              #`
            ################################################"

Write-Host "`nDATE: $(Get-Date -UFormat "%m/%d/%Y %R")`n"  # MM/DD/YYYY HH:mm

function Student-AccountNuker {
    try {
        Write-Host "Checking if script execution date matches account cut off date..."
        if ( (Get-Date -UFormat "%m/%d") -eq $DELETION_DATE) {
            Write-Host "Script execution date matches cut off date, deleting ALL student accounts in the`n`Disabled_Students container...`n"

            $accountsToNuke = Get-ADUser -Filter {Enabled -eq $false} -SearchBase $DISABLED_OU -Properties * | Select-Object EmployeeID,`
            SamAccountName | Sort-Object EmployeeID

            $count = 0
            # -Confirm:$False argument is used since this will bug you with confirmation prompts before
            # deleting the account. In some cases this would make sense but this container is specifically
            # for accounts that we don't care about having deleted anyways.
            foreach ($account in $accountsToNuke) {
                Write-Host "Deleting Student $($account.SamAccountName) : $($account.EmployeeID)"
                Get-ADUser -F "employeeID -like $($account.EmployeeID)" | Remove-ADUser -Confirm:$False
                $count = $count + 1
            }

            Write-Host "`nAccount Deletions Successful : ($count Removed)"
            Write-Host "Cleaning up output CSV files before exiting..."

            # Delete CSV files
            return 0
        }

        else {
            Write-Host "Script executed on a day that is not the cut off date, skipping account deletion`nand cleaning up extra temporary files..."
            # Delete CSV files
            
            return 0
        }
    }

    catch {
        Warn-Print "`nERROR: Please check to see if the cut off date for account deletion is valid, or the permissions of the account running the script..."
        Warn-Print "Exiting with return code : -3"
        return -3
    }
}

# TODO: Try to do the 90 days thing that Michael wants. Not even sure how we would do that since the request seems a bit weird and not straightforward anyways.
function Student-AccountDisabler {
    try {
        Write-Host "Comparing AD export to PS export..."

        # TODO: Replace hard-coded AZAD_Students_test with $PS_EXPORT_FILE
        $usersToDisable = Compare-Object -Reference (Import-CSV $AD_EXPORT_FILE) -Difference (Import-CSV "AZAD_Students_test.csv") -Property $studentID `
        -PassThru | Sort-Object EmployeeID | Select-Object EmployeeID,SamAccountName

        # TODO: Add exclusion array to avoid disabling certain test / elementary accounts.
        foreach ($user in $usersToDisable) {
            Get-ADUser -F "employeeID -like $($user.EmployeeID)" | Disable-ADAccount
            Get-ADUser -F "employeeID -like $($user.EmployeeID)" | Move-ADObject -TargetPath $DISABLED_OU
            Write-Host "Disabled $($user.SamAccountName) : Moved to $DISABLED_OU"
        }
    }

    catch {
       Warn-Print "ERROR: Please ensure that the account executing this script has permissions to`n`
       move or disable accounts in AD. Also ensure the PS_EXPORT_FILE path is correct, and that`n`
       nothing is interferring with the AD_EXPORT_FILE (deletion etc.)."
       Warn-Print "Exiting with return code : -2"
       return -2 
    }
}


function Main {
    try {
        Write-Host "Exporting currently active AD Student accounts to CSV...`nCleaning extra output..."

        # Using this chain of commands to remove the stupid type header / empty rows that get output by AD.
        Get-ADUser -Filter {Enabled -eq $true} -SearchBase "OU=STUDENTS,DC=cowetaps,DC=com"  -Properties * | Select-Object EmployeeID,`
        SamAccountName,Givenname,Surname | Sort-Object EmployeeID | Export-CSV -Path "$PSScriptRoot\csv_output\temp.csv" -NoTypeInformation 

        Get-Content "$PSScriptRoot\csv_output\temp.csv" | Where { $_.Replace(",","") -ne "" } | Out-File $AD_EXPORT_FILE

    }

    # Catch CSV or other write exception.
    catch {
        Warn-Print "ERROR: Please double-check to make sure that the CSV path is valid and / or that the account`
        executing this script has the proper permissions to said path.`n`nExiting with return code : -1"
        return -1

    }

    Write-Host "`nRunning Student Acount Disabler function...`n"
    Student-AccountDisabler

    Write-Host "Finished the disabling of student accounts that are inactive in Powerschool`nRunning Student Account Nuker function...`n"
    Student-AccountNuker

}

#! Do not remove this function call.
Main
