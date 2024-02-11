<#
    .SYNOPSIS
       Export all FIDO2 registration info for all users within an Entra OD tenant
    
    .DESCRIPTION
        PowerShell script to gather and export all FIDO2 registration information for all users to a .CSV file.

    .NOTES
        Requirements:
        - Microsoft Graph Powershell SDK (will be installed if not present)
        - Graph permissions:
                User.Read.All
                UserAuthenticationMethod.Read.All
                UserAuthMethod-Passkey.Read.All
    
    .PARAMETER CsvFile
        Specify the full output path and filename for the CSV report file.
        If not specified, the script will produce an report in the current folder using the following file name: "Fido2Registration_Report.csv".

    .PARAMATER Delimter
        Specify the delemiter character used for the CSV output file.
        If not specified, ";" will be used as delimiter.

    .EXAMPLE        
        PS> .\Export-Fido2Info.ps1 -CsvFile "C:\Temp\Fido2Registration_Report.csv" -Delimiter ";"


    Version    Date          Changed by                        Changes
    ---------------------------------------------------------------------------------------
    1.0        21-11-2023    Michel van Vliet                  -

#>

## Parameters
param (
    [Parameter(Mandatory=$False)]
    [string]$CsvFile="Fido2Registration_Report.csv",
    [Parameter(Mandatory=$False)]
    [string]$Delimiter=";"
)

## Variables
$PermScopes="User.Read.All",
            "UserAuthenticationMethod.Read.All",
            "UserAuthMethod-Passkey.Read.All"

## Functions
Function Connect-PSGraph {
    Param (
        [Parameter(Mandatory=$False)]
        [switch]$CreateNewSession,

        [Parameter(Mandatory=$True)]
        [string[]]$Scopes
    )
    ## Check for module installation
    $Module=Get-Module -Name microsoft.graph -ListAvailable
    If($Module.count -eq 0) { 
        Write-Output "Microsoft Graph PowerShell SDK is not available"
        $Confirm= Read-Host Are you sure you want to install module? [Y] Yes [N] No 
        If($Confirm -match "[yY]") 
        { 
            Write-Output "Installing Microsoft Graph PowerShell module..."
            Install-Module Microsoft.Graph -Repository PSGallery -Scope CurrentUser -AllowClobber -Force
        }
        Else {
            Write-Output "Microsoft Graph PowerShell module is required to run this script. Please install module using Install-Module Microsoft.Graph cmdlet." 
            Exit
        }
    }
    ## Disconnect Existing MgGraph session
    If($CreateNewSession.IsPresent){
        Try{Disconnect-MgGraph -ErrorAction SilentlyContinue}
        Catch{}
    }
    ## Connecting to MgGraph
    Write-Output "Connecting to Microsoft Graph"
    Connect-MgGraph -Scopes $Scopes

    If((Get-MgContext) -ne "") {
        Write-Output "Connected to Microsoft Graph PowerShell using account: $((Get-MgContext).Account)"
    }
}

######################################################################################
######################################################################################

## Connect to Graph
Connect-PsGraph -Scopes $PermScopes -CreateNewSession

## Get All User Objects
Try{
    $Users=Get-MgUser -All
}
Catch{Write-Error $_.Exception.Message}

## Gather info per user object
$TotalCount=($Users.Id).Count
Write-Host "Total Number of users: $TotalCount"
$i=0
$Fido2Regs=@()
ForEach ($User in $Users){
    $i++
    $ItemsPercentage=[math]::Round(($i / $TotalCount) * 100)
    Write-Progress -activity "Check Fido2 Registration Details" -status "Percent completed: $ItemsPercentage% ($i/$TotalCount)" -PercentComplete (($i / $TotalCount) * 100) -CurrentOperation $User.DisplayName
    # Get Details
    $Details=$Null
    Try{
        $Details=Get-MgUserAuthenticationFido2Method -UserId $User.Id
    }
    Catch{Write-Error $_.Exception.Message}
    # Add details to output report
    ForEach ($Entry in $Details){
        $Entry | Add-Member -Name “UserID“ -Value $User.Id -MemberType NoteProperty -Force
        $Entry | Add-Member -Name “UserPrincipalName“ -Value $User.UserPrincipalName -MemberType NoteProperty -Force
        $Entry | Add-Member -Name “UserDisplayName“ -Value $User.DisplayName -MemberType NoteProperty -Force
        $Fido2Regs+=$Entry
    }
}

## Display Grouped Ouput
$Fido2Regs | Group-Object Model -NoElement
$Fido2Regs | Group-Object AaGuid -NoElement

## Export info to CSV
$Fido2Regs | Select AaGuid,CreatedDateTime,DisplayName,Id,Model,UserID,UserPrincipalName,UserDisplayName | Export-Csv $CsvFile -Delimiter $Delimiter -NoTypeInformation -Encoding UTF8

## Disconnect Graph
Write-Host "Disconnect Microsoft Graph"
Disconnect-MgGraph
