[CmdletBinding()]
param()

$commandArguments = @(
    '-ExecutionPolicy Bypass',
    '-NonInteractive',
    '-WindowStyle Hidden',
    '-NoProfile',
    "-File `"$env:BIN/software/podman/cache-all-digests-from-microsoft-container-registry.ps1`""
)
$action = New-ScheduledTaskAction -Execute 'pwsh.exe' -Argument "$commandArguments"
$settings = New-ScheduledTaskSettingsSet -ExecutionTimeLimit ([timespan]::FromMinutes(10))

$stateChangeTrigger = Get-CimClass -Namespace 'ROOT\Microsoft\Windows\TaskScheduler' -ClassName 'MSFT_TaskSessionStateChangeTrigger'
$taskSessionUnlockId = 8
$triggerProperties = @{
    StateChange = $taskSessionUnlockId
}
$trigger = New-CimInstance -CimClass $stateChangeTrigger -Property $triggerProperties -ClientOnly

$registerArguments = @{
    TaskName = 'Cache Microsoft Container Registry Digests'
    TaskPath = 'Personal'
    Action = $action
    Settings = $settings
    Trigger = $trigger
    Force = $true
}
Register-ScheduledTask @registerArguments
