# TeamsKeepAlive.ps1
# Nie wymaga instalacji .NET SDK ani uprawnien administratora.
# Add-Type kompiluje ponizszy kod C# "w locie" przy uzyciu kompilatora
# wbudowanego juz w kazdy Windows (czesc .NET Framework).

$ErrorActionPreference = 'Stop'
$script:singleInstanceMutex = $null
$script:createdNew = $false
$trayIcon = $null
$timer = $null
$menu = $null
$nativeReady = $false
$logDirectory = Join-Path ([Environment]::GetFolderPath('LocalApplicationData')) 'TeamsKeepAlive'
$logFile = Join-Path $logDirectory 'error.log'
try {
Add-Type -AssemblyName System.Windows.Forms
Add-Type -AssemblyName System.Drawing

# --- Zabezpieczenie przed uruchomieniem kilku kopii naraz ---
# Jesli skrypt juz dziala w tle, ta kopia po prostu pokaze komunikat
# i sie zamknie, zamiast tworzyc druga, niezalezna instancje.
$script:createdNew = $false
$script:singleInstanceMutex = New-Object System.Threading.Mutex($true, "Local\TeamsKeepAlive_SingleInstance", [ref]$script:createdNew)
if (-not $script:createdNew) {
    [System.Windows.Forms.MessageBox]::Show(
        "TeamsKeepAlive juz dziala w tle (sprawdz ikonke w zasobniku systemowym). Ta kopia zostanie zamknieta.",
        "TeamsKeepAlive",
        [System.Windows.Forms.MessageBoxButtons]::OK,
        [System.Windows.Forms.MessageBoxIcon]::Information
    ) | Out-Null
    return
}
# --------------------------------------------------------------

Add-Type @"
using System;
using System.Runtime.InteropServices;

public class IdleNative
{
    [StructLayout(LayoutKind.Sequential)]
    public struct LASTINPUTINFO
    {
        public uint cbSize;
        public uint dwTime;
    }

    [DllImport("user32.dll")]
    private static extern bool GetLastInputInfo(ref LASTINPUTINFO plii);

    [DllImport("user32.dll", SetLastError = true)]
    private static extern uint SendInput(uint nInputs, INPUT[] pInputs, int cbSize);

    [StructLayout(LayoutKind.Sequential)]
    public struct INPUT
    {
        public uint type;
        public INPUTUNION data;
    }

    [StructLayout(LayoutKind.Explicit)]
    public struct INPUTUNION
    {
        [FieldOffset(0)] public MOUSEINPUT mi;
        [FieldOffset(0)] public KEYBDINPUT ki;
        [FieldOffset(0)] public HARDWAREINPUT hi;
    }

    [StructLayout(LayoutKind.Sequential)]
    public struct KEYBDINPUT
    {
        public ushort wVk, wScan;
        public uint dwFlags, time;
        public IntPtr dwExtraInfo;
    }

    [StructLayout(LayoutKind.Sequential)]
    public struct HARDWAREINPUT
    {
        public uint uMsg;
        public ushort wParamL, wParamH;
    }

    [StructLayout(LayoutKind.Sequential)]
    public struct MOUSEINPUT
    {
        public int dx;
        public int dy;
        public uint mouseData;
        public uint dwFlags;
        public uint time;
        public IntPtr dwExtraInfo;
    }

    [DllImport("kernel32.dll", CharSet = CharSet.Auto, SetLastError = true)]
    private static extern uint SetThreadExecutionState(uint esFlags);

    private const uint ES_CONTINUOUS = 0x80000000;
    private const uint ES_SYSTEM_REQUIRED = 0x00000001;

    // Nie usypiaj systemu automatycznie z powodu bezczynnosci. Ekran
    // moze sie normalnie wygasic/zablokowac, jesli faktycznie nic nie
    // robisz. Blokada ekranu moze zmienic status Teams.
    public static void PreventSystemSleep()
    {
        if (SetThreadExecutionState(ES_CONTINUOUS | ES_SYSTEM_REQUIRED) == 0)
            throw new System.ComponentModel.Win32Exception(Marshal.GetLastWin32Error());
    }

    public static uint GetLastInputTick()
    {
        LASTINPUTINFO lii = new LASTINPUTINFO();
        lii.cbSize = (uint)Marshal.SizeOf(lii);
        if (!GetLastInputInfo(ref lii))
            throw new System.ComponentModel.Win32Exception(Marshal.GetLastWin32Error());
        return lii.dwTime;
    }

    public static uint GetIdleMilliseconds(uint lastInput)
    {
        return unchecked((uint)Environment.TickCount - lastInput);
    }

    public static void AllowSystemSleep()
    {
        SetThreadExecutionState(ES_CONTINUOUS);
    }

    public static void Nudge()
    {
        INPUT[] inputs = new INPUT[2];
        inputs[0].type = 0;
        inputs[0].data.mi.dx = 1;
        inputs[0].data.mi.dwFlags = 0x0001; // MOUSEEVENTF_MOVE
        inputs[1].type = 0;
        inputs[1].data.mi.dx = -1;
        inputs[1].data.mi.dwFlags = 0x0001;
        uint sent = SendInput(2, inputs, Marshal.SizeOf(typeof(INPUT)));
        if (sent != 2)
            throw new InvalidOperationException("SendInput: " + sent + "/2. Win32: " +
                Marshal.GetLastWin32Error() + ". Sprawdz blokade ekranu i zasady systemowe.");
    }
}
"@
$nativeReady = $true
[IdleNative]::PreventSystemSleep()

# ================== USTAWIENIA (mozesz zmienic) ==================

# Po ilu ms bezczynnosci zaczynamy podtrzymywac aktywnosc (Teams na
# zielono).
$idleThresholdMs = 2 * 60 * 1000   # 2 minuty

# Co ile ms sprawdzamy stan.
$checkIntervalMs = 5000            # 5 sekund

# ===================================================================

$trayIcon = New-Object System.Windows.Forms.NotifyIcon
$trayIcon.Icon = [System.Drawing.SystemIcons]::Application
$trayIcon.Visible = $true
$trayIcon.Text = "Teams Keep Alive - obserwuje"

$menu = New-Object System.Windows.Forms.ContextMenuStrip
$statusItem = New-Object System.Windows.Forms.ToolStripMenuItem "Status: obserwuje"
$statusItem.Enabled = $false
$menu.Items.Add($statusItem) | Out-Null
$menu.Items.Add((New-Object System.Windows.Forms.ToolStripSeparator)) | Out-Null
$exitItem = New-Object System.Windows.Forms.ToolStripMenuItem "Zamknij"
$menu.Items.Add($exitItem) | Out-Null
$trayIcon.ContextMenuStrip = $menu

$script:isFaking = $false
$script:lastOwnTick = [uint32]0

$timer = New-Object System.Windows.Forms.Timer
$timer.Interval = $checkIntervalMs

$timer.Add_Tick({
    try {

    [IdleNative]::PreventSystemSleep()

    $lastInputTick = [IdleNative]::GetLastInputTick()

    if (-not $script:isFaking) {
        if ($statusItem.Text -ne "Status: obserwuje") {
            $statusItem.Text = "Status: obserwuje"
            $trayIcon.Text = "Teams Keep Alive - obserwuje"
        }
        $idle = [IdleNative]::GetIdleMilliseconds($lastInputTick)
        if ($idle -ge $idleThresholdMs) {
            $script:isFaking = $true
            $statusItem.Text = "Status: aktywny (podtrzymuje)"
            $trayIcon.Text = "Teams Keep Alive - aktywny"
            [IdleNative]::Nudge()
            $script:lastOwnTick = [IdleNative]::GetLastInputTick()
        }
    }
    else {
        if ($lastInputTick -ne $script:lastOwnTick) {
            $script:isFaking = $false
            $statusItem.Text = "Status: obserwuje"
            $trayIcon.Text = "Teams Keep Alive - obserwuje"
        }
        else {
            [IdleNative]::Nudge()
            $script:lastOwnTick = [IdleNative]::GetLastInputTick()
        }
    }
    } catch {
        $timer.Stop()
        $trayIcon.Text = "Teams Keep Alive - blad"
        $statusItem.Text = "Blad: uruchom ponownie lub sprawdz log"
        if ($nativeReady) { [IdleNative]::AllowSystemSleep() }
        try {
            New-Item -ItemType Directory -Path $logDirectory -Force | Out-Null
            Add-Content -LiteralPath $logFile -Value ("{0:o} {1}" -f (Get-Date), ($_ | Out-String))
        } catch {}
        $trayIcon.ShowBalloonTip(10000, "TeamsKeepAlive - blad", "Podtrzymywanie zatrzymane. Szczegoly: $logFile", [System.Windows.Forms.ToolTipIcon]::Error)
    }
})

$exitItem.Add_Click({
    $timer.Stop()
    $trayIcon.Visible = $false
    [System.Windows.Forms.Application]::Exit()
})

$timer.Start()
[System.Windows.Forms.Application]::Run()

} catch {
    $errorDetails = $_ | Out-String
    try {
        New-Item -ItemType Directory -Path $logDirectory -Force | Out-Null
        Add-Content -LiteralPath $logFile -Value ("{0:o} {1}" -f (Get-Date), $errorDetails)
    } catch {}
    try {
        [System.Windows.Forms.MessageBox]::Show("Nie udalo sie uruchomic aplikacji.`n$errorDetails`nLog: $logFile", "TeamsKeepAlive - blad") | Out-Null
    } catch { Write-Warning $errorDetails }
} finally {
    if ($timer) { $timer.Stop(); $timer.Dispose() }
    if ($trayIcon) { $trayIcon.Visible = $false; $trayIcon.Dispose() }
    if ($menu) { $menu.Dispose() }
    if ($nativeReady) { [IdleNative]::AllowSystemSleep() }
    if ($script:singleInstanceMutex) {
        if ($script:createdNew) { $script:singleInstanceMutex.ReleaseMutex() }
        $script:singleInstanceMutex.Dispose()
    }
}
