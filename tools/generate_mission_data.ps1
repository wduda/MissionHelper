param(
    [string]$CsvPath = "data/LOTRO Missions and Delvings Data.csv",
    [string]$OutputPath = "src/MissionData.lua"
)

Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

function Escape-LuaString {
    param([AllowNull()][string]$Value)

    if ($null -eq $Value) {
        return ""
    }

    $escaped = $Value -replace "\\", "\\\\"
    $escaped = $escaped -replace "`r`n", "`n"
    $escaped = $escaped -replace "`r", "`n"
    $escaped = $escaped -replace "`n", "\\n"
    $escaped = $escaped -replace '"', '\"'
    return $escaped.Trim()
}

function Normalize-MissionName {
    param([string]$Name)

    if ([string]::IsNullOrWhiteSpace($Name)) {
        return ""
    }

    return ($Name -replace "^Mission:\s*", "").Trim()
}

function Parse-Seconds {
    param([AllowNull()][string]$Value)

    if ([string]::IsNullOrWhiteSpace($Value)) {
        return $null
    }

    $trimmed = $Value.Trim()
    $number = 0.0
    if ([double]::TryParse($trimmed, [System.Globalization.NumberStyles]::Float, [System.Globalization.CultureInfo]::InvariantCulture, [ref]$number)) {
        if ($number -le 0) {
            return $null
        }
        return [int][math]::Round($number)
    }

    return $null
}

function Format-Seconds {
    param([int]$Seconds)

    if ($Seconds -lt 0) {
        $Seconds = 0
    }

    $minutes = [int][math]::Floor($Seconds / 60)
    $remaining = $Seconds - ($minutes * 60)
    return "{0}m{1:d2}s" -f $minutes, $remaining
}

function Build-TimeRange {
    param(
        [Nullable[int]]$A,
        [Nullable[int]]$B
    )

    if ($null -ne $A -and $null -ne $B) {
        $low = $A
        $high = $B
        if ($A -gt $B) {
            $low = $B
            $high = $A
        }
        return "$(Format-Seconds -Seconds $low)-$(Format-Seconds -Seconds $high)"
    }

    if ($null -ne $A) {
        return Format-Seconds -Seconds $A
    }

    if ($null -ne $B) {
        return Format-Seconds -Seconds $B
    }

    return ""
}

function Join-NonEmpty {
    param([string[]]$Parts)

    $filtered = @()
    foreach ($part in $Parts) {
        if (-not [string]::IsNullOrWhiteSpace($part)) {
            $filtered += $part.Trim()
        }
    }
    return $filtered
}

if (-not (Test-Path -Path $CsvPath)) {
    throw "CSV not found: $CsvPath"
}

$rows = Import-Csv -Path $CsvPath
$missions = @{}

foreach ($row in $rows) {
    if ([string]::IsNullOrWhiteSpace($row.Name)) {
        continue
    }

    if ($row.Name -notmatch "^Mission:\s*") {
        continue
    }

    $name = Normalize-MissionName -Name $row.Name
    if ([string]::IsNullOrWhiteSpace($name)) {
        continue
    }

    if ($missions.ContainsKey($name)) {
        throw "Duplicate mission name after normalization: $name"
    }

    $details = if ($row.Details) { $row.Details.Trim() } else { "" }
    $other = if ($row.Other) { $row.Other.Trim() } else { "" }
    $missionDescriptionParts = @(Join-NonEmpty -Parts @($details, $other))
    $missionDescription = ""
    if ($missionDescriptionParts -ne $null -and $missionDescriptionParts.Count -gt 0) {
        $missionDescription = [string]::Join("`n`n", $missionDescriptionParts)
    }

    $delvingRaw = if ($row.'Delving Enabled') { $row.'Delving Enabled'.Trim().ToLowerInvariant() } else { "" }
    $delvingEnabled = ($delvingRaw -eq "yes")

    $difficultySoloT6 = if ($row.'Difficulty (Solo T6)') { $row.'Difficulty (Solo T6)'.Trim() } else { "" }
    $difficultyDuoT6 = if ($row.'Difficulty (Duo T6)') { $row.'Difficulty (Duo T6)'.Trim() } else { "" }
    $difficultySoloT12 = if ($row.'Difficulty (Solo T12)') { $row.'Difficulty (Solo T12)'.Trim() } else { "" }
    $difficultyDuoT12 = if ($row.'Difficulty (Duo T12)') { $row.'Difficulty (Duo T12)'.Trim() } else { "" }

    $difficulty = ""
    $difficultyDetails = ""

    if (-not $delvingEnabled) {
        $difficulty = "no delving difficulty"
    } else {
        foreach ($candidate in @($difficultySoloT6, $difficultyDuoT6, $difficultySoloT12, $difficultyDuoT12)) {
            if (-not [string]::IsNullOrWhiteSpace($candidate)) {
                $difficulty = $candidate
                break
            }
        }

        $detailParts = @(Join-NonEmpty -Parts @(
            $(if (-not [string]::IsNullOrWhiteSpace($difficultySoloT6)) { "Solo T6: $difficultySoloT6" } else { "" }),
            $(if (-not [string]::IsNullOrWhiteSpace($difficultyDuoT6)) { "Duo T6: $difficultyDuoT6" } else { "" }),
            $(if (-not [string]::IsNullOrWhiteSpace($difficultySoloT12)) { "Solo T12: $difficultySoloT12" } else { "" }),
            $(if (-not [string]::IsNullOrWhiteSpace($difficultyDuoT12)) { "Duo T12: $difficultyDuoT12" } else { "" })
        ))
        if ($detailParts -ne $null -and $detailParts.Count -gt 0) {
            $difficultyDetails = [string]::Join(" | ", $detailParts)
        }
    }

    $secondsA = Parse-Seconds -Value $row.'Time in seconds A'
    $secondsB = Parse-Seconds -Value $row.'Time in seconds B'
    $timeRange = Build-TimeRange -A $secondsA -B $secondsB
    $timeAssessment = if ($row.'Time Assessment') { $row.'Time Assessment'.Trim() } else { "" }

    $missions[$name] = @{
        name = $name
        objectives = $details
        missionDescription = $missionDescription
        tacticalAdvice = if ($row.Advice) { $row.Advice.Trim() } else { "" }
        bugs = if ($row.Bugs) { $row.Bugs.Trim() } else { "" }
        delvingEnabled = $delvingEnabled
        difficulty = $difficulty
        difficultyDetails = $difficultyDetails
        timeRange = $timeRange
        timeAssessment = $timeAssessment
    }
}

$orderedNames = $missions.Keys | Sort-Object

$builder = New-Object System.Text.StringBuilder
[void]$builder.AppendLine('import "Turbine"')
[void]$builder.AppendLine("")
[void]$builder.AppendLine('--[[ MissionData - Mission Information Database ]]--')
[void]$builder.AppendLine('--[[ Generated from data/LOTRO Missions and Delvings Data.csv ]]--')
[void]$builder.AppendLine("")
[void]$builder.AppendLine("MissionData = {}")
[void]$builder.AppendLine("")
[void]$builder.AppendLine("-- Mission database: localized mission name as key")
[void]$builder.AppendLine("-- Structure: { name, objectives, missionDescription, tacticalAdvice, bugs, delvingEnabled, difficulty, difficultyDetails, timeRange, timeAssessment }")
[void]$builder.AppendLine("MissionData.Missions = {")

foreach ($name in $orderedNames) {
    $m = $missions[$name]
    [void]$builder.AppendLine("    [`"$(Escape-LuaString $name)`"] = {")
    [void]$builder.AppendLine("        name = `"$(Escape-LuaString $m.name)`",")
    [void]$builder.AppendLine("        objectives = `"$(Escape-LuaString $m.objectives)`",")
    [void]$builder.AppendLine("        missionDescription = `"$(Escape-LuaString $m.missionDescription)`",")
    [void]$builder.AppendLine("        tacticalAdvice = `"$(Escape-LuaString $m.tacticalAdvice)`",")
    [void]$builder.AppendLine("        bugs = `"$(Escape-LuaString $m.bugs)`",")
    [void]$builder.AppendLine("        delvingEnabled = " + ($(if ($m.delvingEnabled) { "true" } else { "false" })) + ",")
    [void]$builder.AppendLine("        difficulty = `"$(Escape-LuaString $m.difficulty)`",")
    [void]$builder.AppendLine("        difficultyDetails = `"$(Escape-LuaString $m.difficultyDetails)`",")
    [void]$builder.AppendLine("        timeRange = `"$(Escape-LuaString $m.timeRange)`",")
    [void]$builder.AppendLine("        timeAssessment = `"$(Escape-LuaString $m.timeAssessment)`"")
    [void]$builder.AppendLine("    },")
}

[void]$builder.AppendLine("}")
[void]$builder.AppendLine("")
[void]$builder.AppendLine("function MissionData:GetMissionInfo(missionName)")
[void]$builder.AppendLine("    return self.Missions[missionName]")
[void]$builder.AppendLine("end")
[void]$builder.AppendLine("")
[void]$builder.AppendLine("function MissionData:HasMission(missionName)")
[void]$builder.AppendLine("    return self.Missions[missionName] ~= nil")
[void]$builder.AppendLine("end")
[void]$builder.AppendLine("")
[void]$builder.AppendLine("function MissionData:GetMissionCount()")
[void]$builder.AppendLine("    local count = 0")
[void]$builder.AppendLine("    for _ in pairs(self.Missions) do")
[void]$builder.AppendLine("        count = count + 1")
[void]$builder.AppendLine("    end")
[void]$builder.AppendLine("    return count")
[void]$builder.AppendLine("end")

$utf8NoBom = New-Object System.Text.UTF8Encoding($false)
$outputFullPath = Join-Path -Path (Resolve-Path -Path ".").Path -ChildPath $OutputPath
[System.IO.File]::WriteAllText($outputFullPath, $builder.ToString(), $utf8NoBom)

Write-Host "Generated $OutputPath with $($orderedNames.Count) missions."
