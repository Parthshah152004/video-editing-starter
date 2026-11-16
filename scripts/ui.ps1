# ui.ps1: UI-automation helper for driving real apps on this PC (screenshots, smooth mouse moves, clicks, keys).
# Functions: Shot <png> [x y w h]   MoveTo x y [ms]   Click [x y]   DClick   Drag x1 y1 x2 y2 [ms]   Keys "text"   Scroll n   Focus <proc>
Add-Type -AssemblyName System.Windows.Forms, System.Drawing
Add-Type @'
using System; using System.Runtime.InteropServices;
public class UIW {
  [DllImport("user32.dll")] public static extern bool SetProcessDPIAware();
  [DllImport("user32.dll")] public static extern bool SetCursorPos(int x, int y);
  [DllImport("user32.dll")] public static extern void mouse_event(uint f, uint dx, uint dy, int d, UIntPtr e);
  [DllImport("user32.dll")] public static extern bool GetCursorPos(out POINT p);
  [DllImport("user32.dll")] public static extern bool SetForegroundWindow(IntPtr h);
  [DllImport("user32.dll")] public static extern bool ShowWindow(IntPtr h, int c);
  public struct POINT { public int X; public int Y; }
}
'@
[void][UIW]::SetProcessDPIAware()
function Shot([string]$path, [int]$x = -1, [int]$y = 0, [int]$w = 0, [int]$h = 0) {
  $b = [System.Windows.Forms.SystemInformation]::VirtualScreen
  if ($x -lt 0) { $x = $b.X; $y = $b.Y; $w = $b.Width; $h = $b.Height }
  $bmp = New-Object System.Drawing.Bitmap $w, $h
  $g = [System.Drawing.Graphics]::FromImage($bmp); $g.CopyFromScreen($x, $y, 0, 0, $bmp.Size); $g.Dispose()
  $bmp.Save($path, [System.Drawing.Imaging.ImageFormat]::Png); $bmp.Dispose()
}
function Pos { $p = New-Object UIW+POINT; [void][UIW]::GetCursorPos([ref]$p); return @($p.X, $p.Y) }
function Ease([double]$t) { if ($t -lt 0.5) { return 4*$t*$t*$t } else { return 1 - [math]::Pow(-2*$t+2, 3)/2 } }
function MoveTo([int]$x, [int]$y, [int]$ms = 600) {
  $s = Pos; $n = [math]::Max(2, [int]($ms / 8)); $sw = [Diagnostics.Stopwatch]::StartNew()
  for ($i = 1; $i -le $n; $i++) { $e = Ease ($i / $n); [void][UIW]::SetCursorPos([int]($s[0] + ($x - $s[0]) * $e), [int]($s[1] + ($y - $s[1]) * $e)); $target = [int]($ms * $i / $n); while ($sw.ElapsedMilliseconds -lt $target) { Start-Sleep -Milliseconds 1 } }
  [void][UIW]::SetCursorPos($x, $y)
}
function Click([int]$x = -1, [int]$y = -1) {
  if ($x -ge 0) { [void][UIW]::SetCursorPos($x, $y); Start-Sleep -Milliseconds 40 }
  [UIW]::mouse_event(2, 0, 0, 0, [UIntPtr]::Zero); Start-Sleep -Milliseconds 70; [UIW]::mouse_event(4, 0, 0, 0, [UIntPtr]::Zero)
}
function DClick([int]$x = -1, [int]$y = -1) { Click $x $y; Start-Sleep -Milliseconds 90; Click }
function Drag([int]$x1, [int]$y1, [int]$x2, [int]$y2, [int]$ms = 500) {
  MoveTo $x1 $y1 250; [UIW]::mouse_event(2, 0, 0, 0, [UIntPtr]::Zero); Start-Sleep -Milliseconds 80; MoveTo $x2 $y2 $ms; [UIW]::mouse_event(4, 0, 0, 0, [UIntPtr]::Zero)
}
function Keys([string]$s) { [System.Windows.Forms.SendKeys]::SendWait($s) }
function Scroll([int]$n) { [UIW]::mouse_event(0x800, 0, 0, $n * 120, [UIntPtr]::Zero) }
function Focus([string]$proc) { $p = Get-Process $proc -ErrorAction SilentlyContinue | Where-Object { $_.MainWindowHandle -ne 0 } | Select-Object -First 1; if ($p) { [void][UIW]::ShowWindow($p.MainWindowHandle, 3); [void][UIW]::SetForegroundWindow($p.MainWindowHandle) } }
