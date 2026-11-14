#Requires -Version 5.1
# R207: read-only Windows Inno uninstall registry version diagnosis.
# No install/backup/registry mutation and no private PC paths in report.
$ErrorActionPreference = 'Stop'
$marker = 'HKK_R207_01426_VERSION_MISMATCH_READONLY_V1'
$repo = 'dngusdprp-creator/common-project-bridge'
$regPath = 'Software\Microsoft\Windows\CurrentVersion\Uninstall\{29C3BC91-33AB-4712-86B5-6DCE724E72F0}_is1'
$phase = 'REGISTRY'
$result = 'BLOCKED'
$reason = 'UNCLASSIFIED'
$detail = @{}
try {
    $entries = @()
    foreach ($hive in @([Microsoft.Win32.RegistryHive]::CurrentUser,[Microsoft.Win32.RegistryHive]::LocalMachine)) {
        foreach ($view in @([Microsoft.Win32.RegistryView]::Registry64,[Microsoft.Win32.RegistryView]::Registry32)) {
            $base = $null
            $key = $null
            try {
                $base = [Microsoft.Win32.RegistryKey]::OpenBaseKey($hive,$view)
                $key = $base.OpenSubKey($regPath,$false)
                if ($null -ne $key) {
                    $ver = [string]$key.GetValue('DisplayVersion','')
                    $root = [string]$key.GetValue('InstallLocation','')
                    $inno = [string]$key.GetValue('Inno Setup: App Path','')
                    $entries += [pscustomobject]@{Version=$ver;Root=$root;Inno=$inno}
                }
            } finally {
                if ($null -ne $key) {$key.Close()}
                if ($null -ne $base) {$base.Close()}
            }
        }
    }
    $detail['INNO_REGISTRY_VIEWS'] = [string]$entries.Count
    if ($entries.Count -eq 0) {throw 'INNO_IDENTITY_MISSING'}
    $values = @($entries | ForEach-Object {$_.Version.Trim()} | Sort-Object -Unique)
    $detail['UNIQUE_VERSION_COUNT'] = [string]$values.Count
    if ($values.Count -ne 1) {throw 'INSTALLED_VERSION_CONFLICT_ACROSS_VIEWS'}
    $value = [string]$values[0]
    if ($value -match '^[0-9]{1,3}(\.[0-9]{1,3}){1,4}$') {
        $detail['VERSION_VALUE'] = $value
    } else {
        $detail['VERSION_VALUE'] = 'NON_NUMERIC_FORMAT'
    }
    $detail['VERSION_MATCH_01426'] = if($value -ceq '0.14.26'){'YES'}else{'NO'}
    $detail['VERSION_IS_01427'] = if($value -ceq '0.14.27'){'YES'}else{'NO'}
    $detail['VERSION_IS_01428'] = if($value -ceq '0.14.28'){'YES'}else{'NO'}
    $detail['VERSION_01426_PREFIX'] = if($value -match '^0\.14\.26(\.|[^0-9]|$)'){'YES'}else{'NO'}
    $paths = @($entries | ForEach-Object {
        ([string]$_.Root).TrimEnd('\') + '|' + ([string]$_.Inno).TrimEnd('\')
    } | Sort-Object -Unique)
    $detail['UNIQUE_INSTALL_PATH_PAIR_COUNT'] = [string]$paths.Count
    $standard = Join-Path $env:LOCALAPPDATA 'Programs\Hankkuku-P25BC-R14-Review'
    $paths_match = @($entries | Where-Object {
        $_.Root -and $_.Inno -and
        $_.Root.TrimEnd('\') -ieq $_.Inno.TrimEnd('\')
    })
    $detail['INNO_PATH_FIELDS_MATCH'] = if($paths_match.Count -eq $entries.Count){'YES'}else{'NO'}
    $std = @($entries | Where-Object {
        $_.Root -and $_.Root.TrimEnd('\') -ieq $standard.TrimEnd('\')
    })
    $detail['DEFAULT_APP_ROOT'] = if($std.Count -eq $entries.Count){'YES'}else{'NO'}
    $phase = 'COMPLETE'
    $result = 'PASS_VERSION_OBSERVED_ONLY'
    $reason = 'NONE'
} catch {
    $code = [string]$_.Exception.Message
    if ($code -match '^[A-Z0-9_]{4,90}$') {$reason=$code} else {$reason='REGISTRY_READ_ERROR_LOCAL_ONLY'}
}
$lines = @($marker,('RESULT='+$result),('PHASE='+$phase),('REASON='+$reason),
    'INSTALL=NO','BACKUP=NO','FILES_MODIFIED=NO_BY_SCRIPT',
    'PUBLICATION=NO','SUCCESS_BRIDGE=UNMODIFIED')
foreach($key in @($detail.Keys | Sort-Object)) {
    $val = [string]$detail[$key]
    if ($key -match '^[A-Z0-9_]{3,60}$' -and $val -match '^[A-Z0-9_.]{1,60}$') {
        $lines += ($key + '=' + $val)
    }
}
$report = $lines -join [Environment]::NewLine
Write-Host $report
$sent = 'NO'
$gh = Get-Command gh.exe -ErrorAction SilentlyContinue
if ($null -ne $gh) {
    try {
        $login = (& $gh.Source api user --jq '.login' 2>$null | Out-String).Trim()
        $private = (& $gh.Source api ('repos/'+$repo) --jq '.private' 2>$null | Out-String).Trim()
        if ($LASTEXITCODE -eq 0 -and $login -ceq 'dngusdprp-creator' -and $private -ceq 'true') {
            & $gh.Source api -X POST ('repos/'+$repo+'/issues/6/comments') -f "body=$report" --silent 2>$null | Out-Null
            if ($LASTEXITCODE -eq 0) {$sent='YES'}
        }
    } catch {}
}
Write-Host ('GITHUB_RESULT_POSTED='+$sent)
if ($result -ne 'PASS_VERSION_OBSERVED_ONLY') {exit 1}
