#Requires -Version 5.1
# HKK R206: USER PC READ-ONLY app/data preflight, never backup or install here.
# No paths, settings contents, API keys, media names or usernames leave this PC.
$ErrorActionPreference = 'Stop'
$marker = 'HKK_R206_USER_01426_READONLY_PREFLIGHT_V1'
$appId = '{29C3BC91-33AB-4712-86B5-6DCE724E72F0}_is1'
$regPath = 'Software\Microsoft\Windows\CurrentVersion\Uninstall\' + $appId
$guiExpected = 'dc846543b087e5cb3b7bc2647a9eacaab78070e8ce54d3059ee9b2aacb93d489'
$workerExpected = '13e6f00f5720fc099fe8b423bce829a85f7392da05e72cfa3c94c560e7810bfb'
$phase = 'REGISTRY'
$status = 'BLOCKED'
$reason = 'UNCLASSIFIED'
$details = @{}
function SafeNameValue([string]$value) {
    return ($value -match '^[A-Z0-9_]{2,70}$')
}
function IsSafeFile([string]$path) {
    if (-not (Test-Path -LiteralPath $path -PathType Leaf)) {return $false}
    $item = Get-Item -LiteralPath $path -ErrorAction Stop
    return (-not ($item.Attributes -band [IO.FileAttributes]::ReparsePoint))
}
function ClassifyHash([string]$path,[string]$expected) {
    if (-not (IsSafeFile $path)) {return 'MISSING_OR_UNSAFE'}
    $actual = (Get-FileHash -LiteralPath $path -Algorithm SHA256 -ErrorAction Stop).Hash.ToLowerInvariant()
    if ($actual -ceq $expected) {return 'PINNED'}
    return 'DIFFERENT'
}
try {
    if ([Environment]::OSVersion.Platform -ne [PlatformID]::Win32NT) {throw 'WINDOWS_ONLY'}
    $entries = @()
    foreach ($hive in @([Microsoft.Win32.RegistryHive]::CurrentUser,
                        [Microsoft.Win32.RegistryHive]::LocalMachine)) {
        foreach ($view in @([Microsoft.Win32.RegistryView]::Registry64,
                            [Microsoft.Win32.RegistryView]::Registry32)) {
            $base = $null
            $key = $null
            try {
                $base = [Microsoft.Win32.RegistryKey]::OpenBaseKey($hive,$view)
                $key = $base.OpenSubKey($regPath,$false)
                if ($null -ne $key) {
                    $entries += [pscustomobject]@{
                        version=[string]$key.GetValue('DisplayVersion')
                        install=[string]$key.GetValue('InstallLocation')
                        appPath=[string]$key.GetValue('Inno Setup: App Path')
                        uninstall=[string]$key.GetValue('UninstallString')
                    }
                }
            } finally {
                if ($null -ne $key) {$key.Close()}
                if ($null -ne $base) {$base.Close()}
            }
        }
    }
    if ($entries.Count -eq 0) {throw 'INNO_APPID_NOT_FOUND'}
    $unique = @($entries | ForEach-Object {$_ | ConvertTo-Json -Compress} | Sort-Object -Unique)
    if ($unique.Count -ne 1) {throw 'INNO_REGISTRY_VIEWS_CONFLICT'}
    $found = $entries[0]
    if ($found.version -cne '0.14.26') {throw 'CURRENT_VERSION_NOT_01426'}
    $details['VERSION'] = '01426'
    if (-not $found.install -or -not $found.appPath -or
        $found.install.TrimEnd('\') -ine $found.appPath.TrimEnd('\')) {
        throw 'INNO_INSTALL_LOCATION_MISMATCH'
    }
    $root = [IO.Path]::GetFullPath($found.install.TrimEnd('\'))
    if (-not (Test-Path -LiteralPath $root -PathType Container)) {
        throw 'INSTALL_FOLDER_MISSING'
    }
    $item = Get-Item -LiteralPath $root
    if ($item.Attributes -band [IO.FileAttributes]::ReparsePoint) {throw 'INSTALL_FOLDER_REPARSE'}
    $standard = Join-Path $env:LOCALAPPDATA 'Programs\Hankkuku-P25BC-R14-Review'
    $details['INSTALL_ROOT_STANDARD'] = if($root -ieq $standard){'YES'}else{'NO'}
    $un = $found.uninstall.Trim()
    if ($un.StartsWith('"')) {
        $last = $un.IndexOf('"',1)
        if ($last -lt 2) {throw 'UNINSTALL_PATH_INVALID'}
        $un = $un.Substring(1,$last-1)
    } else {
        $un = ($un -split '\s+\/')[0]
    }
    if ($un -notmatch '\\unins[0-9]{3,}\.exe$' -or -not (IsSafeFile $un) -or
        [IO.Path]::GetDirectoryName($un).TrimEnd('\') -ine $root.TrimEnd('\')) {
        throw 'INNO_UNINSTALLER_NOT_TRUSTED'
    }
    $details['UNINSTALLER_PRESENT'] = 'YES'
    $phase = 'BINARIES'
    $details['GUI_SHA'] = ClassifyHash (Join-Path $root 'app\HankkukuP25BCReview.exe') $guiExpected
    $details['WORKER_SHA'] = ClassifyHash (Join-Path $root 'Updater\HKK_UpdateRunner.exe') $workerExpected
    if ($details['GUI_SHA'] -cne 'PINNED' -or $details['WORKER_SHA'] -cne 'PINNED') {
        throw 'INSTALLED_BINARIES_DIFFERENT_FROM_PIN'
    }
    $running = @(Get-Process -Name 'HankkukuP25BCReview','HKK_UpdateRunner' -ErrorAction SilentlyContinue)
    $details['APP_RUNNING'] = if($running.Count -gt 0){'YES'}else{'NO'}

    $phase = 'DATA_LOCATIONS'
    $home = Join-Path $env:LOCALAPPDATA 'HankkukuRealEstate'
    $details['DEFAULT_HOME_PRESENT'] = if(Test-Path -LiteralPath $home -PathType Container){'YES'}else{'NO'}
    $dataDirs = @()
    if ($details['DEFAULT_HOME_PRESENT'] -eq 'YES') {
        $dataDirs += $home
        $cfg = Join-Path $home 'settings.json'
        if (IsSafeFile $cfg) {
            $item = Get-Item -LiteralPath $cfg
            if ($item.Length -gt 0 -and $item.Length -lt 1048576) {
                try {
                    $obj = Get-Content -LiteralPath $cfg -Raw -Encoding UTF8 | ConvertFrom-Json -ErrorAction Stop
                    if ($obj -and ($obj.PSObject.Properties.Name -contains 'data_dir') -and
                        $obj.data_dir -is [string] -and $obj.data_dir) {
                        $dataDirs += [Environment]::ExpandEnvironmentVariables([string]$obj.data_dir)
                        $details['CUSTOM_DATA_PATH_IN_SETTINGS'] = 'YES'
                    }
                } catch {
                    $details['SETTINGS_PARSE'] = 'FAILED'
                }
            }
        }
    }
    if (-not $details.ContainsKey('CUSTOM_DATA_PATH_IN_SETTINGS')) {
        $details['CUSTOM_DATA_PATH_IN_SETTINGS'] = 'NO'
    }
    if (-not $details.ContainsKey('SETTINGS_PARSE')) {$details['SETTINGS_PARSE']='NOT_FAILED'}
    if ($env:HANKKUKU_DATA_DIR) {
        $dataDirs += $env:HANKKUKU_DATA_DIR
        $details['DATA_ENV_OVERRIDE'] = 'YES'
    } else {$details['DATA_ENV_OVERRIDE'] = 'NO'}

    $dbfound = 0
    foreach ($dir in @($dataDirs | Select-Object -Unique)) {
        try {
            $db = Join-Path $dir 'fieldbook.sqlite3'
            if (IsSafeFile $db) { $dbfound++ }
        } catch {}
    }
    $details['DATABASE_FILE_COUNT'] = [string][Math]::Min(9,$dbfound)
    $extra = Join-Path $env:LOCALAPPDATA 'Hankkuku\P25BB_R5_ReviewData\P25K_PREVIEW_USER'
    $details['R5_PROFILE_PRESENT'] = if(Test-Path -LiteralPath $extra -PathType Container){'YES'}else{'NO'}
    $details['BACKUP_STATUS'] = 'NOT_PERFORMED'
    $details['EXTERNAL_MEDIA_SCOPE'] = 'NOT_VERIFIED'
    $details['DATABASE_INTEGRITY'] = 'NOT_TESTED'
    $details['RESTORE_CHECK'] = 'NOT_PERFORMED'
    $details['PC_UPDATE'] = 'NOT_STARTED'
    $phase='COMPLETE'
    $status='PASS_READONLY_SCOPE_DISCOVERY'
    $reason='NONE'
} catch {
    $msg = [string]$_.Exception.Message
    if ($msg -match '^[A-Z0-9_]{4,90}$') {$reason=$msg}
    else {$reason='UNEXPECTED_LOCAL_ONLY'}
}
$body = @($marker,('RESULT='+$status),('PHASE='+$phase),('REASON='+$reason),
    'INSTALL=NO','BACKUP=NO','USER_FILES_MODIFIED=NO_BY_SCRIPT',
    'PUBLICATION=NO','SUCCESS_BRIDGE=UNMODIFIED')
foreach($key in @($details.Keys | Sort-Object)) {
    $val = [string]$details[$key]
    if ((SafeNameValue $key) -and ($val -match '^[A-Z0-9_]{1,70}$')) {
        $body += ($key + '=' + $val)
    }
}
$report = $body -join [Environment]::NewLine
Write-Host $report

# Opt-in-free report delivery through an ALREADY AUTHENTICATED GH CLI only.
# On a PC without GH this is intentionally local only: never ask for secrets.
$sent = 'NO'
$gh = Get-Command gh.exe -ErrorAction SilentlyContinue
if ($null -ne $gh) {
    try {
        $login = (& $gh.Source api user --jq '.login' 2>$null | Out-String).Trim()
        $private = (& $gh.Source api 'repos/dngusdprp-creator/common-project-bridge' --jq '.private' 2>$null | Out-String).Trim()
        if ($LASTEXITCODE -eq 0 -and $login -ceq 'dngusdprp-creator' -and $private -ceq 'true') {
            & $gh.Source api -X POST 'repos/dngusdprp-creator/common-project-bridge/issues/6/comments' -f "body=$report" --silent 2>$null | Out-Null
            if ($LASTEXITCODE -eq 0) {$sent='YES'}
        }
    } catch {}
}
Write-Host ('GITHUB_RESULT_POSTED='+$sent)
if ($status -ne 'PASS_READONLY_SCOPE_DISCOVERY') { exit 1 }
