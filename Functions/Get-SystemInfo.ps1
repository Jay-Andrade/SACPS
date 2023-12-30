<#
.SYNOPSIS
This function will query the system and return basic information about the system.
It's designed as an improved, more accurate, and more concise version of Get-ComputerInfo

.EXAMPLE
$systemInfo = Get-SystemInfo
Tests if a reboot is needed and outputs to the variable $rebootNeeded
#>
function Get-SystemInfo
{
    try {
        #Get information on the system
        if (((Get-CimInstance -ClassName Win32_OperatingSystem).ProductType) -eq 2){
            $dcStatus = $TRUE
        } else {
            $dcStatus = $FALSE
        }
        
        $computerInfo = Get-ComputerInfo
        
        $biosVersion = "$($computerInfo.BiosSystemBiosMajorVersion).$($computerInfo.BiosSystemBiosMinorVersion)"
        
        $diskInfo =Get-PSDrive C
        $diskFree = $diskInfo.Free /1GB
        $diskSize = $diskFree + ($diskInfo.used / 1GB)
        
        $uptime = ((Get-Date) - ($computerInfo.OsLastBootUpTime))
        
        $ramsticks = (Get-CimInstance win32_physicalmemory).Capacity
        $ramCapacity = 0
        foreach ($dimm in $ramsticks) {
            #In case more than 1 DIMM is present this is necessary
            $ramCapacity += $dimm / 1GB
        }

        #More reliable than using output from Get-ComputerInfo
        $ReleaseID = Get-ItemPropertyValue -Path "HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion" -Name ReleaseId
        if ($ReleaseID -like "2009") {
            $ReleaseID = Get-ItemPropertyValue -Path "HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion" -Name DisplayVersion
        }

        #Lenovo stores model in format '21AK002LUS' in .CSModel, and format 'ThinkPad P14s Gen 3' in .CsSystemFamily
        #Dell and HP do not follow this and store the friendly-named model name in .CSModel
        if ($computerInfo.CsManufacturer.tolower() -notlike "lenovo") {
            $manufacturer = $computerInfo.CsModel
        } else {
            $manufacturer = $computerInfo.CsSystemFamily
        }
        
        $rebootPending = Test-PendingReboot

        $publicIP = Get-PublicIP

        #Add everything into an ordered hashtable
        $systemInfo = [ordered]@{}
        $systemInfo.Add("Name",$computerInfo.CsCaption)
        $systemInfo.Add("OS",$computerInfo.OSName)
        $systemInfo.Add("OSVersion",$ReleaseID)
        $systemInfo.Add("Domain",$computerInfo.CsDomain)
        $systemInfo.Add("DomainController",$dcStatus)
        $systemInfo.Add("Manufacturer",$computerInfo.CsManufacturer)
        $systemInfo.Add("Model",$manufacturer)
        $systemInfo.Add("Processor",$computerInfo.CsProcessors)
        $systemInfo.Add("SerialNumber",$computerInfo.BiosSeralNumber)
        $systemInfo.Add("RebootPending",$rebootPending)
        $systemInfo.Add("PublicIP",$publicIP)
        $systemInfo.Add("BIOSVersion",$biosVersion)
        $systemInfo.Add("RAM",$ramCapacity)
        $systemInfo.Add("Disk",[int32]$diskSize)
        $systemInfo.Add("DiskFree",[int32]$diskFree)
        $systemInfo.Add("UptimeHours",[int32]$uptime.totalhours)
        $systemInfo.Add("UptimeDays",[math]::round($uptime.totaldays,2))
    } catch {
        Write-Syslog -Category 'ERROR' -Message "Failed to get system information. Error: $_"
        $systemInfo = $NULL
    }

    return $systemInfo
}