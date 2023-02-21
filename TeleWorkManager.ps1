Import-Module ActiveDirectory

Function Get-IniFile {  
	<#

   .Synopsis

    This function will load ini file

   .Description

    This function will load ini file into object

   .Example

	$testIni = Get-IniFile .\Test.ini
	$server = $testIni.database.server
	$orgnization = $testIni.owner.organization

   .Parameter spaces

	$filePath

   .Notes

    NAME:  Get-IniFile

    AUTHOR: 

    LASTEDIT: 

    KEYWORDS: Windows PowerShell ISE, Scripting Techniques

    HSG:

   .Link

     https://stackoverflow.com/a/43697842

	#Requires -Version 2.0

	#>
	param(  
		[parameter(Mandatory = $true)] [string] $filePath  
	)  
	
	$anonymous = "NoSection"
	
	$ini = @{}  
	switch -regex -file $filePath {  
		"^\[(.+)\]$" {
			# Section    
			$section = $matches[1]  
			$ini[$section] = @{}  
			$CommentCount = 0  
		}  
		
		"^(;.*)$" {
			# Comment    
			if (!($section)) {  
				$section = $anonymous  
				$ini[$section] = @{}  
			}  
			$value = $matches[1]  
			$CommentCount = $CommentCount + 1  
			$name = "Comment" + $CommentCount  
			$ini[$section][$name] = $value  
		}   
		
		"(.+?)\s*=\s*(.*)" {
			# Key    
			if (!($section)) {  
				$section = $anonymous  
				$ini[$section] = @{}  
			}  
			$name, $value = $matches[1..2]  
			$ini[$section][$name] = $value  
		}  
	}  
	
	return $ini  
}  

Function GetPersianDateTime {
	$Jc = new-object system.Globalization.PersianCalendar 
	$ThisDate = [System.DateTime]::Now
	$strReturn = "{0}/{1}/{2},{3}:{4}:{5}" -f $jc.GetYear($thisDate), $jc.GetMonth($thisDate), $jc.GetDayOfMonth($thisDate), $jc.GetHour($thisDate), $jc.GetMinute($thisDate), $jc.GetSecond($thisDate)
	return $strReturn
}

Function GetPersianDate {
	$Jc = new-object system.Globalization.PersianCalendar 
	$ThisDate = [System.DateTime]::Now
	$strReturn = "{0}-{1}-{2}" -f $jc.GetYear($thisDate), $jc.GetMonth($thisDate), $jc.GetDayOfMonth($thisDate)
	return $strReturn
}

Function ConvertToGeorgianDateTime {
	Param(
		[Parameter(Mandatory = $true, Position = 0)]
		[string]$pDate,
		[Parameter(Mandatory = $true, Position = 1)]
		[string]$strDateSep,
		[Parameter(Mandatory = $true, Position = 2)]
		[string]$strTimeSep
	)
	$Jc = new-object system.Globalization.PersianCalendar
	$CharArrayDate = $pDate.Split(" ")[0].Split($strDateSep)
	$CharArrayTime = $pDate.Split(" ")[1].Split($strTimeSep)
	$ThisDate = $Jc.ToDateTime($CharArrayDate[0], $CharArrayDate[1], $CharArrayDate[2], $CharArrayTime[0], $CharArrayTime[1], $CharArrayTime[2], 0)
	return $thisDate
}

Function SaveMyLog {
	Param ([string]$logstring)
	if (-Not (Test-Path "$($BasePath)\Logs")) {
		New-Item "$($BasePath)\Logs" -ItemType Directory
	}
	$Logfile = "$($BasePath)\Logs\$(GetPersianDate).log"
	Write-Host $logstring
	Add-content $Logfile -value "$(GetPersianDateTime)==>$logstring"
}

Function Get-ADUserMemberOf {
	Param(
		[Parameter(Mandatory = $true)]
		[ValidateNotNullOrEmpty()]
		[String]$UserNameToCheck,
		[Parameter(Mandatory = $true)]
		[ValidateNotNullOrEmpty()]
		[String]$Group
	)
	try {
		$GroupDN = (Get-ADGroup $Group).DistinguishedName
		$UserDN = (Get-ADUser $UserNameToCheck).DistinguishedName
		$Getaduser = Get-ADUser -Filter "memberOf -RecursiveMatch '$GroupDN'" -SearchBase $UserDN
		If ($Getaduser) {
			$true
		}
		Else { 
			$false 
		}
	}
	catch {
		
	}
}

$BasePath = "C:\IT\Telework\"
$iniFilePath = $BasePath + "TeleWork.ini"
SaveMyLog "Start the program to check remote work access."

if (Test-Path $iniFilePath) {
	$iniFile = Get-IniFile($iniFilePath)
	$userCount = $iniFile.UserNames.Count;
	$userGroupToCheck = 'TeleWorkers'

	if ($userCount -gt 1) {
		for ($i = 1; $i -le $userCount ; $i++) {  
			$TeleWorkStartDateTime = ''
			$TeleWorkEndDateTime = ''
			$firstName = $iniFile['User' + $i].Name
			$Username = $iniFile['User' + $i].Username

			$TeleWorkStartDate = $iniFile['User' + $i].TeleWorkStartDate
			$TeleWorkStartTime = $iniFile['User' + $i].TeleWorkStartTime

			$TeleWorkEndDate =$iniFile['User' + $i].TeleWorkEndDate
			$TeleWorkEndTime=$iniFile['User' + $i].TeleWorkEndTime

			if ( $TeleWorkStartDate -ne '' -and $TeleWorkStartTime -ne '') {
				$TeleWorkStartDateTime = ConvertToGeorgianDateTime ($TeleWorkStartDate + " " + $TeleWorkStartTime) "/" ":"
			}
		
			if ( $TeleWorkEndDate -ne '' -and  $TeleWorkEndTime -ne '') {
				$TeleWorkEndDateTime = ConvertToGeorgianDateTime ($TeleWorkEndDate + " " + $TeleWorkEndTime) "/" ":"
			}
		
			if ($TeleWorkStartDateTime -ne '' -and $TeleWorkEndDateTime -ne '') {
				if ((Get-Date) -gt $TeleWorkStartDateTime -and (Get-Date) -lt $TeleWorkEndDateTime) {
				
					if (Get-ADUserMemberOf -UserNameToCheck $Username -Group $userGroupToCheck) {
						SaveMyLog('User ' + $Username + '(' + $firstName + ') already is a member of group')
					}
					else {
						SaveMyLog('We should add user ' + $Username + '(' + $firstName + ') to group')
						Add-ADGroupMember -Identity $userGroupToCheck -Members $Username
					}
				}
				else {
					if (Get-ADUserMemberOf -UserNameToCheck $Username -Group $userGroupToCheck) {
						SaveMyLog('We should remove user ' + $Username + '(' + $firstName + ') From group')
						Remove-ADGroupMember -Confirm:$false -Identity $userGroupToCheck -Members $Username
					}
				
				}
			
			}
		
		}
	}
}
