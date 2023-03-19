using namespace System.IO

param (
	[parameter(Position=0, Mandatory=$true)]
	[string]
	$referenceFolder,
	
	[parameter(Position=1, Mandatory=$true)]
	[string]
	$incorrectSubFolder,
	
	[parameter(Position=2, Mandatory=$true)]
	[string]
	$outputFolder,
	
	[string[]]
	$alassArgs
)

$alassCommand = "alass"

if ((Get-Command $alassCommand -ErrorAction SilentlyContinue) -eq $null) {
	write-host "Unable to find $alassCommand in your PATH"
	exit
}

if (-not (Test-Path -LiteralPath $referenceFolder)) {
	write-host "referenceFolder: '$referenceFolder' does not exist"
	exit
}

if (-not (Test-Path -LiteralPath $incorrectSubFolder)) {
	write-host "incorrectSubFolder: '$incorrectSubFolder' does not exist"
	exit
}

$referenceFiles = Get-ChildItem -File -LiteralPath $referenceFolder
$incorrectSubFiles = Get-ChildItem -File -LiteralPath $incorrectSubFolder

if ($referenceFiles.Length -ne $incorrectSubFiles.Length) {
	write-host "Number of reference files and incorrect subtitle files must be the same"
	exit
}

if (-not (Test-Path -LiteralPath $outputFolder)) {
	write-host Creating directory $outputFolder
	New-Item -ItemType Directory -Path $outputFolder | Out-Null
}

for ($i=0; $i -lt $referenceFiles.Length; $i++) {
	$referenceFileFullName = $referenceFiles[$i].FullName
	$referenceFileName = [Path]::GetFileNameWithoutExtension($referenceFileFullName)
	
	$incorrectSubFileFullName = $incorrectSubFiles[$i].FullName
	$incorrectSubFileExtension = [Path]::GetExtension($incorrectSubFileFullName)
	
	$outputFileName = $referenceFileName + $incorrectSubFileExtension
	$outputFileFullName = [Path]::Combine($outputFolder, $outputFileName)

	$alassCommandArgs = @()
	
	foreach ($arg in $alassArgs) {
		if ($arg) {
			$alassCommandArgs += $arg
		}
	}
	
	& $alassCommand $referenceFileFullName $incorrectSubFileFullName $outputFileFullName $alassArgs
}