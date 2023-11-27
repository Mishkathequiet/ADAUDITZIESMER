﻿# Mark A. Ziesemer, www.ziesemer.com
# SPDX-FileCopyrightText: Copyright © 2023, Mark A. Ziesemer

#Requires -Version 5.1
#Requires -Modules @{ModuleName='Pester'; ModuleVersion='5.3.1'}

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

Describe 'OperatingSystemVersions'{
	BeforeAll {
		# Work-around as required for https://github.com/pester/vscode-adapter/issues/85 .
		function Set-StrictMode(){}

		. $PSScriptRoot\..\AD-Privileged-Audit.ps1

		$osVersions = Initialize-ADPrivOSVersions
		# Work-around to silence "is assigned but never used" warning from PSScriptAnalyzer.
		$osVersions | Should -Not -BeNullOrEmpty

		function Test-ADPrivOSExclusion($row){
			if($row.'OperatingSystem' -match 'Preview|Evaluation'){
				return $true
			}
			if($row.'OperatingSystemVersion' -eq '10.0 (22598)'){
				return $true
			}
		}
	}

	BeforeEach {
		# Continued work-around as required for https://github.com/pester/vscode-adapter/issues/85 .
		Microsoft.PowerShell.Core\Set-StrictMode -Version Latest
	}

	It 'Availability-IsDate' {
		$osVersions.Values | ForEach-Object{
			$_.'Builds'.Values.'Availability' | ForEach-Object{
				if($_ -is [string]){
					Get-Date -Date $_
				}else{
					$_.Values | ForEach-Object{
						Get-Date -Date $_
					}
				}
			}
		}
	}

	It 'EndOfServicing-Tuesday' {
		$exemptDates = @('2004-12-31', '2005-06-30')
		$osVersions.Values | ForEach-Object{
			$_.'Builds'.Values.'EndOfServicing'.Values | ForEach-Object{
				if($_ -is [string]){
					if($_ -notin $exemptDates){
						(Get-Date -Date $_).DayOfWeek | Should -Be 'Tuesday'
					}
				}else{
					$_.Values | ForEach-Object{
						if($_ -notin $exemptDates){
							(Get-Date -Date $_).DayOfWeek | Should -Be 'Tuesday'
						}
					}
				}
			}
		}
	}

	BeforeDiscovery {
		$sampleOsVersions = Import-Csv -Path 'Tests\OperatingSystemVersions.csv'
		$sampleOsVersions | Should -Be $sampleOsVersions
	}

	Context 'CSV-Sample-Raw' {
		It 'CSV-Sample-Raw - <_>' -ForEach $sampleOsVersions {
			$row = $_
			if(Test-ADPrivOSExclusion $row){
				return
			}
			Write-Log "Inspecting: $row"
			$osMatch = $osVersionPattern.Match($row.'OperatingSystemVersion')
			$osMatch.Success | Should -Be $true -Because $row.'OperatingSystemVersion'

			$osVer = $osVersions[$osMatch.Groups[1].Value]
			$osVer | Should -Not -Be $null
			$cats = $osVer.'Categories'
			$cats.Keys | Should -Contain $row.'OperatingSystem'

			$tier = $cats[$row.'OperatingSystem']
			$tier | Should -Not -Be $null

			$searchBuild = $osMatch.Groups[2].Value
			if($searchBuild -ne ''){
				$searchBuild = [int]$searchBuild
			}
			$build = $osVer.'Builds'[$searchBuild]
			$build | Should -Not -Be $null

			$build.Version | Should -Not -Be $null

			$availability = $build.Availability
			$availability | Should -Not -Be $null
			if($availability -isnot [string]){
				$availability = $build.Availability[$tier]
				$availability | Should -Not -Be $null
			}

			$endOfServicing = $build.EndOfServicing
			$endOfServicing | Should -Not -Be $null
			if($endOfServicing -isnot [string]){
				$endOfServicing = $build.EndOfServicing[$tier]
				$endOfServicing | Should -Not -Be $null
			}

			Write-Log "  Found: - T: $tier - V: $($build.Version) - A: $availability - EOS: $endOfServicing"
		}
	}

	Context 'CSV-Sample-Get' {

		BeforeAll {
			$ctx = [PSCustomObject]@{
				osVersions = $osVersions
				params = [PSCustomObject]@{
					now = Get-Date
				}
			}
			$ctx | Should -Be $ctx
		}

		It 'CSV-Sample-Get - <_>' -ForEach $sampleOsVersions {
			$row = $_
			if(Test-ADPrivOSExclusion $row){
				return
			}
			Write-Log "Inspecting: $row"
			$osVer = Get-ADPrivOSVersion $ctx $row
			$osVer | Should -Not -Be $null
			Write-Log "  Found: $osVer"
		}
	}

}
