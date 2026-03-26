# Multi-Tenant Provisioner
WinPE-compatible PowerShell tool to collect Autopilot hardware hashes, select a tenant, and register devices in Microsoft Intune with automatic profile assignment validation.

This tool is designed for MSPs and to be run in combination with OSDCloud in a WinPE environment during the deployment of a Windows device.

The Graph authentication logic is based on a multi-tenant app registration in Entra ID, allowing the same App ID and App Secret to be used across all tenants.

OSDCloud: https://github.com/OSDeploy/OSDCloud

Multi tenant app: https://learningbytesblog.com/posts/Muiltitenant-Entra-APP-for-multitenant-managment/

Autopilot logic used in this tool and OSDCloud USB creation based on: https://github.com/blawalt/WinPEAP

## Optionally

* A multi-tenant Entra ID enterprise application

* An Azure Key Vault

* An Azure Blob Storage


## Prerequisites

* OSDCloud PowerShell module
    ```powershell
    Install-Module OSDCloud
    ```
* **Windows Assessment and Deployment Kit (ADK) and WinPE Add-on:** Install the Windows 10 ADK and the WinPE add-on. These provide deployment tools, including WinPE itself and the `oa3tool.exe` needed later.
    * Download link: [Windows ADK Download](https://learn.microsoft.com/en-us/windows-hardware/get-started/adk-install)
    * Ensure installation of **ADK** and the **WinPE Add-on** 

## OSDCloud

* Create an OSDCloud Template
    ```powershell
    New-OSDCloudTemplate -SetAllIntl en-us -SetInputLocale en-us
    ```

* Create an OSDCloud WorkSpace
    ```powershell
    New-OSDCloudWorkspace -WorkspacePath "C:\OSDCloud\MTP"
    ```
* Copy files

* Create WinPE
    ```powershell
    Edit-OSDCloudWinPE -Wallpaper "C:\path\to\your\background.jpg"
    ```
## Test in Hyper-V

## Create bootable USB

## User with WDS PXE