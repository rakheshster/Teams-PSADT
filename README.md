# PSADT package for installing Teams
I have some notes on Teams installation options on [my blog](https://rakhesh.com/citrix/notes-on-teams-locations-installing-etc/). 

You can get the Teams installer [here](https://docs.microsoft.com/en-us/microsoftteams/msi-deployment). Download it and put into the `Files` folder. 

## Installing Teams
Typically you install Teams to a machine and it adds hooks to each user's profiles and takes care of keeping itself up to date. That's the default way of installing Teams. However you can also install it per-machine (confusing, coz the default way is also to install it per machine! go figure) and this one also adds hooks but doesn't keep itself up to date - that is then your responsibility. This latter method of installing is also the Teams MWI (Machine Wide Installer). 

As far as I understand the only difference between the two is that with the latter you control when Teams is updated. The latter is a newer option and that's probably why most instructions on the Internet are about the former way of installing. _This is my guess_. :) 

## Uninstalling Teams
Uninstalling Teams is similarly not straightforward. 

It is not enough to uninstall it from the machine as you'd be wont to do (you have to [remove two items](https://support.microsoft.com/en-gb/office/uninstall-microsoft-teams-3b159754-3c26-4952-abe7-57d27f5f4c81?ui=en-us&rs=en-gb&ad=gb#ID0EAABAAA=Desktop) from Add/ Remove programs - "Microsoft Teams" and "Teams Machine-Wide Installer"), you also have to run the uninstaller for each user. Crazy! Microsoft talks about it [here](https://docs.microsoft.com/en-us/microsoftteams/msi-deployment#clean-up-and-redeployment-procedure) and also provides a PowerShell script [here](https://docs.microsoft.com/en-us/microsoftteams/scripts/powershell-script-deployment-cleanup).

Not sure if it's the right approach or not, I decided to just "nuke" the per-user stuff by deleting the folder where Teams is installed per user and also deleting the regkeys.

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