param(
    [string]$RepositoryRoot = (Split-Path -Parent $PSScriptRoot),
    [string]$ConfigPath,
    [ValidateRange(1,65535)][int]$Port = 4317
)
$ErrorActionPreference = 'Stop'
$RepositoryRoot = (Resolve-Path -LiteralPath $RepositoryRoot).Path
$nodePath = (Get-Command node -ErrorAction Stop).Source
$desktopRoot = Join-Path $env:LOCALAPPDATA 'Mousecat/Desktop'
$binPath = Join-Path $desktopRoot 'app'
$projectPath = Join-Path $RepositoryRoot 'apps/mousecat-desktop/Mousecat.Desktop.csproj'
New-Item -ItemType Directory -Force -Path $desktopRoot | Out-Null
if (-not $ConfigPath) {
    $localConfig = Join-Path $RepositoryRoot 'mousecat.config.json'
    if (Test-Path -LiteralPath $localConfig) { $ConfigPath = $localConfig }
    else {
        $ConfigPath = Join-Path $desktopRoot 'runtime.json'
        if (-not (Test-Path -LiteralPath $ConfigPath)) {
            @{state=@{enabled=$true;path=(Join-Path $desktopRoot 'state.json')}} |
                ConvertTo-Json -Depth 4 | Set-Content -LiteralPath $ConfigPath -Encoding UTF8
        }
    }
}
$ConfigPath = (Resolve-Path -LiteralPath $ConfigPath).Path
$config = Get-Content -LiteralPath $ConfigPath -Raw | ConvertFrom-Json
if ($config.state.enabled -ne $true) { throw 'The selected configuration must enable local state so questions survive restarts.' }
$selectedDesktopExecutable = [IO.Path]::GetFullPath((Join-Path $binPath 'Mousecat.exe'))
$running = @(Get-Process -Name Mousecat -ErrorAction SilentlyContinue | Where-Object {
    # Mousecat's separate Electron app can share the historical executable name.
    # An unavailable path stays conservative; a known different app does not block this update.
    try { $candidateExecutable = $_.Path } catch { $candidateExecutable = $null }
    (-not $candidateExecutable) -or [string]::Equals(
        [IO.Path]::GetFullPath($candidateExecutable), $selectedDesktopExecutable,
        [StringComparison]::OrdinalIgnoreCase)
})
if ($running) { throw 'Close the Marshmallow desktop window before updating it. The service and saved questions may remain open.' }
& dotnet publish $projectPath -c Release -r win-x64 --self-contained true -o $binPath
if ($LASTEXITCODE -ne 0) { throw 'Desktop build failed; shortcuts were not updated.' }
@{RepositoryRoot=$RepositoryRoot;NodePath=$nodePath;ConfigPath=$ConfigPath;Port=$Port} |
    ConvertTo-Json | Set-Content -LiteralPath (Join-Path $desktopRoot 'desktop.json') -Encoding UTF8
$shell = New-Object -ComObject WScript.Shell
$locations = @([Environment]::GetFolderPath('Desktop'), [Environment]::GetFolderPath('Programs'))
foreach ($location in $locations) {
    $shortcut = $shell.CreateShortcut((Join-Path $location 'Marshmallow.lnk'))
    $shortcut.TargetPath = Join-Path $binPath 'Mousecat.exe'
    $shortcut.WorkingDirectory = $RepositoryRoot
    $shortcut.Description = 'Marshmallow - questions, plans and decision history'
    $shortcut.Save()
}
Write-Output "Installed Marshmallow desktop and Start menu shortcuts."
Write-Output (Join-Path $binPath 'Mousecat.exe')
