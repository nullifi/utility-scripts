<#
.SYNOPSIS
	Manage locally installed printers, add, delete, replace print server.

.DESCRIPTION
	Allows the management of locally installed printers. You can add and delete
	predefined printer groups, and you can replace existing printers with
	identical printers located on a different print server. Printers and copiers
	can be "replaced" independently.
#>

# TODO: Create a generic "parameter validation" function. Check all $args for validity
# based on which switch($args[0]) we are on

##
# Initial Setup Variables
##

# Default printer and copier servers, used when adding new printers
$CopyServer = "\\10.1.1.125\"
$CopierServer = "\\10.1.1.115\"

# Available printers and copiers, script will not touch any other printers
$NW = @("NWCopy", "NWBond", "NWLabels")
$NE = @("NECopy", "NEBond", "NELabels")
$SE = @("SECopy", "SEBond", "SELabels")
$SW = @("SWCopy", "SWBond", "SWLabels")
$Copiers = @("Color", "NWCopier", "SWCopier", "SECopier")

# Default printers per group, used to set default initially
$NWDef = "NWCopy"
$NEDef = "NECopy"
$SEDef = "SECopy"
$SWDef = "SWCopy"

# The crux of this entire script
$net = New-Object -com WScript.Network


##
# Function Definitions
##

function Show-Help
{
	Write-Host "Printer Management Script"
	Write-Host "------------------------"
	Write-Host "Usage: ./manage-printers.ps1 [function] <parameters>"
	Write-Host " "
	Write-Host "[function] can be:"
	Write-Host "add [group]                  Installs the specified group of printers and copiers."
	Write-Host "delete [group]               Deletes existing printers and copiers."
	Write-Host "replace [type] [old] [new]   Changes the servers of the specified type of printers.  "
	Write-Host " "
	Write-Host "[group] can be:"
	Write-Host "NW                 Northwest printer group"
	Write-Host "NE                 Northeast printer group"
	Write-Host "SW                 Southwest printer group"
	Write-Host "SE                 Southeast printer group"
	Write-Host " "
	Write-Host "All groups install all existing copiers as well. Delete only deletes copy printers, not copiers."
	Write-Host " "
	Write-Host "[type] can be: printers, copiers"
	Write-Host "[old] is the old print server, ie: \\ML-FS\"
	Write-Host "[new] is the new print server, ie: \\ML-Index\"
	Write-Host " "
}


function Add-Slashes($str, $type = 0)
{
	switch($type)
	{
		"0"
		{
			if(!$str.StartsWith("\\"))
			{
				$str = "\\" + $str
			}
			
			if(!$str.EndsWith("\"))
			{
				$str += "\"
			}
		}
		"1"
		{
			if(!$str.StartsWith("\\"))
			{
				$str = "\\" + $str
			}
			
			if($str.EndsWith("\"))
			{
				$str = $str.Substring(0, ($str.Length - 1))
			}
		}
	}
	
	return $str
}


function Get-Group($Group)
{
	$Return = @{}
	$Return.Success = $true
	switch($Group)
	{
		"NW" {$Return.Printers = $NW; $Return.Default = $NWDef}
		"NE" {$Return.Printers = $NE; $Return.Default = $NEDef}
		"SW" {$Return.Printers = $SW; $Return.Default = $SWDef}
		"SE" {$Return.Printers = $SE; $Return.Default = $SEDef}
		default {$Return.Success = $false}
	}
	
	return $Return
}


function Set-DefaultPrinter($Printer, $Server)
{
	$DefPrinter = (Add-Slashes $Server) + $Printer
	$net.SetDefaultPrinter($DefPrinter)
}

# TODO: Have some kind of success/fail checking
function Add-Printer($PrinterList, $Server)
{
	foreach($Printer in $PrinterList)
	{
		$net.AddWindowsPrinterConnection((Add-Slashes $Server) + $Printer)
	}
	
	return $true
}

# TODO: Success/failure checking
function Delete-Printer($PrinterList)
{
	foreach($Printer in $PrinterList)
	{
		(Get-WmiObject -q "SELECT * FROM win32_printer WHERE sharename='$Printer'").psbase.delete()
	}
	return $true
}

# TODO: Success/failure, same as above
# TODO: Change paramters to {paremeters} style listing. That way we can specify named parameters via CLI
function Replace-Printers($Type, $OldServer, $NewServer)
{
	$DefaultPrinter = ""

	switch($Type)
	{
		"printers"
		{
			$AllPrinters = $NW + $NE + $SW + $SE
			$Replaced = $false
			foreach($Printer in $AllPrinters)
			{
				if([string]::Compare((Add-Slashes $OldServer 1), (Get-WmiObject -q "SELECT * FROM win32_printer WHERE sharename='$Printer'").SystemName, $true) -eq 0)
				{
					if(((Get-WmiObject -q "SELECT * FROM win32_printer WHERE sharename='$Printer'").default) -eq $true)
					{
						$DefaultPrinter = $Printer
					}
					# The server matches, let's delete this printer and add it again with the new server.
					if((Delete-Printer $Printer))
					{
						Add-Printer $Printer $NewServer
						
						$Replaced = $true
					}
				}
			}
		}
		"copiers"
		{
			foreach($Copier in $Copiers)
			{
				if([string]::Compare((Add-Slashes $OldServer 1), (Get-WmiObject -q "SELECT * FROM win32_printer WHERE sharename='$Copier'").SystemName, $true) -eq 0)
				{
					if(((Get-WmiObject -q "SELECT * FROM win32_printer WHERE sharename='$Copier'").default) -eq $true)
					{
						$DefaultPrinter = $Copier
					}
					# The server matches, delete this copier and add it again with the new server.
					if(Delete-Printer($Copier))
					{
						Add-Printer($Copier, $NewServer)
					
					}
				}
			}
		}
	}
	
	if($DefaultPrinter -ne "")
	{
		Set-DefaultPrinter $DefaultPrinter $NewServer
	}
}

# Main execution loop. Loop? It's not a loop... program? switch. Whatever.
switch($args[0])
{
	"add"
	{
		$Group = Get-Group($args[1])
		
		if($Group.Success -eq $true)
		{
			if($args[2] -ne $null)
			{
				$CopyServer = $args[2]
			}

			if($args[3] -ne $null)
			{
				$CopierServer = $args[3]
			}

			if((Add-Printer $Group.Printers $CopyServer))
			{
				Write-Host "Printers installed."
			}

			if((Add-Printer $Copiers $CopierServer))
			{
				Write-Host "Copiers installed."
			}

			Set-DefaultPrinter $Group.Default $CopyServer
		}else{
			Show-Help
			exit
		}
	}
	"delete"
	{
		$Group = Get-Group($args[1])
		
		if($Group.Success -eq $true)
		{
			if((Delete-Printer $Group.Printers))
			{
				Write-Host "Printers deleted."
			}
		}else{
			Show-Help
			exit
		}
	}
	"replace"
	{
		if((Replace-Printers $args[1] $args[2] $args[3]))
		{
			Write-Host "Printers replaced."
		}
	}
	"report"
	{
		# TODO: Report on all printers installed. Use sharename, systemname, or something to get \\server\printer.
	}
	"help"
	{
		Show-Help
		exit
	}
	default
	{
		Show-Help
		exit
	}
}