# Tiny desktop driver: screenshot / click / keys / activate window. usage:
#   ui.ps1 shot <out.png> [scaleWidth]
#   ui.ps1 click <x> <y>          (physical screen pixels)
#   ui.ps1 keys "<SendKeys string>"
#   ui.ps1 activate "<window title substring>"
param([string]$cmd, [string]$a1, [string]$a2)
Add-Type -AssemblyName System.Windows.Forms, System.Drawing
Add-Type @"
using System; using System.Runtime.InteropServices; using System.Text;
public class U {
  [DllImport("user32.dll")] public static extern bool SetProcessDPIAware();
  [DllImport("user32.dll")] public static extern bool SetCursorPos(int x, int y);
  [DllImport("user32.dll")] public static extern void mouse_event(uint f, uint x, uint y, uint d, IntPtr e);
  [DllImport("user32.dll")] public static extern bool SetForegroundWindow(IntPtr h);
  [DllImport("user32.dll")] public static extern bool ShowWindow(IntPtr h, int n);
  [DllImport("user32.dll")] public static extern bool IsIconic(IntPtr h);
  [DllImport("user32.dll")] public static extern void keybd_event(byte k, byte s, uint f, IntPtr e);
}
"@
[U]::SetProcessDPIAware() | Out-Null
switch ($cmd) {
  "shot" {
    $b = [System.Windows.Forms.SystemInformation]::VirtualScreen
    $bmp = New-Object System.Drawing.Bitmap $b.Width, $b.Height
    $g = [System.Drawing.Graphics]::FromImage($bmp); $g.CopyFromScreen($b.X, $b.Y, 0, 0, $bmp.Size)
    $w = if ($a2) { [int]$a2 } else { $b.Width }
    if ($w -ne $b.Width) { $h = [int]($b.Height * $w / $b.Width); $s = New-Object System.Drawing.Bitmap $bmp, $w, $h; $s.Save($a1, [System.Drawing.Imaging.ImageFormat]::Png) } else { $bmp.Save($a1, [System.Drawing.Imaging.ImageFormat]::Png) }
    "screen $($b.X),$($b.Y) $($b.Width)x$($b.Height) saved width $w"
  }
  "click" { [U]::SetCursorPos([int]$a1, [int]$a2) | Out-Null; Start-Sleep -Milliseconds 120; [U]::mouse_event(2,0,0,0,[IntPtr]::Zero); Start-Sleep -Milliseconds 60; [U]::mouse_event(4,0,0,0,[IntPtr]::Zero); "clicked $a1,$a2" }
  "keys" { [System.Windows.Forms.SendKeys]::SendWait($a1); "sent $a1" }
  "activate" {
    $p = Get-Process | Where-Object { $_.MainWindowTitle -like "*$a1*" } | Select-Object -First 1
    if (-not $p) { "no window"; Get-Process | Where-Object { $_.MainWindowTitle } | ForEach-Object { " - " + $_.ProcessName + ": " + $_.MainWindowTitle }; break }
    if ([U]::IsIconic($p.MainWindowHandle)) { [U]::ShowWindow($p.MainWindowHandle, 9) | Out-Null }
    [U]::keybd_event(0x12,0,0,[IntPtr]::Zero); [U]::keybd_event(0x12,0,2,[IntPtr]::Zero)   # ALT tap lets SetForegroundWindow succeed
    [U]::SetForegroundWindow($p.MainWindowHandle) | Out-Null; "activated: " + $p.MainWindowTitle
  }
}
