$WarningPreference = 'SilentlyContinue'
Add-Type -AssemblyName System.Windows.Forms
Add-Type -AssemblyName System.Drawing

# ==========================================
# --- PRE-FLIGHT MODULE CHECK ---
# ==========================================
$powerCliInstalled = Get-Module -ListAvailable -Name VMware.VimAutomation.Core
if ($null -eq $powerCliInstalled) {
    [System.Windows.Forms.MessageBox]::Show(
        "VMware PowerCLI is missing from this computer.`n`nPlease open PowerShell and run the following command to install it:`nInstall-Module VMware.PowerCLI -Scope CurrentUser", 
        "Missing Prerequisite", 
        [System.Windows.Forms.MessageBoxButtons]::OK, 
        [System.Windows.Forms.MessageBoxIcon]::Error
    )
    exit
}

# ==========================================
# --- PRE-LAUNCH CONNECTION GUI ---
# ==========================================
$loginForm = New-Object Windows.Forms.Form
$loginForm.Text = "vCenter Login"
$loginForm.Size = New-Object Drawing.Size(420, 260)
$loginForm.StartPosition = "CenterScreen"
$loginForm.FormBorderStyle = "FixedDialog"
$loginForm.MaximizeBox = $false
$loginForm.TopMost = $true 

$lblVC = New-Object Windows.Forms.Label; $lblVC.Text = "vCenter Server(s) [comma-separated]:"; $lblVC.Location = New-Object Drawing.Point(15, 15); $lblVC.AutoSize = $true; $loginForm.Controls.Add($lblVC)
$txtVC = New-Object Windows.Forms.TextBox; $txtVC.Location = New-Object Drawing.Point(15, 35); $txtVC.Size = New-Object Drawing.Size(370, 20); $loginForm.Controls.Add($txtVC)

$lblUser = New-Object Windows.Forms.Label; $lblUser.Text = "Username:"; $lblUser.Location = New-Object Drawing.Point(15, 70); $lblUser.AutoSize = $true; $loginForm.Controls.Add($lblUser)
$txtUser = New-Object Windows.Forms.TextBox; $txtUser.Location = New-Object Drawing.Point(15, 90); $txtUser.Size = New-Object Drawing.Size(175, 20); $loginForm.Controls.Add($txtUser)

$lblPass = New-Object Windows.Forms.Label; $lblPass.Text = "Password:"; $lblPass.Location = New-Object Drawing.Point(210, 70); $lblPass.AutoSize = $true; $loginForm.Controls.Add($lblPass)
$txtPass = New-Object Windows.Forms.TextBox; $txtPass.Location = New-Object Drawing.Point(210, 90); $txtPass.Size = New-Object Drawing.Size(175, 20); $txtPass.PasswordChar = '*'; $loginForm.Controls.Add($txtPass)

$chkSame = New-Object Windows.Forms.CheckBox; $chkSame.Text = "Use these credentials for all entered vCenters"; $chkSame.Location = New-Object Drawing.Point(15, 125); $chkSame.Size = New-Object Drawing.Size(370, 20); $chkSame.Checked = $true; $loginForm.Controls.Add($chkSame)

$btnConnect = New-Object Windows.Forms.Button; $btnConnect.Text = "Connect"; $btnConnect.Location = New-Object Drawing.Point(160, 165); $btnConnect.Size = New-Object Drawing.Size(90, 28); $btnConnect.DialogResult = [System.Windows.Forms.DialogResult]::OK; $btnConnect.BackColor = [System.Drawing.Color]::LightBlue; $loginForm.Controls.Add($btnConnect)

$loginForm.AcceptButton = $btnConnect

$dialogResult = $loginForm.ShowDialog()
if ($dialogResult -ne [System.Windows.Forms.DialogResult]::OK) { exit }

# Process Inputs
$vcArray = $txtVC.Text -split ',' | ForEach-Object { $_.Trim() } | Where-Object { $_ -ne "" }
$mainUser = $txtUser.Text
$mainPass = $txtPass.Text
$useSame = $chkSame.Checked

if ($vcArray.Count -eq 0) {
    [System.Windows.Forms.MessageBox]::Show("No vCenters entered. Exiting.", "Notice")
    exit
}

# --- BULLETPROOF CONNECTION LOOP (100% Silent) ---
foreach ($vc in $vcArray) {
    if (-not ($global:DefaultVIServers.Name -contains $vc)) {
        try {
            if ($useSame) {
                if ($mainUser -ne "") {
                    [void](Connect-VIServer -Server $vc -User $mainUser -Password $mainPass -ErrorAction Stop)
                } else {
                    [void](Connect-VIServer -Server $vc -ErrorAction Stop)
                }
            } else {
                if ($vc -eq $vcArray[0] -and $mainUser -ne "") {
                    [void](Connect-VIServer -Server $vc -User $mainUser -Password $mainPass -ErrorAction Stop)
                } else {
                    $cred = Get-Credential -Message "Please enter credentials for vCenter: $vc" -UserName $mainUser
                    [void](Connect-VIServer -Server $vc -Credential $cred -ErrorAction Stop)
                }
            }
        } catch {
            [System.Windows.Forms.MessageBox]::Show("Failed to connect to $vc.`nError: $($_.Exception.Message)", "Connection Error")
        }
    }
}

$availableClusters = Get-Cluster -ErrorAction SilentlyContinue | Select-Object -ExpandProperty Name | Sort-Object

if (-not $availableClusters) {
    [System.Windows.Forms.MessageBox]::Show("No clusters found or connection failed. Exiting.", "Notice")
    exit
}

# ==========================================
# --- MAIN UI SETUP ---
# ==========================================
$form = New-Object Windows.Forms.Form
$form.Text = "VMware 9.1 Memory Tiering Assessment Tool"
$form.Size = New-Object Drawing.Size(850, 750)
$form.StartPosition = "CenterScreen"
$form.TopMost = $true 

$lblSelect = New-Object Windows.Forms.Label; $lblSelect.Text = "Cluster:"; $lblSelect.Location = New-Object Drawing.Point(20, 20); $lblSelect.AutoSize = $true; $form.Controls.Add($lblSelect)
$combo = New-Object Windows.Forms.ComboBox; $combo.Location = New-Object Drawing.Point(70, 18); $combo.Size = New-Object Drawing.Size(180, 25)
$availableClusters | ForEach-Object { [void]$combo.Items.Add($_) }; $form.Controls.Add($combo)

$lblRatio = New-Object Windows.Forms.Label; $lblRatio.Text = "Tier Ratio:"; $lblRatio.Location = New-Object Drawing.Point(260, 20); $lblRatio.AutoSize = $true; $form.Controls.Add($lblRatio)
$comboRatio = New-Object Windows.Forms.ComboBox; $comboRatio.Location = New-Object Drawing.Point(325, 18); $comboRatio.Size = New-Object Drawing.Size(130, 25)
@("1:1 (50% DRAM)", "1:2 (33% DRAM)", "1:4 (20% DRAM)") | ForEach-Object { [void]$comboRatio.Items.Add($_) }
$comboRatio.SelectedIndex = 0 
$comboRatio.Enabled = $false
$form.Controls.Add($comboRatio)

$lblNote = New-Object Windows.Forms.Label
$lblNote.Text = "*Selectable ONLY if Memory Tiering is enabled"
$lblNote.Location = New-Object Drawing.Point(320, 45)
$lblNote.AutoSize = $true
$lblNote.ForeColor = [System.Drawing.Color]::DimGray
$lblNote.Font = New-Object Drawing.Font("Segoe UI", 8, [Drawing.FontStyle]::Italic)
$form.Controls.Add($lblNote)

$btnRun = New-Object Windows.Forms.Button; $btnRun.Text = "Analyze"; $btnRun.Location = New-Object Drawing.Point(470, 16); $btnRun.Size = New-Object Drawing.Size(100, 28); $btnRun.BackColor = [System.Drawing.Color]::LightGreen; $form.Controls.Add($btnRun)
$btnExport = New-Object Windows.Forms.Button; $btnExport.Text = "Export CSV"; $btnExport.Location = New-Object Drawing.Point(580, 16); $btnExport.Size = New-Object Drawing.Size(100, 28); $btnExport.Enabled = $false; $form.Controls.Add($btnExport)

$label = New-Object Windows.Forms.Label; $label.Text = "Status: Ready"; $label.Location = New-Object Drawing.Point(20, 70); $label.Size = New-Object Drawing.Size(780, 20); $label.Font = New-Object Drawing.Font("Arial", 10, [Drawing.FontStyle]::Bold); $form.Controls.Add($label)
$pb = New-Object Windows.Forms.ProgressBar; $pb.Location = New-Object Drawing.Point(20, 100); $pb.Size = New-Object Drawing.Size(780, 30); $form.Controls.Add($pb)
$assess = New-Object Windows.Forms.Label; $assess.Location = New-Object Drawing.Point(20, 140); $assess.Size = New-Object Drawing.Size(780, 60); $assess.Font = New-Object Drawing.Font("Segoe UI", 11, [Drawing.FontStyle]::Bold); $form.Controls.Add($assess)
$dg = New-Object Windows.Forms.DataGridView; $dg.Location = New-Object Drawing.Point(20, 210); $dg.Size = New-Object Drawing.Size(780, 470); $dg.AutoSizeColumnsMode = "Fill"; $dg.ReadOnly = $true; $form.Controls.Add($dg)

# ==========================================
# --- MAIN ANALYSIS LOGIC ---
# ==========================================
$btnRun.Add_Click({
    if ([string]::IsNullOrEmpty($combo.SelectedItem)) { return }
    $form.Cursor = [System.Windows.Forms.Cursors]::WaitCursor
    
    try {
        $clusterName = $combo.SelectedItem
        $hosts = Get-VMHost -Location (Get-Cluster -Name $clusterName)
        
        $ratioSelection = $comboRatio.SelectedItem.ToString()
        $divisor = 2 
        if ($ratioSelection -match "1:2") { $divisor = 3 }
        if ($ratioSelection -match "1:4") { $divisor = 5 }

        $totalDramGB_Sum = 0
        $tieringActiveGlobally = $false
        
        foreach ($h in $hosts) {
            $hostIsTiered = $false
            
            try {
                $esxcli = Get-EsxCli -VMHost $h -V2 -ErrorAction SilentlyContinue
                $memStatus = $esxcli.memtier.status.get.Invoke()
                if ($memStatus.Status -eq "Enabled") {
                    $hostIsTiered = $true
                    $tieringActiveGlobally = $true
                }
            } catch { }

            $hv = $h | Get-View -Property Hardware
            $rawTotalGB = $hv.Hardware.MemorySize / 1GB
            
            if ($hostIsTiered) {
                $hostDramGB = $rawTotalGB / $divisor
            } else {
                $hostDramGB = $rawTotalGB
            }
            
            $totalDramGB_Sum += $hostDramGB
        }
        
        $finalDramGB = [math]::Round($totalDramGB_Sum, 2)
        
        if ($tieringActiveGlobally) {
            $comboRatio.Enabled = $true
        } else {
            $comboRatio.Enabled = $false
            $comboRatio.SelectedIndex = 0 
        }

        $vms = Get-VM -Location $clusterName | Where-Object {$_.PowerState -eq "PoweredOn"}
        $totalActiveGB = 0
        $script:results = New-Object System.Collections.Generic.List[PSObject]

        foreach ($vm in $vms) {
            $activeGB = [math]::Round($vm.ExtensionData.Summary.QuickStats.GuestMemoryUsage / 1024, 2)
            $totalActiveGB += $activeGB
            $script:results.Add([PSCustomObject]@{
                VMName = $vm.Name; Provisioned_GB = [math]::Round($vm.MemoryGB, 2); 
                Active_GB = $activeGB; Active_Pct = if($vm.MemoryGB -gt 0){[math]::Round(($activeGB/$vm.MemoryGB)*100,2)}else{0}
            })
        }
        
        $script:sortedResults = $script:results | Sort-Object Active_Pct -Descending
        
        $ratio = if ($finalDramGB -gt 0) { [math]::Round(($totalActiveGB / $finalDramGB) * 100, 2) } else { 0 }
        $statusText = if ($tieringActiveGlobally) { "ENABLED" } else { "DISABLED" }

        $dg.DataSource = [System.Collections.ArrayList]$script:sortedResults
        $pb.Value = [math]::Min([int]$ratio, 100)
        $label.Text = "Isolated DRAM (Tier 0): $finalDramGB GB | Active Workload: $totalActiveGB GB ($ratio%) | Status: $statusText"
        
        $assess.ForeColor = if ($ratio -le 50) { [System.Drawing.Color]::DarkGreen } else { [System.Drawing.Color]::Firebrick }
        
        if ($tieringActiveGlobally) {
            $assess.Text = "Memory Tiering is already ENABLED.`nActive workload occupies $ratio% of the configured DRAM tier."
        } else {
            $assess.Text = "Memory Tiering is DISABLED.`nThis cluster is a great candidate for Memory Tiering - but ONLY if active workload is 50% or under from total DRAM size (Currently at $ratio%)."
        }
        
        $btnExport.Enabled = $true
    } catch {
        [System.Windows.Forms.MessageBox]::Show("Error: $($_.Exception.Message)")
    }
    $form.Cursor = [System.Windows.Forms.Cursors]::Default
})

$btnExport.Add_Click({
    $save = New-Object Windows.Forms.SaveFileDialog
    $save.Filter = "CSV Files (*.csv)|*.csv"; $save.FileName = "vSphere9_MemoryTier_Final.csv"
    if ($save.ShowDialog() -eq "OK") {
        $script:sortedResults | Export-Csv -Path $save.FileName -NoTypeInformation
        [System.Windows.Forms.MessageBox]::Show("Export successful!")
    }
})

# THE FIX: Cast the form call to [void] so it doesn't spit out "Cancel" to the ps2exe wrapper
[void]$form.ShowDialog()