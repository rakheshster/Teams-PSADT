# Script created by me based on the work of others. I have a NIH syndrome. :) 
param(
    # Enable or disable GPU acceleration? 
    [boolean]$disableGpu = $true,
    
    # Should Teams quit or run on clicking the close button?
    [boolean]$runningOnClose = $true,

    # Should Teams open as hidden?
    [boolean]$OpenAsHidden = $true
)

# Since I am pushing this out to all users, I'd rather the script quits immediately if there's no Teams installed
if (!(Test-Path "$env:ProgramFiles (x86)\Microsoft\Teams\current\Teams.exe")) {
    exit
}

# Quit Teams if it's running
Stop-Process -Name Teams -ErrorAction SilentlyContinue

# Teams Config Data
$TeamsConfig = "$env:APPDATA\Microsoft\Teams\desktop-config.json"

# Convert from JSON and import as an object
$TeamsConfigJSON = Get-Content $TeamsConfig -Raw -ea SilentlyContinue | ConvertFrom-Json

if ($TeamsConfigJSON) {
    # Update Object settings
    $TeamsConfigJSON.appPreferenceSettings.disableGpu = $disableGpu
    $TeamsConfigJSON.appPreferenceSettings.runningOnClose = $runningOnClose
    $TeamsConfigJSON.appPreferenceSettings.OpenAsHidden = $OpenAsHidden

    # Save
    $TeamsConfigJSON | ConvertTo-Json | Out-File -Encoding UTF8 -FilePath $TeamsConfig -Force
}

# Thanks to:
# https://devblogs.microsoft.com/scripting/configuring_startup_settings_in_microsoft_teams_with_windows_powershell/
# https://github.com/Mohrpheus78/Microsoft/blob/main/Teams%20User%20Settings.ps1
# https://www.undocumented-features.com/2019/08/12/disabling-teams-autostart/