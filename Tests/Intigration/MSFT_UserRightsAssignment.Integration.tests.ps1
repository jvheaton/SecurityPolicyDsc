<#
.Synopsis
   Template for creating DSC Resource Integration Tests
.DESCRIPTION
   To Use:
     1. Copy to \Tests\Integration\ folder and rename MSFT_x<ResourceName>.Integration.tests.ps1
     2. Customize TODO sections.
     3. Create test DSC Configurtion file MSFT_x<ResourceName>.config.ps1 from integration_config_template.ps1 file.

.NOTES
   Code in HEADER, FOOTER and DEFAULT TEST regions are standard and may be moved into
   DSCResource.Tools in Future and therefore should not be altered if possible.
#>

# TODO: Customize these parameters...
$Global:DSCModuleName      = 'xSecedit' # Example xNetworking
$Global:DSCResourceName    = 'MSFT_xUserRightsAssignment' # Example MSFT_xFirewall
# /TODO

#region HEADER
if ( (-not (Test-Path -Path '.\DSCResource.Tests\')) -or `
     (-not (Test-Path -Path '.\DSCResource.Tests\TestHelper.psm1')) )
{
    & git @('clone','https://github.com/PowerShell/DscResource.Tests.git')
}
else
{
    & git @('-C',(Join-Path -Path (Get-Location) -ChildPath '\DSCResource.Tests\'),'pull')
}

Import-Module $PSScriptRoot\..\..\DSCResources\MSFT_xUserRightsAssignment\MSFT_xUserRightsAssignment.psm1 -Force
Import-Module .\DSCResource.Tests\TestHelper.psm1 -Force
$TestEnvironment = Initialize-TestEnvironment `
    -DSCModuleName $Global:DSCModuleName `
    -DSCResourceName $Global:DSCResourceName `
    -TestType Integration 
#endregion

# TODO: Other Init Code Goes Here...

# Using try/finally to always cleanup even if something awful happens.
try
{
    #region Integration Tests
    $ConfigFile = Join-Path -Path $PSScriptRoot -ChildPath "$($Global:DSCResourceName).config.ps1"
    . $ConfigFile

    Describe "$($Global:DSCResourceName)_Integration" {

        #Get policy state before so we can restore policy after test
        $beforeTest = Get-TargetResource -Policy $rule.Policy -Identity $rule.Identity -Ensure $rule.Ensure

        #region DEFAULT TESTS
        Context "Default Tests" {
            It 'Should compile without throwing' {
                {
                    Invoke-Expression -Command "$($Global:DSCResourceName)_Config -OutputPath `$TestEnvironment.WorkingFolder"
                    Start-DscConfiguration -Path $TestEnvironment.WorkingFolder `
                        -ComputerName localhost -Wait -Verbose -Force
                } | Should not throw
            }

            It 'should be able to call Get-DscConfiguration without throwing' {
                { Get-DscConfiguration -Verbose -ErrorAction Stop } | Should Not throw
            }
        }
        #endregion

        Context "Verify Successful Configuration" {

            It 'Should have set the resource and all the parameters should match' {
                 $getResults = Get-TargetResource -Policy $rule.Policy -Identity $rule.Identity -Ensure $rule.Ensure
                 
                 foreach ($Id in $rule.Identity)
                 {
                    $getResults.Identity | where {$_ -eq $Id} | Should Be $Id
                 }

                 $rule.Policy | Should Be $getResults.Policy
                 $rule.Ensure | Should Be $getResults.Ensure
            }
        }
        #Clean up
        #Remove all Identities from policy used for testing and restore to original state
        Set-TargetResource -Policy $rule.Policy -Identity NULL -Ensure Present

        Set-TargetResource -Policy $rule.Policy -Identity $beforeTest.ActualIdentity -Ensure Present
    }
    #endregion

}
finally
{
    #region FOOTER
    Restore-TestEnvironment -TestEnvironment $TestEnvironment
    #endregion

    # TODO: Other Optional Cleanup Code Goes Here...
}
