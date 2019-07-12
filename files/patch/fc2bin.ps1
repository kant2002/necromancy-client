# Script for applying fc /b or .dif kind of binary diffs to files.
# Run using this command: 
#   powershell -executionpolicy bypass -File "fc2bin.ps1"
# Difference file should have the following format:

#    Description line
#
#    myold.fil
#    0000100A: 00 10
#    0000100B: 00 30

param([string]$Apply, [switch]$Revert);

function requestFileName([string]$WindowTitle, [string]$InitialDirectory, [string]$Filter = 'All files (*.*)|*.*', [switch]$AllowMultiSelect)
{
    $openFileDialog = New-Object System.Windows.Forms.OpenFileDialog
    $openFileDialog.Title = $WindowTitle
    $openFileDialog.InitialDirectory = $MyInvocation.MyCommand.Path
    $openFileDialog.Filter = $Filter
    if ($AllowMultiSelect) { $openFileDialog.MultiSelect = $true }
    $openFileDialog.ShowHelp = $true    # Without this line the ShowDialog() function may hang depending on system configuration and running from console vs. ISE.
    $openFileDialog.ShowDialog() > $null
    if ($AllowMultiSelect) { return $openFileDialog.Filenames } else { return $openFileDialog.Filename }
}

function applyPatch([string]$filePath, [switch]$RevertChanges)
{ 
    if (![string]::IsNullOrEmpty($filePath)) {
        Write-Host 'You selected the file:' $filePath
    } else { 
        Write-Host 'You did not select a file.'
        return
    }
    
    $patch = Get-Content $filePath
    $description = $patch[0]
    $targetFile = $patch[2]
    Write-Host 'It will apply' $description 'to' $targetFile
    $targetFile=$(Resolve-Path -LiteralPath $targetFile).Path
    $patch = $patch[3..($patch.length - 1)]
    $bytes = [System.IO.File]::ReadAllBytes($targetFile);
    
    for ($i=0; $i -le $patch.length-1; $i++) {
        $patch[$i] -match [regex]'([0-9a-fA-F]+): ([0-9a-fA-F]+) ([0-9a-fA-F]+)' > $null

        $address = [Convert]::ToInt64($matches[1], 16)
        $oldbyte = [Convert]::ToInt32($matches[2], 16)
        $newbyte =  [Convert]::ToInt32($matches[3] , 16)

        if ($RevertChanges) {
            Write-Host ('{0:X8}: ' -f $address) -nonewline;
            if ($bytes[$address] -eq $newbyte) {
                Write-Host ('{0:X2} ' -f $oldbyte) -foregroundcolor magenta -nonewline; Write-Host ('{0:X2}' -f $newbyte) -foregroundcolor blue
                $bytes[$address] = $oldbyte
            } else {
                Write-Host 'error (expected ' -nonewline;
                Write-Host ('{0:X2}' -f $newbyte) -foregroundcolor green -nonewline
                Write-Host ' got ' -nonewline
                Write-Host ('{0:X2}' -f $bytes[$address]) -foregroundcolor red -nonewline
                Write-Host ')'
            }
        } else {
            Write-Host ('{0:X8}: ' -f $address) -nonewline;
            if ($bytes[$address] -eq $oldbyte) {
                Write-Host ('{0:X2} ' -f $oldbyte) -foregroundcolor magenta -nonewline; Write-Host ('{0:X2}' -f $newbyte) -foregroundcolor blue
                $bytes[$address] = $newbyte
            } else {
                Write-Host 'error (expected ' -nonewline;
                Write-Host ('{0:X2}' -f $oldbyte) -foregroundcolor green -nonewline
                Write-Host ' got ' -nonewline
                Write-Host ('{0:X2}' -f $bytes[$address]) -foregroundcolor red -nonewline
                Write-Host  ')'
            }
        }
    }
    
    [System.IO.File]::WriteAllBytes($targetFile+'.patched', $bytes);
    Write-Host  "Patching complete!`nResult saved as"$targetFile".patched."
}

Write-Host "`nConsole usage (don't use parameters for the GUI version):`n`tfc2bin.ps1 [-apply <path_to_diff> [-revert]]`n"
if ($Apply) {
    if (!$Revert) {
        applyPatch -filePath $Apply
    } else {
        applyPatch -filePath $Apply -RevertChanges
    }
} else {
    Add-Type -AssemblyName System.Windows.Forms
    $form = New-Object System.Windows.Forms.Form -Property @{
        Text = 'DIF file based patcher'
        Size = New-Object System.Drawing.Size(355,100)
        AutoSize = $False
        MinimizeBox = $False
        MaximizeBox = $False
        StartPosition = "CenterScreen"
    }
    $patchBtn = New-Object System.Windows.Forms.Button -Property @{
        Location = New-Object System.Drawing.Point -Property @{
            X = 10
            Y = 10
        }
        Size = New-Object System.Drawing.Size(150,40)
        Text = 'Patch'
    }
    $revertBtn = New-Object System.Windows.Forms.Button -Property @{
        Location = New-Object System.Drawing.Point -Property @{
            X = 170
            Y = 10
        }
        Size = New-Object System.Drawing.Size(150,40)
        Text = 'Revert'
    }
    $patchBtn.Add_Click({
        $path = requestFileName -WindowTitle 'Select patch file' -Filter 'Patch files (*.*)|*.*'
        applyPatch -filePath $path
        $form.Close()
    })
    $revertBtn.Add_Click({
        $path = requestFileName -WindowTitle 'Select patch file for reverting' -Filter 'Patch files (*.*)|*.*'
        applyPatch -filePath $path -RevertChanges
        $form.Close()
    })
    $form.Controls.Add($patchBtn)
    $form.Controls.Add($revertBtn)
    $form.ShowDialog()
}
