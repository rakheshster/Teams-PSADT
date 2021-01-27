# PSADT package for installing Teams
This is a [PSADT (PowerShell AppDeployment Toolkit)](https://psappdeploytoolkit.com/) package for installing Teams. Before using this you need to get the Teams MSI installer. You can get it [here](https://docs.microsoft.com/en-us/microsoftteams/msi-deployment). Download and put into the `Files` folder. 

I have some notes on Teams installation options on [my blog](https://rakhesh.com/citrix/notes-on-teams-locations-installing-etc/) taken when I was figuring it out. There's also a [follow up blog post](https://rakhesh.com/?p=5456&preview=true) where I talk about how frustrating it is to disable Teams auto-launch. I am no expert on this topic so please take my notes with a pinch of salt. :) 

My end goal was to install Teams in a VDI environment. 

## Installing Teams
Typically you install Teams to a machine and it adds hooks to each user's profiles and takes care of keeping itself up to date. However you can also install it per-machine (confusing, coz the default way is also to install it per machine) and this one also adds hooks but doesn't keep itself up to date - that is your responsibility. This latter method of installing is also the Teams MWI (Machine Wide Installer). 

As far as I understand the only difference between the two is that with the latter you control when Teams is updated. But I am not a 100% sure. Based on using the MWI version it looks like it installs to a location in `Program Files` and that's where all users run it from (unlike the other installer which runs from each users' `AppData` folder). The MWI version is a newer option (May 2019) and it's likely that most instructions on the Internet implictly refer to the other version and hence it's confusing. 

Microsoft's preferred approach is for you to use the typical way wherein it auto-updates. They suggest the alternative only for VDA installs. In fact, the Machine-Wide Installer does not work on non-VDA systems as far as I know so you have to trick the installer into thinking it is running on a VDA. [This blog post](https://www.masterpackager.com/blog/mst-to-install-microsoft-teams-msi-vdi-to-regular-windows-10) has some info. This PSADT package creates a dummy Citrix key to trick the installer to succeed (because I assume if you are running it on a non-VDA you want it to install).

## Uninstalling Teams
Uninstalling Teams is similarly not straightforward. 

It is not enough to uninstall it from the machine as you'd be wont to do (you have to [remove two items](https://support.microsoft.com/en-gb/office/uninstall-microsoft-teams-3b159754-3c26-4952-abe7-57d27f5f4c81?ui=en-us&rs=en-gb&ad=gb#ID0EAABAAA=Desktop) from Add/ Remove programs - "Microsoft Teams" and "Teams Machine-Wide Installer"), you also have to run the uninstaller for each user. Crazy! Microsoft talks about it [here](https://docs.microsoft.com/en-us/microsoftteams/msi-deployment#clean-up-and-redeployment-procedure) and also provides a PowerShell script [here](https://docs.microsoft.com/en-us/microsoftteams/scripts/powershell-script-deployment-cleanup).

Not sure if it's the right approach or not, I decided to just "nuke" the per-user stuff by deleting the folder where Teams is installed per user and also deleting the regkeys.

## Updating Teams
Would be a surprise if this were easy, but no surprises here. :) You'd only want to update Teams if you went the Machine-Wide Installer way, and there's no easy way of updating it. You have to uninstall and install the new version. Am [not kidding](https://docs.microsoft.com/en-us/microsoftteams/teams-client-update#what-about-updates-to-teams-on-vdi).

## How do I use this?
Just running `Deploy-Application 'Install'` via SCCM will do the Machine-Wide Install. This also removes any existing Teams installations from Add/ Remove Programs and nukes Teams from all user profiles - just to start with a clean slate. 

Similarly `Deploy-Application 'Uninstall'` removes Teams and also nukes from the user profiles.

If for some reason you don't want to have control over Teams updates and are happy with it updating itself, you can go with the default option that Microsoft recommends. For this run `Deploy-Application 'Deploy-Application2.ps1' 'Install'` to install and `Deploy-Application 'Deploy-Application2.ps1' 'Uninstall'` to uninstall. This is a variant that installs Teams on the machine such that it auto-updates per user; this one too removes any existing Teams installs before installing.

One difference between these two variants is that in the Machine-Wide Install case I also tattoo the registry so I can use it to detect the Teams version and do updates later if required. You'll find the following section in `Deploy-Application.ps1` which defines the registry keys; feel free to modify, and definitely update the version number to whatever you get when downloading the MSI.

```powershell
## Variables added by me to track installation status in SCCM. I tattoo these in the registry.
[string]$appRegKey = 'HKLM\SOFTWARE\TheFirm\Software'
[string]$appRegKeyName = 'Teams'
[string]$appRegKeyValue = '1.3.0.28779' # !!When you change this version be sure to update the detection method!!
```

As mentioned above, in the Machine-Wide Installer case I also create a dummy registry key if we are not in a VDA (it tries to detect Citrix and VMWare):

```powershell
## Create the HKLM\SOFTWARE\Citrix\PortICA registry key because you need that for the MWI install
if (!(Test-Path -Path 'HKLM:\SOFTWARE\Citrix\PortICA' -PathType 'Container') -and !(Test-Path -Path 'HKLM:\Software\VMware, Inc.\VMware VDM\Agent' -PathType 'Container')) {
    Write-Log "Creating dummy HKLM\SOFTWARE\Citrix\PortICA key as I don't seem to be running on a VDA"
    Set-RegistryKey -Key 'HKLM\SOFTWARE\Citrix\PortICA' -Value '(Default)'
    Set-RegistryKey -Key 'HKLM\SOFTWARE\Citrix\PortICA' -Name 'DummyKey' -Value 'Created to trick Teams' -Type 'String'
}
```

That's all!

## Update (26 Jan 2021)
Since the original release I have modified the `Deploy-Application.ps1` script with the following:

```powershell
# Disable fallback so Teams doesn't use the Citrix 
Set-RegistryKey -Key 'HKLM\SOFTWARE\Microsoft\Teams' -Name DisableFallback -Value '1' -Type DWord

# Disable the autorun key. Let users launch it manually.
Remove-RegistryKey -Key 'HKLM\SOFTWARE\Microsoft\Windows\CurrentVersion\Run' -Name 'Teams'
Remove-RegistryKey -Key 'HKLM\SOFTWARE\WOW6432Node\Microsoft\Windows\CurrentVersion\Run' -Name 'Teams'
```

The `Teams-Tweaks.ps1` script in this repo is not needed for PSADT but is something I created for the blog post above. It is a useful addition if you are deploying Teams to VDI solutions. In my testing however, while the script works Teams seems to ignore it... so ¯\_(ツ)_/¯