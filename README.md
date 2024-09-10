# FailOver Automation for Hyper-V

This repository contains PowerShell scripts designed to automate failover processes in Hyper-V environments. It ensures high availability for virtual machines by streamlining the management of failover clusters across multiple hosts.

## Features
- Automates Hyper-V failover between cluster nodes.
- Detects node status and reallocates resources efficiently to minimize downtime.
- Configures failover actions based on host status.

## Setup Instructions

### Host Hyper-V 1 (Location 1)
- Schedule the failover script in **Task Scheduler** to run at system startup on **Host Hyper-V 1**. This script will handle the failover tasks specific to the first location.

### Host Hyper-V 2 (Location 2)
- Similarly, schedule the failover script to run at system startup on **Host Hyper-V 2**. This script is configured to manage the failover process in the second location.

## Script Descriptions

### Location 1 Script (Hyper-V Host 1)
- **Purpose**: Monitors the status of the Hyper-V cluster on Host 1 and automates failover procedures when needed.
- **Tasks**:
  - Detects node failure and initiates failover.
  - Reallocates virtual machine resources.
  - Updates cluster configuration based on the detected environment.

### Location 2 Script (Hyper-V Host 2)
- **Purpose**: Similar to Location 1, this script ensures that Host 2 can take over when necessary.
- **Tasks**:
  - Monitors node status in the failover cluster.
  - Reassigns resources to Host 2 in case of node failure on Host 1.

## Requirements
- Windows Server with Hyper-V role installed.
- PowerShell 5.1 or higher.
- Hyper-V failover cluster configuration.

## License
This project is licensed under the MIT License.
