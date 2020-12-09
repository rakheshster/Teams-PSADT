<#
.SYNOPSIS
	This script performs the installation or uninstallation of an application(s).
	# LICENSE #
	PowerShell App Deployment Toolkit - Provides a set of functions to perform common application deployment tasks on Windows.
	Copyright (C) 2017 - Sean Lillis, Dan Cunningham, Muhammad Mashwani, Aman Motazedian.
	This program is free software: you can redistribute it and/or modify it under the terms of the GNU Lesser General Public License as published by the Free Software Foundation, either version 3 of the License, or any later version. This program is distributed in the hope that it will be useful, but WITHOUT ANY WARRANTY; without even the implied warranty of MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE. See the GNU General Public License for more details.
	You should have received a copy of the GNU Lesser General Public License along with this program. If not, see <http://www.gnu.org/licenses/>.
.DESCRIPTION
	The script is provided as a template to perform an install or uninstall of an application(s).
	The script either performs an "Install" deployment type or an "Uninstall" deployment type.
	The install deployment type is broken down into 3 main sections/phases: Pre-Install, Install, and Post-Install.
	The script dot-sources the AppDeployToolkitMain.ps1 script which contains the logic and functions required to install or uninstall an application.
.PARAMETER DeploymentType
	The type of deployment to perform. Default is: Install.
.PARAMETER DeployMode
	Specifies whether the installation should be run in Interactive, Silent, or NonInteractive mode. Default is: Interactive. Options: Interactive = Shows dialogs, Silent = No dialogs, NonInteractive = Very silent, i.e. no blocking apps. NonInteractive mode is automatically set if it is detected that the process is not user interactive.
.PARAMETER AllowRebootPassThru
	Allows the 3010 return code (requires restart) to be passed back to the parent process (e.g. SCCM) if detected from an installation. If 3010 is passed back to SCCM, a reboot prompt will be triggered.
.PARAMETER TerminalServerMode
	Changes to "user install mode" and back to "user execute mode" for installing/uninstalling applications for Remote Destkop Session Hosts/Citrix servers.
.PARAMETER DisableLogging
	Disables logging to file for the script. Default is: $false.
.EXAMPLE
    powershell.exe -Command "& { & '.\Deploy-Application.ps1' -DeployMode 'Silent'; Exit $LastExitCode }"
.EXAMPLE
    powershell.exe -Command "& { & '.\Deploy-Application.ps1' -AllowRebootPassThru; Exit $LastExitCode }"
.EXAMPLE
    powershell.exe -Command "& { & '.\Deploy-Application.ps1' -DeploymentType 'Uninstall'; Exit $LastExitCode }"
.EXAMPLE
    Deploy-Application.exe -DeploymentType "Install" -DeployMode "Silent"
.NOTES
	Toolkit Exit Code Ranges:
	60000 - 68999: Reserved for built-in exit codes in Deploy-Application.ps1, Deploy-Application.exe, and AppDeployToolkitMain.ps1
	69000 - 69999: Recommended for user customized exit codes in Deploy-Application.ps1
	70000 - 79999: Recommended for user customized exit codes in AppDeployToolkitExtensions.ps1
.LINK
	http://psappdeploytoolkit.com
#>
[CmdletBinding()]
Param (
	[Parameter(Mandatory=$false)]
	[ValidateSet('Install','Uninstall','Repair')]
	[string]$DeploymentType = 'Install',
	[Parameter(Mandatory=$false)]
	[ValidateSet('Interactive','Silent','NonInteractive')]
	[string]$DeployMode = 'Interactive',
	[Parameter(Mandatory=$false)]
	[switch]$AllowRebootPassThru = $false,
	[Parameter(Mandatory=$false)]
	[switch]$TerminalServerMode = $false,
	[Parameter(Mandatory=$false)]
	[switch]$DisableLogging = $false
)

Try {
	## Set the script execution policy for this process
	Try { Set-ExecutionPolicy -ExecutionPolicy 'ByPass' -Scope 'Process' -Force -ErrorAction 'Stop' } Catch {}

	##*===============================================
	##* VARIABLE DECLARATION
	##*===============================================
	## Variables: Application
	[string]$appVendor = 'Microsoft'
	[string]$appName = 'Teams (Machine-Wide Install)'
	[string]$appVersion = '1.3.0.28779'
	[string]$appArch = ''
	[string]$appLang = 'EN'
	[string]$appRevision = '01'
	[string]$appScriptVersion = '1.0.0'
	[string]$appScriptDate = '03/12/2020'
	[string]$appScriptAuthor = 'Rakhesh Sasidharan'

	## Variables added by me to track installation status in SCCM. I tattoo these in the registry.
	[string]$appRegKey = 'HKLM\SOFTWARE\TheFirm\Software'
	[string]$appRegKeyName = 'Teams'
	[string]$appRegKeyValue = '1.3.0.28779' # !!When you change this version be sure to update the detection method!!
	##*===============================================
	## Variables: Install Titles (Only set here to override defaults set by the toolkit)
	[string]$installName = ''
	[string]$installTitle = ''

	##* Do not modify section below
	#region DoNotModify

	## Variables: Exit Code
	[int32]$mainExitCode = 0

	## Variables: Script
	[string]$deployAppScriptFriendlyName = 'Deploy Application'
	[version]$deployAppScriptVersion = [version]'3.8.3'
	[string]$deployAppScriptDate = '30/09/2020'
	[hashtable]$deployAppScriptParameters = $psBoundParameters

	## Variables: Environment
	If (Test-Path -LiteralPath 'variable:HostInvocation') { $InvocationInfo = $HostInvocation } Else { $InvocationInfo = $MyInvocation }
	[string]$scriptDirectory = Split-Path -Path $InvocationInfo.MyCommand.Definition -Parent

	## Dot source the required App Deploy Toolkit Functions
	Try {
		[string]$moduleAppDeployToolkitMain = "$scriptDirectory\AppDeployToolkit\AppDeployToolkitMain.ps1"
		If (-not (Test-Path -LiteralPath $moduleAppDeployToolkitMain -PathType 'Leaf')) { Throw "Module does not exist at the specified location [$moduleAppDeployToolkitMain]." }
		If ($DisableLogging) { . $moduleAppDeployToolkitMain -DisableLogging } Else { . $moduleAppDeployToolkitMain }
	}
	Catch {
		If ($mainExitCode -eq 0){ [int32]$mainExitCode = 60008 }
		Write-Error -Message "Module [$moduleAppDeployToolkitMain] failed to load: `n$($_.Exception.Message)`n `n$($_.InvocationInfo.PositionMessage)" -ErrorAction 'Continue'
		## Exit the script, returning the exit code to SCCM
		If (Test-Path -LiteralPath 'variable:HostInvocation') { $script:ExitCode = $mainExitCode; Exit } Else { Exit $mainExitCode }
	}

	#endregion
	##* Do not modify section above
	##*===============================================
	##* END VARIABLE DECLARATION
	##*===============================================

	If ($deploymentType -ine 'Uninstall' -and $deploymentType -ine 'Repair') {
		##*===============================================
		##* PRE-INSTALLATION
		##*===============================================
		[string]$installPhase = 'Pre-Installation'

		## <Perform Pre-Installation tasks here>
		## Clean up any existing Teams installs. I remove the MWI installer and also remove per user installs. 
		## I do the latter via getting a list of all profiles on this machine and removing the Teams folder 
		## from %localappdata% as well as deleting the regkey from HKCU.
		Remove-MSIApplications -Name 'Teams Machine-Wide Installer'
		Remove-MSIApplications -Name 'Microsoft Teams'

		$profilePaths = Get-UserProfiles | Select-Object -ExpandProperty 'ProfilePath' 
        foreach ($profile in $profilePaths ) {
			Remove-Folder -Path "$profile\Appdata\Local\Microsoft\Teams"
			Remove-Folder -Path "$profile\Appdata\Local\Microsoft\TeamsPresenceAddin"
			Remove-Folder -Path "$profile\Appdata\Local\Microsoft\TeamsMeetingAddin"
			Remove-Folder -Path "$profile\Appdata\Local\SquirrelTemp"
			Remove-Folder -Path "$profile\Appdata\Roaming\Microsoft\Teams"
		}

		[scriptblock]$HKCURegistryChanges = {
			Remove-RegistryKey -Key 'HKCU\Software\Microsoft\Office\Teams' -SID $UserProfile.SID
			Remove-RegistryKey -Key 'HKCU\Software\Microsoft\Windows\CurrentVersion\Uninstall\Teams' -SID $UserProfile.SID
		}
		Invoke-HKCURegistrySettingsForAllUsers -RegistrySettings $HKCURegistryChanges

		## Create the HKLM\SOFTWARE\Citrix\PortICA registry key because you need that for the MWI install
		if (!(Test-Path -Path 'HKLM:\SOFTWARE\Citrix\PortICA' -PathType 'Container') -and !(Test-Path -Path 'HKLM:\Software\VMware, Inc.\VMware VDM\Agent' -PathType 'Container')) {
			Write-Log "Creating dummy HKLM\SOFTWARE\Citrix\PortICA key as I don't seem to be running on a VDA"
			Set-RegistryKey -Key 'HKLM\SOFTWARE\Citrix\PortICA' -Value '(Default)'
		}

		##*===============================================
		##* INSTALLATION
		##*===============================================
		[string]$installPhase = 'Installation'

		## Handle Zero-Config MSI Installations
		If ($useDefaultMsi) {
			[hashtable]$ExecuteDefaultMSISplat =  @{ Action = 'Install'; Path = $defaultMsiFile }; If ($defaultMstFile) { $ExecuteDefaultMSISplat.Add('Transform', $defaultMstFile) }
			Execute-MSI @ExecuteDefaultMSISplat; If ($defaultMspFiles) { $defaultMspFiles | ForEach-Object { Execute-MSI -Action 'Patch' -Path $_ } }
		}

		## <Perform Installation tasks here>
		## Note that "ALLUSER=1" is tyically for VDI environments only. The Teams application doesn’t auto-update whenever there is a new version.
		## "ALLUSERS=1" means Teams is visible in Add/ Remove programs and anyone with admin priviliges can uninstall
		## OPTIONS="noAutoStart=true" stops Teams from autolaunching
		Execute-MSI -Action 'Install' -Path "$dirFiles\Teams_windows_x64.msi" -Parameters '/qn /NORESTART ALLUSER=1 ALLUSERS=1 OPTIONS="noAutoStart=true"'

		##*===============================================
		##* POST-INSTALLATION
		##*===============================================
		[string]$installPhase = 'Post-Installation'

		## <Perform Post-Installation tasks here>
		Set-RegistryKey -Key "$appRegKey" -Name "$appRegKeyName" -Value "$appRegKeyValue" -Type String -ContinueOnError:$True

	}
	ElseIf ($deploymentType -ieq 'Uninstall')
	{
		##*===============================================
		##* PRE-UNINSTALLATION
		##*===============================================
		[string]$installPhase = 'Pre-Uninstallation'

		## Show Progress Message (with the default message)

		## <Perform Pre-Uninstallation tasks here>


		##*===============================================
		##* UNINSTALLATION
		##*===============================================
		[string]$installPhase = 'Uninstallation'

		## Handle Zero-Config MSI Uninstallations
		If ($useDefaultMsi) {
			[hashtable]$ExecuteDefaultMSISplat =  @{ Action = 'Uninstall'; Path = $defaultMsiFile }; If ($defaultMstFile) { $ExecuteDefaultMSISplat.Add('Transform', $defaultMstFile) }
			Execute-MSI @ExecuteDefaultMSISplat
		}

		# <Perform Uninstallation tasks here>
		Execute-MSI -Action 'Uninstall' -Path "$dirFiles\Teams_windows_x64.msi" -Parameters '/qn /NORESTART ALLUSER=1 ALLUSERS=1'


		##*===============================================
		##* POST-UNINSTALLATION
		##*===============================================
		[string]$installPhase = 'Post-Uninstallation'

		## <Perform Post-Uninstallation tasks here>
		## Delete Teams from all the local profiles. Also delete the registry keys from HKCU.
		$profilePaths = Get-UserProfiles | Select-Object -ExpandProperty 'ProfilePath' 
        foreach ($profile in $profilePaths ) {
			Remove-Folder -Path "$profile\Appdata\Local\Microsoft\Teams"
			Remove-Folder -Path "$profile\Appdata\Local\Microsoft\TeamsPresenceAddin"
			Remove-Folder -Path "$profile\Appdata\Local\Microsoft\TeamsMeetingAddin"
			Remove-Folder -Path "$profile\Appdata\Local\SquirrelTemp"
			Remove-Folder -Path "$profile\Appdata\Roaming\Microsoft\Teams"
		}

		[scriptblock]$HKCURegistryChanges = {
			Remove-RegistryKey -Key 'HKCU\Software\Microsoft\Office\Teams' -SID $UserProfile.SID -Recurse
			Remove-RegistryKey -Key 'HKCU\Software\Microsoft\Windows\CurrentVersion\Uninstall\Teams' -SID $UserProfile.SID -Recurse
		}
		Invoke-HKCURegistrySettingsForAllUsers -RegistrySettings $HKCURegistryChanges

		Remove-RegistryKey -Key "$appRegKey" -Name $appRegKeyName
	}
	ElseIf ($deploymentType -ieq 'Repair')
	{
		##*===============================================
		##* PRE-REPAIR
		##*===============================================
		[string]$installPhase = 'Pre-Repair'

		## Show Progress Message (with the default message)
		Show-InstallationProgress

		## <Perform Pre-Repair tasks here>

		##*===============================================
		##* REPAIR
		##*===============================================
		[string]$installPhase = 'Repair'

		## Handle Zero-Config MSI Repairs
		If ($useDefaultMsi) {
			[hashtable]$ExecuteDefaultMSISplat =  @{ Action = 'Repair'; Path = $defaultMsiFile; }; If ($defaultMstFile) { $ExecuteDefaultMSISplat.Add('Transform', $defaultMstFile) }
			Execute-MSI @ExecuteDefaultMSISplat
		}
		# <Perform Repair tasks here>

		##*===============================================
		##* POST-REPAIR
		##*===============================================
		[string]$installPhase = 'Post-Repair'

		## <Perform Post-Repair tasks here>


    }
	##*===============================================
	##* END SCRIPT BODY
	##*===============================================

	## Call the Exit-Script function to perform final cleanup operations
	Exit-Script -ExitCode $mainExitCode
}
Catch {
	[int32]$mainExitCode = 60001
	[string]$mainErrorMessage = "$(Resolve-Error)"
	Write-Log -Message $mainErrorMessage -Severity 3 -Source $deployAppScriptFriendlyName
	Show-DialogBox -Text $mainErrorMessage -Icon 'Stop'
	Exit-Script -ExitCode $mainExitCode
}
