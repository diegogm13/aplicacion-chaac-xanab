# Práctica 12 — muestrea CPU (%) y memoria (MB) de un proceso cada N ms.
# Uso: powershell -File practica12/scripts/muestrear.ps1 -ProcesoId 1234 -Segundos 60 -Salida practica12/resultados/x.csv
#      (o -Puerto 3000 para tomar el proceso que escucha en ese puerto, o -Nombre chaac_xanab_app)
# CPU % = tiempo de CPU consumido en el intervalo / (intervalo × núcleos) × 100  (100 % = toda la máquina)
param(
  [int]$ProcesoId = 0,
  [int]$Puerto = 0,
  [string]$Nombre = '',
  [int]$Segundos = 60,
  [int]$IntervaloMs = 500,
  [string]$Salida = 'muestras.csv'
)
$nucleos = [Environment]::ProcessorCount
$fin = (Get-Date).AddSeconds($Segundos)
# Espera a que exista el proceso (la app puede tardar en abrir).
while (-not $ProcesoId -and (Get-Date) -lt $fin) {
  if ($Puerto) { $c = Get-NetTCPConnection -LocalPort $Puerto -State Listen -ErrorAction SilentlyContinue | Select-Object -First 1; if ($c) { $ProcesoId = $c.OwningProcess } }
  elseif ($Nombre) { $p = Get-Process -Name $Nombre -ErrorAction SilentlyContinue | Select-Object -First 1; if ($p) { $ProcesoId = $p.Id } }
  if (-not $ProcesoId) { Start-Sleep -Milliseconds 200 }
}
if (-not $ProcesoId) { Write-Error 'Proceso no encontrado'; exit 1 }
$filas = New-Object System.Collections.Generic.List[string]
$filas.Add('t_ms,cpu_pct,ram_mb,privada_mb,hilos')
$t0 = Get-Date
$p = Get-Process -Id $ProcesoId
$cpuPrev = $p.TotalProcessorTime.TotalMilliseconds
$tPrev = Get-Date
while ((Get-Date) -lt $fin) {
  Start-Sleep -Milliseconds $IntervaloMs
  try { $p = Get-Process -Id $ProcesoId -ErrorAction Stop } catch { break }
  $ahora = Get-Date
  $cpu = $p.TotalProcessorTime.TotalMilliseconds
  $pct = 100 * ($cpu - $cpuPrev) / (($ahora - $tPrev).TotalMilliseconds * $nucleos)
  $filas.Add([string]::Format([Globalization.CultureInfo]::InvariantCulture, '{0},{1:F2},{2:F1},{3:F1},{4}',
      [int]($ahora - $t0).TotalMilliseconds, $pct, ($p.WorkingSet64 / 1MB), ($p.PrivateMemorySize64 / 1MB), $p.Threads.Count))
  $cpuPrev = $cpu; $tPrev = $ahora
}
New-Item -ItemType Directory -Force (Split-Path $Salida) | Out-Null
[IO.File]::WriteAllLines($Salida, $filas)
Write-Host "PID $ProcesoId · $($filas.Count - 1) muestras -> $Salida"
