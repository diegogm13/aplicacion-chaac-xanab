# Práctica 11 — Mediciones reales del SITIO WEB (Angular en Vercel).
# Uso: powershell -ExecutionPolicy Bypass -File practica11/scripts/medir_web.ps1
# Sólo hace peticiones GET; no modifica datos.
param(
  [string]$Sitio = 'https://chaac-xanab-dg.vercel.app',
  [string]$Api = 'https://backend-chaac-xanab.vercel.app/api',
  [string]$Salida = 'practica11/resultados/web'
)
$ErrorActionPreference = 'Stop'
New-Item -ItemType Directory -Force $Salida | Out-Null
$fmtArchivo = Join-Path $env:TEMP 'p11_web_fmt.txt'
[IO.File]::WriteAllText($fmtArchivo, '{"code":%{http_code},"dns":%{time_namelookup},"tcp":%{time_connect},"tls":%{time_appconnect},"ttfb":%{time_starttransfer},"total":%{time_total},"bytes":%{size_download}}\n')

function Medir([string[]]$extra) {
  $o = (& curl.exe -s -o NUL -w "@$fmtArchivo" @extra) | ConvertFrom-Json
  foreach ($k in 'dns','tcp','tls','ttfb','total') { $o.$k = [math]::Round($o.$k * 1000, 1) }
  $o
}
function Stats($v) {
  $avg = ($v | Measure-Object -Average).Average
  $sd = [math]::Sqrt((($v | ForEach-Object { ($_ - $avg) * ($_ - $avg) }) | Measure-Object -Sum).Sum / [math]::Max($v.Count - 1, 1))
  [ordered]@{ min = ($v | Measure-Object -Minimum).Minimum; promedio = [math]::Round($avg, 1); max = ($v | Measure-Object -Maximum).Maximum; desviacion = [math]::Round($sd, 1) }
}

$res = [ordered]@{ fecha = (Get-Date).ToString('yyyy-MM-dd HH:mm:ss zzz'); sitio = $Sitio }

Write-Host '1. 10 x GET / (página del sitio)'
$pag = 1..10 | ForEach-Object { Medir @("$Sitio/") | Add-Member n $_ -PassThru }
$res.pagina = [ordered]@{ solicitudes = $pag; total_ms = Stats ($pag | % total); exitosas = @($pag | ? code -eq 200).Count }

Write-Host '2. Paquete JavaScript principal (3 descargas)'
$html = & curl.exe -s "$Sitio/"
$main = ([regex]'(main-[\w-]+\.js)').Match($html).Groups[1].Value
$res.bundle = 1..3 | ForEach-Object {
  $r = Medir @('-H', 'Accept-Encoding: gzip, br', "$Sitio/$main")
  [pscustomobject]@{ intento = $_; archivo = $main; code = $r.code; bytes = $r.bytes; tiempo_s = [math]::Round($r.total / 1000, 3)
    mbps = [math]::Round(($r.bytes * 8) / ($r.total / 1000) / 1e6, 3) }
}

Write-Host '3. API vía el sitio (rewrite de Vercel) vs API directa — 10 + 10'
$viaSitio = 1..10 | ForEach-Object { Medir @("$Sitio/api/productos") | Add-Member n $_ -PassThru }
$directa = 1..10 | ForEach-Object { Medir @("$Api/productos") | Add-Member n $_ -PassThru }
$res.api_via_sitio = [ordered]@{ solicitudes = $viaSitio; total_ms = Stats ($viaSitio | % total) }
$res.api_directa = [ordered]@{ solicitudes = $directa; total_ms = Stats ($directa | % total) }

Write-Host '4. Rutas y códigos'
$res.codigos = foreach ($c in @(@('200 inicio', '/'), @('200 ruta SPA /login', '/login'), @('200 ruta SPA inexistente (SPA)', '/no-existe'),
                                 @('404 por rewrite /api/no-existe', '/api/no-existe'), @('401 /api/auth/me sin token', '/api/auth/me'))) {
  $r = Medir @("$Sitio$($c[1])")
  [pscustomobject]@{ caso = $c[0]; ruta = $c[1]; code = $r.code; bytes = $r.bytes; ms = $r.total }
}

Write-Host '5. Cabeceras de seguridad del sitio'
$hdr = & curl.exe -s -D - -o NUL "$Sitio/"
$hdr | Out-File -Encoding utf8 "$Salida/cabeceras_sitio.txt"
$res.cabeceras = [ordered]@{}
foreach ($h in 'strict-transport-security','content-security-policy','x-frame-options','x-content-type-options','referrer-policy','cache-control','x-vercel-cache') {
  $m = $hdr | Select-String -Pattern "^${h}:\s*(.*)$"
  $res.cabeceras[$h] = if ($m) { $m.Matches[0].Groups[1].Value.Trim() } else { $null }
}
Remove-Item $fmtArchivo
[IO.File]::WriteAllText((Join-Path (Resolve-Path $Salida) 'web.json'), ($res | ConvertTo-Json -Depth 6))
Write-Host "Listo -> $Salida/web.json"
