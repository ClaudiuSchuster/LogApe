### LogApe - Provides advanced logging functionalities with ease of use (e.g. Colors in Pipelines & Shells and optionally additional LogFile Output)
param (
    # To enable module debug messages: Import-Module LogApe -ArgumentList $true
    [bool] $global:ModuleDebugMessages = [bool]($global:ModuleDebugMessages)
)

### Write-Host PSM-BEGIN if ModuleDebugMessages:$true
if ($global:ModuleDebugMessages) { Write-Host "`e[90m$(Get-Date -Format 'yyyy-MM-dd HH:mm:ss.fff') DBUG: [$($MyInvocation.MyCommand.Name -replace '\.\w+$', '')] [$($MyInvocation.MyCommand.Name)] PowerShellModule ~ BEGIN ~`e[0m" }


### Enums
enum LogLevelMsg { NOTE = 0; INFO = 1; WARN = 2; DBUG = 3; ERRR = 4; }
enum LogLevelColor { Ansi92 = 0; Ansi97 = 1; Ansi93 = 2; Ansi90 = 3; Ansi31 = 4; } # Ansi92=Green, Ansi97=White, Ansi93=Yellow, Ansi90=Gray, Ansi31=Red
enum LogMsgColorAlias { Green = 0; White = 1; Yellow = 2; Gray = 3; Red = 4; }


### Class 'LogApe'
class LogApe {

    ### Constructor - Init configuration from provided config object
    LogApe([object]$Config, [psobject]$Parent, [psobject]$CParent, [string]$LogFile, [string]$UseDateCulture, [hashtable]$ErrorLevelMsgMapping, [bool]$MsecLogDisabled, [bool]$DebugOutput) {
        try {
            $this.SetConfig($Config)
            if ($UseDateCulture -And $this.config.DateCulture -ne $UseDateCulture) { $this.SetConfig(@{ DateCulture = $UseDateCulture }) }
            if ($DebugOutput -And $this.config.Debug -ne $DebugOutput) { $this.SetConfig(@{ Debug = $DebugOutput }) }
            if ($LogFile -And $this.config.LogFile -ne $LogFile) { $this.SetConfig(@{ LogFile = $LogFile }) }
            if ($MsecLogDisabled -And $this.config.MsecLog -ne (-Not $MsecLogDisabled)) { $this.SetConfig(@{ MsecLog = (-Not $MsecLogDisabled) }) }
            if ($Parent -And $this.config.Parent -ne ($Parent.GetType().IsArray ? $Parent[0] : $Parent) ) { $this.SetConfig(@{ Parent = ($Parent.GetType().IsArray ? $Parent[0] : $Parent) }) }
            if (-Not $CParent -And $Parent -And $this.config.ParentColor -ne ($Parent.GetType().IsArray ? $Parent[1] : $null) ) { $this.SetConfig(@{ ParentColor = ($Parent.GetType().IsArray ? $Parent[1] : $null) }) }
            if ($CParent -And $this.config.ParentColor -ne $CParent) { $this.SetConfig(@{ ParentColor = $CParent }) }
            if ($ErrorLevelMsgMapping) { $this.SetConfig(@{ ErrorLevelMsgMapping = $ErrorLevelMsgMapping }) }
        } catch { [LogApe]::PrintStopError("[$((Get-PSCallStack).FunctionName[0])([object])] Constructor failed! Exception: $_") }
        [LogApe]::PrintDebug("[$((Get-PSCallStack).FunctionName[0])([object])] Initialized LogApe instance with configuration", $this.GetConfig(), 2)
    }

    ### Class & Instance objects
    hidden static [hashtable] $dtFormat = @{ dateCulture = 'en-CA'; date = 'yyyy-MM-dd'; time = 'HH:mm:ss'; }
    hidden [hashtable] $config = $this.GetConfig()

    ### Class Methods for logging, text-resources loading/translation and configuration merge
    hidden static [string] getDateTimeByCulture([string]$TrailingTimePattern) { return [LogApe]::getDateTimeByCulture($TrailingTimePattern, $null) }
    hidden static [string] getDateTimeByCulture([string]$TrailingTimePattern, [string]$Culture) {
        if ($Culture -And ([LogApe]::dtFormat.dateCulture -ne $Culture)) {
            $oldDtFormat = @{ dateCulture = [LogApe]::dtFormat.dateCulture; date = [LogApe]::dtFormat.date }
            [LogApe]::dtFormat.dateCulture = $Culture
            [LogApe]::dtFormat.date = (Get-Culture -Name $Culture).DateTimeFormat.ShortDatePattern
            [LogApe]::PrintDebug("[getDateTimeByCulture(TrailingTimePattern='$TrailingTimePattern',Culture='$Culture')] " `
                    + "Changed DateFormat. New: '$Culture'='$([LogApe]::dtFormat.date)'. Old: '$($oldDtFormat.dateCulture)'='$($oldDtFormat.date)'.")
        }
        return (Get-Date -Format $([LogApe]::dtFormat.date + ' ' + [LogApe]::dtFormat.time + ($TrailingTimePattern ? $TrailingTimePattern : '')))
    }
    hidden static [string] formatObjectToShortJson([psobject]$InputObject) { return [LogApe]::getDateTimeByCulture($InputObject, 1) }
    hidden static [string] formatObjectToShortJson([psobject]$InputObject, [int]$Depth) {
        $formatedObj = '    ' + (($InputObject | ConvertTo-Json -Depth $Depth) `
                -replace '(?:([\[\{])\r?\n\s*|\r?\n\s*([\]\}])|([^\]\}]"?,)\r?\n\s*)', '$3$1 $2').Replace("`n", "`n    ")
        [bool]$isSingleArray = $InputObject.GetType().IsArray -And ($InputObject).Count -eq 1
        [bool]$isMultiLine = ($formatedObj | Measure-Object -Line).Lines -gt 1
        return ($isSingleArray ? "[`r`n    " : '') + ($isMultiLine ? "`r`n$formatedObj" : $formatedObj.Trim()) + ($isSingleArray ? ' ]' : '')
    }
    hidden static [string] print([psobject]$Msg, [string]$DateTime, [byte]$ErrLvl, [psobject]$DebugObject) { return [LogApe]::print($Msg, $DateTime, $ErrLvl, $DebugObject, '', '', $null) }
    hidden static [string] print([psobject]$Msg, [string]$DateTime, [byte]$ErrLvl, [psobject]$DebugObject, [psobject]$MsgTrail, [psobject]$MsgTail, [hashtable]$ErrorLevelMsgMapping) {
        if ($ErrLvl -ge 5) { $ErrLvl = 4 }
        [array]$_msg = $MsgTrail, $Msg, $MsgTail | ForEach-Object {
            $_concat = ''
            $_.GetType().IsArray -And $_.Count -eq 2 -And $_[0] -is [string] -And ($_[1] -is [string] -Or $_[1] -is [int]) ? , $_ : $_ | ForEach-Object {
                $t = $_.GetType().Name
                if ($t -eq 'String') {
                    $_concat += "`e[$(([LogLevelColor]$ErrLvl).ToString().Replace('Ansi',''))m$_`e[0m"
                } elseif ($_.GetType().IsArray) {
                    $m = [string]($_[0] ? $_[0] : '')
                    if ($m -And ($_[1] -Or $_[1] -is [int])) {
                        $c = ($_[1] -Or $_[1] -is [int]) ? $_[1] : $null
                        if (($c -Or $c -is [int]) -And ([System.Enum]::GetValues([LogMsgColorAlias]) -contains $c -Or ([System.Enum]::GetValues([LogMsgColorAlias]) | ForEach-Object { [int]($_) }) -contains $c)) {
                            $m.Split("`n") | ForEach-Object { $_concat += "`e[0m`e[$(([LogLevelColor][int]([LogMsgColorAlias]$c)).ToString().Replace('Ansi',''))m$($_.Replace("`r",''))" }
                            $_concat += "`e[0m"
                        } else {
                            [LogApe]::PrintWarning("Wrong Color '$c' at _log([Array[]]`$Msg, ...)!")
                            $_concat += "`e[$(([LogLevelColor]$ErrLvl).ToString().Replace('Ansi',''))m$m`e[0m"
                        }
                    } elseif ($m -ne '') {
                        $_concat += "`e[$(([LogLevelColor]$ErrLvl).ToString().Replace('Ansi',''))m$m`e[0m"
                    }
                } elseif ($t -eq 'OrderedDictionary' -Or $t -eq 'Hashtable' -Or $t -eq 'PSCustomObject' -Or $t -match "Object*") {
                    $m = [string]($_.Msg ? $_.Msg : $_.msg ? $_.msg : '')
                    if ($m -And ($_.Color -Or $_.Color -is [int]) -Or ($_.color -Or $_.color -is [int])) {
                        $c = ($_.Color -Or $_.Color -is [int]) ? $_.Color : ($_.color -Or $_.color -is [int]) ? $_.color : $null
                        if (($c -Or $c -is [int]) -And ([System.Enum]::GetValues([LogMsgColorAlias]) -contains $c -Or ([System.Enum]::GetValues([LogMsgColorAlias]) | ForEach-Object { [int]($_) }) -contains $c)) {
                            $m.Split("`n") | ForEach-Object { $_concat += "`e[0m`e[$(([LogLevelColor][int]([LogMsgColorAlias]$c)).ToString().Replace('Ansi',''))m$($_.Replace("`r",''))" }
                            $_concat += "`e[0m"
                        } else {
                            [LogApe]::PrintWarning("Wrong Color '$c' at _log([Object[]]`$Msg, ...)!")
                            $_concat += "`e[$(([LogLevelColor]$ErrLvl).ToString().Replace('Ansi',''))m$m`e[0m"
                        }
                    } elseif ($m -ne '') {
                        $_concat += "`e[$(([LogLevelColor]$ErrLvl).ToString().Replace('Ansi',''))m$m`e[0m"
                    }
                } else {
                    $_concat += "`e[$(([LogLevelColor]$ErrLvl).ToString().Replace('Ansi',''))m$_`e[0m"
                }
            }
            return $_concat
        }
        $maxErrLvl = (@([Enum]::GetValues([LogLevelMsg]) + [Enum]::GetValues([LogLevelColor])) | ForEach-Object { [int]$_ } | Measure-Object -Maximum).Maximum
        $ErrLvl = $ErrLvl -gt $maxErrLvl ? $maxErrLvl : $ErrLvl
        $_msg = $DateTime `
            + ' ' `
            + ($ErrorLevelMsgMapping ? ( ' ' * (($ErrorLevelMsgMapping[$ErrorLevelMsgMapping.Keys] | Measure-Object -Maximum -Property Length).Maximum - ( `
                            $ErrorLevelMsgMapping[([LogLevelMsg]$ErrLvl).ToString()] ? $ErrorLevelMsgMapping[([LogLevelMsg]$ErrLvl).ToString()] `
                            : $ErrorLevelMsgMapping[[int]$ErrLvl] ? $ErrorLevelMsgMapping[[int]$ErrLvl] `
                            : ([LogLevelMsg]$ErrLvl).ToString()).Length) ) `
                : '') `
            + ($ErrorLevelMsgMapping -And ($ErrorLevelMsgMapping[([LogLevelMsg]$ErrLvl).ToString()] -Or $ErrorLevelMsgMapping[[int]$ErrLvl]) `
                ? ($ErrorLevelMsgMapping[([LogLevelMsg]$ErrLvl).ToString()] ? $ErrorLevelMsgMapping[([LogLevelMsg]$ErrLvl).ToString()] : $ErrorLevelMsgMapping[[int]$ErrLvl]) `
                : ([LogLevelMsg]$ErrLvl).ToString()) `
            + ': ' `
            + $_msg[0] `
            + $_msg[1] `
            + ($DebugObject -And $DebugObject.obj ? (
                "`e[$(([LogLevelColor]$ErrLvl).ToString().Replace('Ansi',''))m: `e[0m" `
                    + [LogApe]::formatObjectToShortJson($DebugObject.obj, $DebugObject.depth)
            ) : '') `
            + $_msg[2]
        $_msg.Split("`n") | ForEach-Object { Write-Host "`e[$(([LogLevelColor]$ErrLvl).ToString().Replace('Ansi',''))m$($_.Replace("`r",''))`e[0m" }
        return $_msg
    }
    static [void] PrintNote([string]$Msg) { [LogApe]::print("[LogApe] $Msg", [LogApe]::getDateTimeByCulture('.fff'), 0, $null) }
    static [void] PrintInfo([string]$Msg) { [LogApe]::print("[LogApe] $Msg", [LogApe]::getDateTimeByCulture('.fff'), 1, $null) }
    static [void] PrintWarning([string]$Msg) { [LogApe]::print("[LogApe] $Msg", [LogApe]::getDateTimeByCulture('.fff'), 2, $null) }
    static [void] PrintDebug([string]$Msg) {
        if ($global:ModuleDebugMessages) { [LogApe]::print("[LogApe] $Msg", [LogApe]::getDateTimeByCulture('.fff'), 3, $null) }
    }
    static [void] PrintDebug([string]$Msg, [PSObject]$DebugObject) {
        if ($global:ModuleDebugMessages) { [LogApe]::print("[LogApe] $Msg", [LogApe]::getDateTimeByCulture('.fff'), 3, @{ obj = $DebugObject; depth = 1; }) }
    }
    static [void] PrintDebug([string]$Msg, [PSObject]$DebugObject, [int]$Depth) {
        if ($global:ModuleDebugMessages) { [LogApe]::print("[LogApe] $Msg", [LogApe]::getDateTimeByCulture('.fff'), 3, @{ obj = $DebugObject; depth = $Depth; }) }
    }
    static [void] PrintError([string]$Msg) { [LogApe]::print("[LogApe] $Msg", [LogApe]::getDateTimeByCulture('.fff'), 5, $null) }
    static [void] PrintStopError([string]$Msg) {
        [LogApe]::print("[LogApe] $Msg", [LogApe]::getDateTimeByCulture('.fff'), 5, $null)
        throw "[LogApe] $Msg"
    }
    hidden [void] mergeConfig([hashtable]$newConfig) {
        if ($global:ModuleDebugMessages) { $this.config.Debug = $global:ModuleDebugMessages }
        $counts = @{ totalKeyCount = 0; modifiedkeyCount = 0; untouchedKeyCount = 0; }
        foreach ($key in $newConfig.Keys) {
            if ($this.config.ContainsKey($key)) {
                $counts.totalKeyCount++;
                if (($null -eq $this.config[$key] -And $null -ne $newConfig[$key]) `
                        -Or ($null -ne $this.config[$key] -And $null -eq $newConfig[$key]) `
                        -Or ($key -eq 'ErrorLevelMsgMapping') `
                        -Or (Compare-Object -ReferenceObject $this.config[$key] -DifferenceObject $newConfig[$key])
                ) {
                    $this.config[$key] = $newConfig[$key]
                    $counts.modifiedkeyCount++
                } else { $counts.untouchedKeyCount++ }
            } else { [LogApe]::PrintWarning("[$((Get-PSCallStack).FunctionName[0])([hashtable])] Key '$key' not suitable for configuration!") }
        }
        if ($this.config.IsModuleDefault -And $counts.modifiedkeyCount -gt 0) { $this.config.Remove('IsModuleDefault') }
        if (($newConfig.Keys).Count) {
            if (-Not $counts.modifiedkeyCount -And -Not $counts.untouchedKeyCount) {
                [LogApe]::PrintWarning("[$((Get-PSCallStack).FunctionName[0])([hashtable])] " `
                        + "0 of provided $(($newConfig.Keys).Count) keys merged to config!")
            } else {
                [LogApe]::PrintDebug("[$((Get-PSCallStack).FunctionName[0])([hashtable])] " `
                        + "Merged $($counts.totalKeyCount) of provided $(($newConfig.Keys).Count) config keys: " `
                        + "$($counts.modifiedkeyCount) modified, $($counts.untouchedKeyCount) already existing.")
            }
        }
    }
    hidden [void] _log([psobject]$Msg, [byte]$ErrLvl = 1, [psobject]$DebugObject = $null) { $this._log($Msg, $ErrLvl, $DebugObject, '') }
    hidden [void] _log([psobject]$Msg, [byte]$ErrLvl = 1, [psobject]$DebugObject = $null, [psobject]$MsgTail = '') {
        if ($ErrLvl -eq 3 -And -Not $global:ModuleDebugMessages -And -Not $this.config.Debug) { return }
        $_msg = [LogApe]::print($Msg,
            [LogApe]::getDateTimeByCulture(
                (-Not $this.config -Or $this.config.MsecLog ? '.fff' : ''),
                ((-Not $this.config -Or $this.config.IsModuleDefault) ? $null : $this.config.DateCulture ? $this.config.DateCulture : (Get-Culture).Name)
            ),
            $ErrLvl,
            $DebugObject,
            ($this.config.Parent ? $this.config.ParentColor -Or $this.config.ParentColor -is [int] ? @("[$($this.config.Parent)] ", $this.config.ParentColor) : "[$($this.config.Parent)] " : ''),
            $MsgTail,
            $this.config.ErrorLevelMsgMapping
        )
        if ($this.config.LogFile) { $_msg | Out-File -Path $this.config.LogFile -Append -Force -Encoding utf8BOM }
        if ($ErrLvl -ge 5) { throw $_msg }
    }


    ### Public Instance Logging Methods
    # Alias for LogInfo([psobject]$Msg)
    [void] Log([psobject]$Msg) { $this.LogInfo($Msg) }
    # Write Note message to screen and logfile (if configured), (ForegroundColor Green)
    [void] LogNote([psobject]$Msg) { $this._log($Msg, 0, $null) }
    # Write Info message to screen and logfile (if configured), (ForegroundColor White)
    [void] LogInfo([psobject]$Msg) { $this._log($Msg, 1, $null) }
    # Alias for LogWarning([psobject]$Msg)
    [void] LogWarn([psobject]$Msg) { $this.LogWarning($Msg) }
    # Write Warning message to screen and logfile (if configured), (ForegroundColor Yellow)
    [void] LogWarning([psobject]$Msg) { $this._log($Msg, 2, $null) }
    # Write Debug message to screen and logfile (if configured), (ForegroundColor Gray)
    # Optional as 2nd paramter a PsObject which will be formatted to short-JSON can be supplied.
    # Optional as 3rd paramater the JSON convert depth can be supplied.
    [void] LogDebug([psobject]$Msg) { $this._log($Msg, 3, $null) }
    [void] LogDebug([psobject]$Msg, [PSObject]$DebugObject) { $this._log($Msg, 3, @{ obj = $DebugObject; depth = 1; }) }
    [void] LogDebug([psobject]$Msg, [PSObject]$DebugObject, [int]$Depth) { $this._log($Msg, 3, @{ obj = $DebugObject; depth = $Depth; }) }
    # Write a object for debug purpose as short-json to screen with optional ErrLvl specified
    [void] LogObject([psobject]$Msg, [PSObject]$DebugObject) { $this.LogObject($Msg, $DebugObject, 22) }
    [void] LogObject([psobject]$Msg, [PSObject]$DebugObject, [int]$Depth) { $this.LogObject($Msg, $DebugObject, $Depth, 1) }
    [void] LogObject([psobject]$Msg, [PSObject]$DebugObject, [int]$Depth, [byte]$ErrLvl) { $this._log($Msg, $ErrLvl, @{ obj = $DebugObject; depth = $Depth; }) }
    [void] LogObject([psobject]$Msg, [PSObject]$DebugObject, [int]$Depth, [byte]$ErrLvl, [psobject]$MsgTail) { $this._log($Msg, $ErrLvl, @{ obj = $DebugObject; depth = $Depth; }, $MsgTail) }
    # Write Error Message to Screen and Logfile (if configured), (ForegroundColor Red)
    [void] LogError([psobject]$Msg) { $this._log($Msg, 4, $null) }
    # Write Exception Information to Screen and Logfile (if configured), (ForegroundColor Red)
    [void] LogError([System.Management.Automation.ErrorRecord]$E) {
        $this.LogError(
            "$(Split-Path $E.InvocationInfo.ScriptName -Leaf)[$($E.InvocationInfo.ScriptLineNumber)] $($E.InvocationInfo.InvocationName): " `
                + $E.Exception.Message `
                + ($E.Exception.InnerException).Message
        )
    }
    # Throw Error and Write Error Message to Screen and Logfile (if configured), (ForegroundColor Red)
    [void] LogStopError([psobject]$Msg) { $this._log($Msg, 5, $null) }
    # Throw Error and Write Exception Information to Screen and Logfile (if configured), (ForegroundColor Red)
    [void] LogStopError([System.Management.Automation.ErrorRecord]$E) { $this.LogStopError("$(Split-Path $E.InvocationInfo.ScriptName -Leaf)[$($E.InvocationInfo.ScriptLineNumber)] $($E.InvocationInfo.InvocationName): " + $E.Exception.Message + ($E.Exception.InnerException).Message) }
    # Write a empty New-Line (only to screen not to logfile)
    [void] NewLine() { $this.NewLine(1) }
    [void] NewLine([int]$Count) { for ($i = 1; $i -le $Count; $i++) { Write-Host '' } }
    # Write a empty New-Line (only to screen not to logfile) and return the LogApe Instance for further usage, e.g. $LogApe.NewLinePre().Log("Hello")
    [LogApe] NewLinePre() { return $this.NewLinePre(1) }
    [LogApe] NewLinePre([int]$Count) { for ($i = 1; $i -le $Count; $i++) { Write-Host '' }; return $this; }


    ### Public Instance Progress Methods
    # Set (Start or Update) a Progress
    [void] SetProgress([int]$Progress, [int]$TotalProgress, [string]$Action, [string]$Name) {
        $this.SetProgress($Progress, $TotalProgress, "Processing $($this.config.Parent ? "[$($this.config.Parent)] " : '')$Action for '$Name'", $true)
    }
    [void] SetProgress([int]$Progress, [int]$TotalProgress, [string]$Activity) {
        $this.SetProgress($Progress, $TotalProgress, $Activity, $false)
    }
    [void] SetProgress([int]$Progress, [int]$TotalProgress, [string]$Activity, [bool]$NoParent) {
        Write-Progress `
            -Activity "$(($this.config.Parent -And -Not $NoParent) ? "[$($this.config.Parent)] " : '')$Activity" `
            -CurrentOperation "Completed $Progress of $TotalProgress." `
            -PercentComplete (($Progress / $TotalProgress) * 100)
    }
    # Complete the Progress
    [void] FinishProgress() { $this.FinishProgress('*') }
    [void] FinishProgress([string]$Activity) { Write-Progress -Completed -Activity $Activity }


    ### Public Instance VSO Logging Commands for Azure Pipelines - https://docs.microsoft.com/en-us/azure/devops/pipelines/scripts/logging-commands
    # Show percentage completed. Set progress and current operation for the current task.
    [void] VsoSetProgress([int]$Progress, [int]$TotalProgress, [string]$Action, [string]$Name) {
        $this.SetProgress($Progress, $TotalProgress, "Processing $($this.config.Parent ? "[$($this.config.Parent)] " : '')$Action for '$Name'", $true)
    }
    [void] VsoSetProgress([int]$Progress, [int]$TotalProgress, [string]$Activity) {
        $this.SetProgress($Progress, $TotalProgress, $Activity, $false)
    }
    [void] VsoSetProgress([int]$Progress, [int]$TotalProgress, [string]$Activity, [bool]$NoParent) {
        Write-Host ( "##vso[task.setprogress " `
                + "value=$(($Progress / $TotalProgress) * 100);" `
                + "]$(($this.config.Parent -And -Not $NoParent) ? "[$($this.config.Parent)] " : '')$Activity"
        )
    }
    # Log an error or warning message in the timeline record of the current task.
    # When Type is not provided, set Type to 'warning'.
    # (Type = warning | error)
    [void] VsoLogIssue([string]$Issue, [string]$Type) {
        Write-Host ( "##vso[task.logissue " `
                + "type=$Type;" `
                + "] $Issue"
        )
    }
    # Log a warning message in the timeline record of the current task.
    [void] VsoLogIssue([string]$Issue) { $this.VsoLogIssue($Issue, 'warning') }
    # Log an error message in the timeline record of the current task.
    [void] VsoLogError([string]$Issue) { $this.VsoLogIssue($Issue, 'error') }
    # Initialize or modify the value of a variable.
    # Sets a variable in the variable service of taskcontext.
    # The first task can set a variable, and following tasks are able to use the variable.
    # The variable is exposed to the following tasks as an environment variable.
    # For Job-Crossing Variables set IsOutput to $true, following tasks are able to use the variable as input.
    # Define in following jobs a new pipeline-variable to consume variables from inputs with value like:
    #   $[ dependencies.JobNameFromDependsOnDefinition.outputs['StepNameUsingThisFunction.VariableName'] ]
    # When issecret is set to true, the value of the variable will be saved as secret and masked out from log.
    # Secret variables are not passed into tasks as environment variables and must instead be passed as inputs.
    [void] VsoSetVariable([string]$Variable, [string]$Value) { $this.VsoSetVariable($Variable, $Value, $false, $false, $false) }
    [void] VsoSetVariable([string]$Variable, [string]$Value, [bool]$IsOutput) { $this.VsoSetVariable($Variable, $Value, $IsOutput, $false, $false) }
    [void] VsoSetVariable([string]$Variable, [string]$Value, [bool]$IsOutput, [bool]$IsReadOnly) { $this.VsoSetVariable($Variable, $Value, $IsOutput, $IsReadOnly, $false) }
    [void] VsoSetVariable([string]$Variable, [string]$Value, [bool]$IsOutput, [bool]$IsReadOnly, [bool]$IsSecret) {
        Write-Host ( "##vso[task.setvariable " `
                + "variable=$Variable;" `
                + "isOutput=$($IsOutput.ToString().ToLower());" `
                + "isReadonly=$($IsReadOnly.ToString().ToLower());" `
                + "issecret=$($IsSecret.ToString().ToLower());" `
                + "]$Value"
        )
    }
    # Finish the timeline record for the current task, set task result and current operation.
    # When result is not provided, set result to 'Succeeded'.
    # (TaskResult = Succeeded | SucceededWithIssues | Failed | Canceled)
    [void] VsoCompleteTask() { $this.VsoCompleteTask('Succeeded') }
    [void] VsoCompleteTask([string]$TaskResult) {
        Write-Host ( "##vso[task.complete " `
                + "result=$TaskResult;" `
                + "]DONE"
        )
    }
    # Finish the timeline record for the current task, set task result and current operation to 'SucceededWithIssues'.
    [void] VsoCompleteTaskWarning() { $this.VsoCompleteTask('SucceededWithIssues') }
    # Finish the timeline record for the current task, set task result and current operation to 'Failed'.
    [void] VsoCompleteTaskFailed() { $this.VsoCompleteTask('Failed') }
    # Update the PATH environment variable by prepending to the PATH.
    # The updated environment variable will be reflected in subsequent tasks.
    [void] VsoPrependPath([string]$Path) {
        Write-Host ( "##vso[task.prependpath" `
                + "]$Path"
        )
    }
    # New artifact link creation. Artifact location must be a file container path, VC path or UNC share path.
    # (Type = container | filepath | versioncontrol | gitref | tfvclabel)
    [void] VsoAssociateArtifact([string]$Artifact, [string]$ArtifactName, [string]$Type) {
        Write-Host ( "##vso[artifact.associate " `
                + "type=$Type;" `
                + "artifactname=$ArtifactName;" `
                + "]$Artifact"
        )
    }
    # Upload an artifact, and optionally publish the file into a file container folder
    [void] VsoUploadArtifact([string]$Artifact, [string]$ArtifactName) { $this.VsoUploadArtifact($Artifact, $ArtifactName, $null) }
    [void] VsoUploadArtifact([string]$Artifact, [string]$ArtifactName, [string]$ContainerFolder) {
        Write-Host ( "##vso[artifact.upload " `
                + "$($ContainerFolder ? "containerfolder=$ContainerFolder;" : '')" `
                + "artifactname=$ArtifactName;" `
                + "]$Artifact"
        )
    }
    # Upload a [string] as an artifact, and optionally publish the file into a file container folder
    [void] VsoUploadStringAsArtifact([string]$ArtifactContent, [string]$Filename, [string]$ArtifactName) { $this.VsoUploadStringAsArtifact($Artifact, $Filename, $ArtifactName, $null) }
    [void] VsoUploadStringAsArtifact([string]$ArtifactContent, [string]$Filename, [string]$ArtifactName, [string]$ContainerFolder) {
        $tmpPath = (Test-Path $env:TEMP) ? $env:TEMP : (Test-Path '/tmp/') ? '/tmp' : (& { throw 'No Temp Path found!' })
        Get-ChildItem -Path "$($env:TEMP)/LogApe_tempArtiContent_*" | Where-Object {
            $_.LastAccessTime -lt (Get-Date).AddHours(-3)
        } | Remove-Item -Recurse -Force -ErrorAction SilentlyContinue
        $tmpPath = Join-Path $tmpPath ('LogApe_tempArtiContent_' + [int](Get-Date -UFormat %s) + '_' + (Get-Random))
        New-Item -ItemType Directory -Path $tmpPath -ErrorAction Stop | Out-Null
        $tmpPath = Join-Path $tmpPath $Filename
        $ArtifactContent | Out-File -FilePath $tmpPath
        Write-Host ( "##vso[artifact.upload " `
                + "$($ContainerFolder ? "containerfolder=$ContainerFolder;" : '')" `
                + "artifactname=$ArtifactName;" `
                + "]$tmpPath"
        )
    }
    # Upload and attach attachment to current timeline record. These files are not available for download with logs.
    # These can only be referred to by extensions using the type or name values.
    [void] VsoAddAttachment([string]$Attachment, [string]$Name, [string]$Type) {
        Write-Host ( "##vso[task.addattachment " `
                + "type=$Type;" `
                + "name=$Name;" `
                + "]$Attachment"
        )
    }
    # Add some Markdown content to the build summary.
    # This summary shall be added to the build/release summary and not available for download with logs.
    # The summary should be a .md file in UTF-8 or ASCII format.
    [void] VsoUploadSummary([string]$MdFile) {
        Write-Host ( "##vso[task.uploadsummary" `
                + "]$MdFile"
        )
    }
    # Upload a file to the current timeline record that can be downloaded with task logs
    [void] VsoUploadFile([string]$File) {
        Write-Host ( "##vso[task.uploadfile" `
                + "]$File"
        )
    }
    # Upload log-file to builds container "logs\tool" folder
    [void] VsoUploadLog([string]$File) {
        Write-Host ( "##vso[build.uploadlog" `
                + "]$File"
        )
    }
    # Override the automatically generated build number
    [void] VsoUpdateBuildNumber([string]$BuildNumber) {
        Write-Host ( "##vso[build.updatebuildnumber" `
                + "]$BuildNumber"
        )
    }
    # Rename the current release
    [void] VsoUpdateReleaseName([string]$ReleaseName) {
        Write-Host ( "##vso[build.updatereleasename" `
                + "]$ReleaseName"
        )
    }
    # Add a tag to the build
    [void] VsoAddBuildTag([string]$Tag) {
        Write-Host ( "##vso[build.addbuildtag" `
                + "]$Tag"
        )
    }
    # Set/Modify a service connection id field with given value. Value updated will be retained in the endpoint for the subsequent tasks that execute within the same job.
    # (Field = authParameter | dataParameter | url)
    # ('AccessToken' is required unless 'Field' = 'url')
    # When 'Field' & 'AccessToken' is not provided, set 'Field' to 'url'.
    [void] SetEndpoint([string]$Value, [string]$ServiceConnectionId) { $this.SetEndpoint($Value, $ServiceConnectionId, 'url', $null) }
    [void] SetEndpoint([string]$Value, [string]$ServiceConnectionId, [string]$Field, [string]$AccessToken) {
        Write-Host ( "##vso[task.setendpoint " `
                + "id=$ServiceConnectionId;" `
                + "field=$Field;" `
                + "$($AccessToken -And $Field -ne 'url' ? "key=$AccessToken;" : '')" `
                + "]$Value"
        )
    }
    # Formatting command. This command gets interpreted by the Azure Pipelines log formatter. It marks specific log lines as errors, warnings, collapsible sections, and so on.
    # (Format = command | debug | warning | error | section | group | endgroup)
    # Formats: [command]Command-line being run; [debug]Debug text; [warning]Warning message; [error]Error message; [section]Start of a section; [group]Beginning of a group; [endgroup]
    # Those formats will render in the logs like this: https://docs.microsoft.com/en-us/azure/devops/pipelines/scripts/media/log-formatting.png?view=azure-devops
    # The block formats can also be collapsed, and looks like this: https://docs.microsoft.com/en-us/azure/devops/pipelines/scripts/media/log-formatting-collapsed.png?view=azure-devops
    [void] VsoLog([string]$Msg, [string]$Format) {
        Write-Host ( "##[$Format]$Msg" )
    }


    ### Public Instance Configuration Methods
    # Set (merge) the configuration by a inline Hashtable or JSON-string
    [void] SetConfig([hashtable]$Hashtable) { $this.mergeConfig($Hashtable) }
    [void] SetConfig([string]$Json) {
        try { $this.SetConfig(($Json | ConvertFrom-Json -AsHashtable -ErrorAction Stop)) }
        catch { [LogApe]::PrintStopError("[$((Get-PSCallStack).FunctionName[0])([string])] Unable to set JSON config: $_") }
    }
    # Set (merge) the configuration by a JSON file
    [void] SetConfigFromJsonFile([string]$Path) {
        try { $this.SetConfig((Get-Content -Path $Path -Encoding UTF8 -ErrorAction Stop)) }
        catch { [LogApe]::PrintStopError("[$((Get-PSCallStack).FunctionName[0])([string])] Unable to load JSON file: $_") }
    }
    # Set (merge) the configuration by a PSData file
    [void] SetConfigFromPSDataFile([string]$Path) {
        try { $this.SetConfig((Import-PowerShellDataFile -Path $Path -ErrorAction Stop)) }
        catch { [LogApe]::PrintStopError("[$((Get-PSCallStack).FunctionName[0])([string])] Unable to load PSD file: $_") }
    }
    # Get the configuration as [Hashtable]
    [System.Collections.IDictionary] GetConfig() {
        if (-Not $this.config) {
            $this.config = (& {
                    [LogApe]::PrintDebug("[GetConfig()] Setting Module-Default configuration ...")
                    $hashtable = @{
                        <# Default Configuration for LogApe Class/Module #>
                        DateCulture          = 'en-CA'
                        MsecLog              = $true
                        Debug                = $false
                        LogFile              = $null
                        Parent               = $null
                        ParentColor          = $null
                        ErrorLevelMsgMapping = $null
                    }
                    $hashtable['IsModuleDefault'] = $true
                    return $hashtable
                })
        }
        $_config = [ordered]@{}
        $this.config.Keys | Sort-Object -CaseSensitive | ForEach-Object { $_config[$_] = $this.config[$_] }
        return $_config
    }
    # Get the configuration as short-JSON string by setting the first parameter to $true
    [string] GetConfig([bool]$AsJson) { return [LogApe]::formatObjectToShortJson($this.GetConfig(), 1).Trim() }
    # Clear the configuration (loads the module default configuration)
    [void] ClearConfig() {
        $this.config = $null
        $this.config = $this.GetConfig()
    }
}


### Create (initialize) a new LogApe class instance
function New-LogApe {
    [OutputType([LogApe])]
    [CmdletBinding()] param (
        # Specifies the config 'as Hashtable or JSON-String'
        [Parameter(Mandatory = $false, Position = 0, ValueFromPipeline = $true)]
        [Alias('C')]
        [object]$ConfigInline,
        # Specifies the JSON file path to use for configuration
        [Parameter(Mandatory = $false)]
        [Alias('CJSON')]
        [string] $ConfigJsonFile,
        # Specifies the PowerShell data file path to use for configuration
        [Parameter(Mandatory = $false)]
        [Alias('CPSD')]
        [string] $ConfigPSDataFile,
        # Specifies the [string] or [array] for the config Parent property
        [Parameter(Mandatory = $false)]
        [Alias('P', 'Prefix', 'H', 'Heading')]
        [psobject] $Parent,
        # Specifies the [string] or [int] for the config ParentColor property
        [Parameter(Mandatory = $false)]
        [Alias('CP', 'ColorParent', 'PC', 'ParentColor', 'CH', 'ColorHeading', 'HC', 'HeadingColor')]
        [psobject] $CParent,
        # Specifies the [string] for the config LogFile property
        [Parameter(Mandatory = $false)]
        [Alias('L')]
        [string] $LogFile,
        # Specifies the [string] for the config DateCulture property
        [Parameter(Mandatory = $false)]
        [Alias('U', 'DC', 'DateCulture')]
        [string] $UseDateCulture,
        # Overrides the default ErrorLevelMsg with provided ones
        [Parameter(Mandatory = $false)]
        [Alias('E')]
        [hashtable] $ErrorLevelMsgMapping,
        # Specifies that config MsecLog property will be set to false
        [Parameter(Mandatory = $false)]
        [Alias('M')]
        [switch] $MsecLogDisabled,
        # Specifies that config Debug property will be set to true
        [Parameter(Mandatory = $false)]
        [Alias('D')]
        [switch] $DebugOutput
    )
    Begin {
        # Parameter validation
        $parameterListSet = @()
        foreach ($key in @('Config', 'JsonFile', 'PSDataFile')) {
            $var = Get-Variable -Name $key -ErrorAction SilentlyContinue;
            if ($var -And $var.value) { $parameterListSet += $var.name }
        }
        if ($parameterListSet.Count -gt 1) { [LogApe]::PrintStopError("'-$($parameterListSet -join ', -')' switches/parameters cannot be combined!") }
    }
    Process {
        return [LogApe]::new(
            $ConfigInline ? $ConfigInline
            : $ConfigJsonFile ? (Get-Content -Path $ConfigJsonFile -Encoding UTF8 -ErrorAction Stop)
            : $ConfigPSDataFile ? (Import-PowerShellDataFile -Path $ConfigPSDataFile -ErrorAction Stop)
            : @{},
            $Parent,
            $CParent,
            $LogFile,
            $UseDateCulture,
            $ErrorLevelMsgMapping,
            [bool]($MsecLogDisabled),
            [bool]($DebugOutput)
        )
    }
    <#
        .SYNOPSIS
        Create a new LogApe instance
        .INPUTS
        [object]. Takes optional configuration as Hashtable or JSON-String or from a PSData or JSON file.
        .OUTPUTS
        LogApe. Returns the LogApe instance object.
        .EXAMPLE
        C:\PS> New-LogApe
        LogApe
        .EXAMPLE
        C:\PS> New-LogApe @{ MsecLog = $false; Parent = "vSphereClass"; LogFile = "C:\log.txt"; }
        LogApe
        .EXAMPLE
        C:\PS> New-LogApe '{ "Parent" : "vSphereClass" }'
        LogApe
        .EXAMPLE
        C:\PS> New-LogApe -JsonFile '.\myJsonConfig.json'
        LogApe
        .EXAMPLE
        C:\PS> New-LogApe -PSDataFile '.\myPSD1Config.psd1'
        LogApe
    #>
}


### PrintDebug PSM-END
[LogApe]::PrintDebug("[$($MyInvocation.MyCommand.Name)] " + 'PowerShellModule ~ END ~')
