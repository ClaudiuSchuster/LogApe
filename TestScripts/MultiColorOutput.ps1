### LogApe Multi Color Output TestScript ###
############################################
Import-Module (Join-Path (Split-Path $PSScriptRoot -Parent) '\Modules\LogApe\') -Force

Write-Host "- - - Default Colored Output Without Multi Color - - -" -ForegroundColor DarkCyan
$l = New-LogApe -D
$l.LogNote("foo")
$l.LogInfo(@("foo"))
$l.LogWarn(@(@("foo"), @("bar")))
$l.LogError(@(@("foo"), @("bar"), @("baz")))
$l.LogDebug(@(@("foo"), @("bar"), @("baz"), @("qux")))

Write-Host "- - - Multi Color Output as Array (Color as ErrLvl or String) - - -" -ForegroundColor DarkCyan
$l = New-LogApe
$l.LogNote(@("foo", 1))
$l.LogNote(@(@("foo", 1)))
$l.LogNote(@(@("foo", 1), @("bar", 2)))
$l.LogNote(@(@("foo", 1), @("bar", 2), @("baz", 3)))
$l.LogNote(@(@("foo", 1), @("bar", 2), @("baz", 3), @("qux", 4)))
$l = New-LogApe
$l.LogInfo(@("foo", 'Green'))
$l.LogInfo(@(@("foo", 'Green')))
$l.LogInfo(@(@("foo", 'Green'), @("bar", 'Yellow')))
$l.LogInfo(@(@("foo", 'Green'), @("bar", 'Yellow'), @("baz", 'Gray')))
$l.LogInfo(@(@("foo", 'Green'), @("bar", 'Yellow'), @("baz", 'Gray'), @("qux", 'Red')))

Write-Host "- - - Multi Color Output as Object (Color as ErrLvl or String) - - -" -ForegroundColor DarkCyan
$l = New-LogApe
$l.LogWarn(@{ Msg = "foo"; Color = 1; })
$l.LogWarn(@(@{ Msg = "foo"; Color = 1; }))
$l.LogWarn(@(@{ Msg = "foo"; Color = 1; }, @{ Msg = "bar"; Color = 0; }))
$l.LogWarn(@(@{ Msg = "foo"; Color = 1; }, @{ Msg = "bar"; Color = 0; }, @{ Msg = "baz"; Color = 3; }))
$l.LogWarn(@(@{ Msg = "foo"; Color = 1; }, @{ Msg = "bar"; Color = 0; }, @{ Msg = "baz"; Color = 3; }, @{ Msg = "qux"; Color = 4; }))
$l = New-LogApe
$l.LogObject(@{ Msg = "foo"; Color = 'White'; }, $null, $null, 4)
$l.LogObject(@(@{ Msg = "foo"; Color = 'White'; }), $null, $null, 4)
$l.LogObject(@(@{ Msg = "foo"; Color = 'White'; }, @{ Msg = "bar"; Color = 'Green'; }), $null, $null, 4)
$l.LogObject(@(@{ Msg = "foo"; Color = 'White'; }, @{ Msg = "bar"; Color = 'Green'; }, @{ Msg = "baz"; Color = 'Gray'; }), $null, $null, 4)
$l.LogObject(@(@{ Msg = "foo"; Color = 'White'; }, @{ Msg = "bar"; Color = 'Green'; }, @{ Msg = "baz"; Color = 'Gray'; }, @{ Msg = "qux"; Color = 'Red'; }), $null, $null, 4)

Write-Host "- - - Mixed Multi Color Output with Default Color Parts (Color as ErrLvl or String) - - -" -ForegroundColor DarkCyan
$l = New-LogApe
$l.Log(@(@{ Msg = "foo"; Color = 0; }, "bar", @{ Msg = "baz"; Color = 'Yellow'; }, "qux"))
$l.Log(@("foo", @{ Msg = "bar"; Color = 2; }, "baz", @{ Msg = "qux"; Color = 'Green'; }))
$l.LogError(@(@("foo", 0), "bar", @("baz", 'Yellow'), "qux"))
$l.LogError(@("foo", @("bar", 'Yellow'), "baz", @("qux", 0)))

Write-Host "- - - Multi Color Output With Parent as Array or Object (Color as ErrLvl or String) - - -" -ForegroundColor DarkCyan
$l = New-LogApe -D -P 'Parent'
$l.LogDebug(@("foo", 1))
$l.LogDebug(@(@("foo", 1)))
$l.LogDebug(@{ Msg = "foo"; Color = 1; })
$l.LogDebug(@(@{ Msg = "foo"; Color = 1; }))
$l.LogDebug(@(@{ Msg = "foo"; Color = 1; }, @{ Msg = "bar"; Color = 'Yellow'; }, @{ Msg = "baz"; Color = 0; }, @{ Msg = "qux"; Color = 'Red'; }))
$l.LogDebug(@(@("foo", 1), @("bar", 'Yellow'), @("baz", 0), @("qux", 'Red')))
