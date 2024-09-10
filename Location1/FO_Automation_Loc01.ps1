<#
.SYNOPSIS
    Script per la gestione automatica del failover tra due nodi Hyper-V con dischi locali.
.DESCRIPTION
    Questo script verifica periodicamente lo stato del nodo primario e avvia il failover 
    delle macchine virtuali specificate verso il nodo secondario se il nodo primario è offline
    per un numero consecutivo di tentativi specificato.
    Lo script crea anche un file di log giornaliero e rimuove i file di log più vecchi di 7 giorni.
.PARAMETER PrimaryHost
    Nome del nodo primario da monitorare.
.PARAMETER SecondaryHost
    Nome del nodo secondario verso cui effettuare il failover.
.PARAMETER VmNames
    Elenco delle macchine virtuali da gestire.
.PARAMETER CheckInterval
    Intervallo di controllo in secondi.
.PARAMETER FailureThreshold
    Numero di tentativi falliti consecutivi per avviare il failover.
.PARAMETER LogDirectory
    Directory dei file di log.
.EXAMPLE
    .\FO_Automation_Loc01.ps1
.NOTES
    Autor: Matteo Gandelli - gandellimatteo215@gmail.com
    Date: 10/09/2024
#>

# Parametri di configurazione
$PrimaryHost = "HV-Host01-Loc1"
$SecondaryHost = "HV-Host01-Loc2"
$VmNames = @("VM01-Host01-Loc1", "VM02-Host01-Loc1", "VM03-Host01-Loc1", "VM04-Host01-Loc1", "VM05-Host01-Loc1") # Elenco delle VM da gestire
$CheckInterval = 30 # Intervallo di controllo in secondi
$FailureThreshold = 2 # Numero di tentativi falliti consecutivi per avviare il failover
$LogDirectory = "C:\FailOverLogs\" # Directory dei file di log

function Write-Log {
    param (
        [string]$Message
    )
    $date = Get-Date -Format "yyyyMMdd"
    $timestamp = Get-Date -Format "dd/MM/yyyy HH:mm:ss"
    $logFilePath = "$LogDirectory\log_$date.txt"
    $logMessage = "$timestamp $Message"
    Add-Content -Path $logFilePath -Value $logMessage
}

function Cleanup-Logs {
    param (
        [string]$LogDirectory,
        [int]$RetentionDays
    )
    $currentDate = Get-Date
    $files = Get-ChildItem -Path $LogDirectory -Filter "log_*.txt"
    
    foreach ($file in $files) {
        $creationDate = $file.CreationTime
        if (($currentDate - $creationDate).Days -gt $RetentionDays) {
            Remove-Item -Path $file.FullName -Force
            Write-Log "File di log $($file.Name) eliminato perché più vecchio di $RetentionDays giorni."
        }
    }
}

function Check-HostStatus {
    param (
        [string]$HostName
    )
    try {
        $ping = Test-Connection -ComputerName $HostName -Count 1 -ErrorAction Stop
        return $true
    } catch {
        return $false
    }
}

function Failover-VMs {
    param (
        [string]$TargetHost,
        [array]$VmNames
    )
    $startedVMs = @()
    foreach ($vmName in $VmNames) {
        $replicaVmName = "${vmName}" #Se replicate con etichetta, aggiungere:   _replica"
        if ($startedVMs -notcontains $replicaVmName) {
            Write-Log "Avvio failover per la VM: $vmName come $replicaVmName"
            
            try {
                # Avvio della VM nel nodo di destinazione con nome _replica
                Invoke-Command -ComputerName $TargetHost -ScriptBlock {
                    param ($vmName)
                    Start-VM -Name $vmName
                } -ArgumentList $replicaVmName -ErrorAction Stop
                Write-Log "La VM $replicaVmName è stata avviata con successo su $TargetHost."
                $startedVMs += $replicaVmName

                # Verifica che la VM replica sia online tramite ping
                $pingSuccess = Test-Connection -ComputerName $replicaVmName -Count 1 -ErrorAction SilentlyContinue
                if ($pingSuccess) {
                    Write-Log "La VM $replicaVmName è online su $PrimaryHost (risponde al ping)."
                } else {
                    Write-Log "La VM $replicaVmName su $PrimaryHost non risponde al ping."
                }
            } catch {
                Write-Log "Errore durante l'avvio della VM $replicaVmName da $PrimaryHost su $TargetHost" + ": $_"
            }
        } else {
            Write-Log "La VM $replicaVmName su $PrimaryHost è già stata avviata su $TargetHost."
            $failureCount = 0 # Resetta il contatore dopo il failover
        }
    }
}

$failureCount = 0
$startedVMs = @() # Array per tenere traccia delle VM avviate con successo
$RetentionDays = 7 # Numero di giorni per cui conservare i file di log

while ($true) {
    if (-not (Check-HostStatus -HostName $PrimaryHost)) {
        $failureCount++
        Write-Log "Tentativo di connessione fallito per $PrimaryHost. Tentativi falliti consecutivi: $failureCount."
        
        if ($failureCount -ge $FailureThreshold) {
            Write-Log "Il nodo primario ($PrimaryHost) è offline per $failureCount tentativi consecutivi. Avvio il failover verso il nodo secondario ($SecondaryHost)."
            Failover-VMs -TargetHost $SecondaryHost -VmNames $VmNames
        }
    } else {
        Write-Log "Il nodo primario è online."
        $failureCount = 0 # Resetta il contatore se il test di connessione ha successo
    }

    # Pulizia dei file di log più vecchi di 7 giorni
    Cleanup-Logs -LogDirectory $LogDirectory -RetentionDays $RetentionDays

    Start-Sleep -Seconds $CheckInterval
}
