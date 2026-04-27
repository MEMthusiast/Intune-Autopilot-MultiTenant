# Multi-Tenant Provisioner

> A PowerShell-based graphical user interface build on top of OSDCloud for selecting a provisioning profile

## 📋 Table of Contents

- [Overview](#Overview)
- [Optional prerequisites](#Optional-prerequisites)
- [Usage](#Prerequisites)
- [Tenants Configuration](#Tenants-Configuration)
- [OSDCloud](#osdcloud)

## Overview

WinPE-compatible PowerShell tool to collect Autopilot hardware hashes, select a tenant, and register devices in Microsoft Intune with automatic profile assignment validation.

This tool is designed for MSPs and to be run in combination with OSDCloud in a WinPE environment during the deployment of a Windows device.

The Graph authentication logic is based on a multi-tenant app registration in Entra ID, allowing the same App ID and App Secret to be used across all tenants.

OSDCloud: https://github.com/OSDeploy/OSDCloud

Multi tenant app: https://learningbytesblog.com/posts/Muiltitenant-Entra-APP-for-multitenant-managment/

Autopilot logic used in this tool and OSDCloud USB creation based on: https://github.com/blawalt/WinPEAP

## Screenhots

### Tenant Selector

<img width="719" height="564" alt="Image" src="https://github.com/user-attachments/assets/1b94467e-c879-486c-a2eb-b98818f32f51" />

## Choices

## Configuration Choice

Before using this solution, decide how you want to store the configuration and authentication details.

You can choose between:

### Option 1 — Hardcoded parameters in `Start-MTP.ps1`

All tenant settings, URLs, and authentication details are stored directly inside the script.

This is suitable when:

- the script is only used internally
- deployment is started from a **centralized Windows deployment server**
- there is no need to restrict usage outside your own environment

### Option 2 — Hosted externally

Configuration files are stored externally, for example in an Azure blob storage:

- `TenantsConfig.json`
- optional provisioning scripts such as `SetupComplete.ps1`

Authentication secrets can optionally be stored in **Azure Key Vault** instead of inside the script.

This is recommended when:

- you want an additional security layer
- you do not want to maintain Tenant configuration settings directly inside `Start-MTP.ps1`
- you are also using bootable USB sticks

---

## Why host the files in Azure Blob Storage and use Azure Key Vault?

A major benefit of hosting the configuration externally is that access can be restricted to a **specific public IP address**.

This means provisioning only works from an approved network location.

### Example

If you are using a **Bootable USB stick** and that USB stick is lost or stolen, the script cannot be used successfully outside the approved location, because:

- the **tenant configuration file**
- the **optional provisioning script**
- and the **authentication secret in Azure Key Vault**

can only be accessed from the allowed public IP address.

This creates an additional **safety net**.

---

## Practical Recommendation

- If you use **Bootable USB sticks** for deployment, hosting the configuration in **Azure Blob Storage** and secrets in **Azure Key Vault** is the safer choice.
- If you use a **centralized Windows deployment server** in a controlled environment, you may choose to use **hardcoded parameters** in `Start-MTP.ps1` for simplicity.



## Optional prerequisites


* A (multi-tenant) Entra ID enterprise application in every tenant

* An Azure Key Vault: https://learn.microsoft.com/en-us/azure/key-vault/general/quick-create-portal

* An Azure Blob Storage: https://learn.microsoft.com/en-us/azure/storage/common/storage-account-create?tabs=azure-portal


## Prerequisites

* **Building the Tenants configuration:** Inside the *Start-MTP.ps1* or with *Export-TentansConfig.ps1*
    * Edit Start-MTP.ps1 and go to: *#region: Hardcoded Tenant Parameters* and fill in the parameters of every tenant you want to provision.

    If you only want to provision an OS you can set *UploadToAutopilot* to **$false** and change *Name* to for example **Windows 11 Pro**

    ```powershell
        Name = "Tenant 1"
        TenantId = "XXXXXXXX-XXXX-XXXX-XXXX-XXXXXXXXXXXX"
        UploadToAutopilot = $true
        GroupTag = "TENANT1"
        OSBuild = "25H2"
        OSEdition = "Pro"
        OSVersion = "Windows 11"
        OSLanguage = "nl-nl"
        OSActivation = "Volume"
    ```
    ### test
    
    
    ```powershell
    Install-Module PartnerCenter
    ```

* **OSDCloud PowerShell module**
    ```powershell
    Install-Module OSD
    ```
* **Windows Assessment and Deployment Kit (ADK) and WinPE Add-on:** Install the Windows 10 ADK and the WinPE add-on. These provide deployment tools, including WinPE itself and the `oa3tool.exe` needed later.
    * Download link: [Windows ADK Download](https://learn.microsoft.com/en-us/windows-hardware/get-started/adk-install)
    * Ensure installation of **ADK** and the **WinPE Add-on** 

## Tenants Configuration

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
 * Update WinPE
    ```powershell
    Edit-OSDCloudWinPE
    ```

## Test in Hyper-V

## Create bootable USB
*Create a bootable USB
     ```powershell
    New-OSDCloudUSB
    ```

 *If you make changes to WinPE in your OSDCloud Workspace, you can easily update your OSDCloud USB WinPE volume by using Update-OSDCloudUSB
     ```powershell
    Update-OSDCloudUSB
    ```

## Use with WDS PXE