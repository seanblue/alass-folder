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

	[string]
	$outputSubLanguage = "",

	[string[]]
	$alassArgs,

	[switch]
	$extractSubs,

	[switch]
	$deleteExtractedSubs,

	[Nullable[int]]
	$extractSubsTrackNumber,

	[string]
	$extractSubsExtension = ".ass"
)

$alassCommand = "alass"
$mkvextractCommand = "mkvextract"

if (-not $extractSubsExtension.StartsWith('.')) {
	$extractSubsExtension = ".${extractSubsExtension}"
}

if ([string]::IsNullOrWhiteSpace($outputSubLanguage)) {
	$outputSubLanguage = ""
}
elseif (-not $outputSubLanguage.StartsWith('.')) {
	$outputSubLanguage = ".${outputSubLanguage}"
}

function Exit-If-Command-Does-Not-Exist($commandName) {
	if ((Get-Command $commandName -ErrorAction SilentlyContinue) -eq $null) {
		write-host "Unable to find $commandName"
		exit
	}
}

function Create-Directory-If-Does-Not-Exist($directoryToCreate) {
	if (-not (Test-Path -LiteralPath $directoryToCreate)) {
		write-host Creating directory $directoryToCreate
		New-Item -ItemType Directory -Path $directoryToCreate | Out-Null
	}
}

function Get-Full-Path([string]$directory, [string]$fileName) {
	return Join-Path -Path $directory -ChildPath $fileName
}

Exit-If-Command-Does-Not-Exist -commandName $alassCommand

if (-not (Test-Path -LiteralPath $referenceFolder)) {
	write-host "referenceFolder: '$referenceFolder' does not exist"
	exit
}

if (-not (Test-Path -LiteralPath $incorrectSubFolder)) {
	write-host "incorrectSubFolder: '$incorrectSubFolder' does not exist"
	exit
}

$referenceFiles = @(Get-ChildItem -File -LiteralPath $referenceFolder)
$incorrectSubFiles = @(Get-ChildItem -File -LiteralPath $incorrectSubFolder)

if ($referenceFiles.Length -ne $incorrectSubFiles.Length) {
	write-host "Number of reference files and incorrect subtitle files must be the same, but were $($referenceFiles.Length) and $($incorrectSubFiles.Length)"
	exit
}

function Extract-Subs([parameter(Position=0, Mandatory=$true)][FileInfo[]]$referenceFiles) {
	Exit-If-Command-Does-Not-Exist -commandName $mkvextractCommand

	if ($extractSubsTrackNumber -eq $null) {
		write-host "extractSubsTrackNumber is required"
		exit
	}

	$currentTime = Get-Date -Format "yyyy_MM_dd_HH_mm_ss_fff"
	$newFolderName = "Extracted_Reference_Subs_${currentTime}"
	$extractedSubsDirectoryName = [Path]::Combine($referenceFolder, $newFolderName)

	Create-Directory-If-Does-Not-Exist $extractedSubsDirectoryName

	write-host "Extracting reference subtitles to $extractedSubsDirectoryName"

	for ($i=0; $i -lt $referenceFiles.Length; $i++) {
		$referenceFileDirectory = $referenceFiles[$i].Directory.FullName
		$referenceFileFullName = $referenceFiles[$i].FullName
		$referenceFileExtension = [Path]::GetExtension($referenceFileFullName)
		$referenceFileNameWithoutExtension = [Path]::GetFileNameWithoutExtension($referenceFileFullName)

		if ($referenceFileExtension -ne ".mkv") {
			write-host "Cannot extract subtitles from $referenceFileFullName. Can only extract subttitles from an mkv file."
			exit
		}

		$extractedSubsFileName = Get-Full-Path -directory $extractedSubsDirectoryName -fileName "${referenceFileNameWithoutExtension}${extractSubsExtension}"

		$trackArg = "${extractSubsTrackNumber}:${extractedSubsFileName}"
		$mkvextractArgs = @("tracks", $referenceFileFullName, $trackArg)

		& $mkvextractCommand $mkvextractArgs | Out-Null
	}

	return $extractedSubsDirectoryName
}

$extractedSubsReferenceFolder = $null
if ($extractSubs) {
	$extractedSubsReferenceFolder = Extract-Subs $referenceFiles
	$referenceFiles = @(Get-ChildItem -File -LiteralPath $extractedSubsReferenceFolder)
}

Create-Directory-If-Does-Not-Exist $outputFolder

write-host "Running alass"

for ($i=0; $i -lt $referenceFiles.Length; $i++) {
	$referenceFileFullName = $referenceFiles[$i].FullName
	$referenceFileName = [Path]::GetFileNameWithoutExtension($referenceFileFullName)

	$incorrectSubFileFullName = $incorrectSubFiles[$i].FullName
	$incorrectSubFileExtension = [Path]::GetExtension($incorrectSubFileFullName)

	$outputFileFullName = Get-Full-Path -directory $outputFolder -fileName "${referenceFileName}${outputSubLanguage}${incorrectSubFileExtension}"

	$alassCommandArgs = @()

	foreach ($arg in $alassArgs) {
		if ($arg) {
			$alassCommandArgs += $arg
		}
	}

	& $alassCommand $referenceFileFullName $incorrectSubFileFullName $outputFileFullName $alassArgs
}

if ($extractedSubsReferenceFolder -ne $null -and $deleteExtractedSubs) {
	Remove-Item -LiteralPath $extractedSubsReferenceFolder -Recurse
}