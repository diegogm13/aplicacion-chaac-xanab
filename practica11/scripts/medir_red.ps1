# Práctica 11 — Fase 5: mediciones reales de conectividad contra el backend desplegado.
# Uso:  powershell -ExecutionPolicy Bypass -File practica11/scripts/medir_red.ps1
# Requiere curl.exe (incluido en Windows 10/11). No modifica datos del servidor.
param(
  [string]$Api = 'https://backend-chaac-xanab.vercel.app/api',
  [string]$Salida = 'practica11/resultados'
)
$ErrorActionPreference = 'Stop'
$hostApi = ([Uri]$Api).Host
New-Item -ItemType Directory -Force $Salida | Out-Null
$res = [ordered]@{ fecha = (Get-Date).ToString('yyyy-MM-dd HH:mm:ss zzz'); api = $Api }

function Stats([double[]]$v) {
  $avg = ($v | Measure-Object -Average).Average
  $sd = [math]::Sqrt((($v | ForEach-Object { ($_ - $avg) * ($_ - $avg) }) | Measure-Object -Sum).Sum / [math]::Max($v.Count - 1, 1))
  $ord = $v | Sort-Object
  $p95 = $ord[[math]::Min([math]::Ceiling(0.95 * $ord.Count) - 1, $ord.Count - 1)]
  [ordered]@{ n = $v.Count; min = [math]::Round(($v | Measure-Object -Minimum).Minimum, 2); max = [math]::Round(($v | Measure-Object -Maximum).Maximum, 2)
              promedio = [math]::Round($avg, 2); desviacion = [math]::Round($sd, 2); p95 = [math]::Round($p95, 2) }
}

# Formato de salida de curl: una línea JSON por petición.
# (PowerShell 5 quita las comillas dobles de los argumentos nativos, así que el
#  formato y los cuerpos JSON se pasan a curl mediante archivos: -w @archivo.)
$fmtArchivo = Join-Path $env:TEMP 'p11_curl_fmt.txt'
[IO.File]::WriteAllText($fmtArchivo, '{"code":%{http_code},"dns":%{time_namelookup},"tcp":%{time_connect},"tls":%{time_appconnect},"ttfb":%{time_starttransfer},"total":%{time_total},"bajada":%{size_download},"subida":%{size_upload},"vel_bajada":%{speed_download},"vel_subida":%{speed_upload},"ip":"%{remote_ip}","http":"%{http_version}"}\n')
$fmt = "@$fmtArchivo"
function CuerpoArchivo([string]$json) {
  $p = Join-Path $env:TEMP ("p11_body_{0}.json" -f [guid]::NewGuid().ToString('N'))
  [IO.File]::WriteAllText($p, $json)
  "@$p"
}
function Medir([string[]]$extra) {
  $out = & curl.exe -s -o NUL -w $fmt @extra
  $o = $out | ConvertFrom-Json
  foreach ($k in 'dns','tcp','tls','ttfb','total') { $o.$k = [math]::Round($o.$k * 1000, 1) }   # s -> ms
  $o
}

# ── A. Ping ICMP (20 paquetes) ───────────────────────────────────────────────
Write-Host "A. ping -n 20 $hostApi"
$ping = ping.exe -n 20 $hostApi
$ping | Out-File -Encoding utf8 "$Salida/ping.txt"
$tiempos = @($ping | Select-String 'tiempo[=<](\d+)ms|time[=<](\d+)ms' | ForEach-Object { [double]($_.Matches[0].Groups[1].Value + $_.Matches[0].Groups[2].Value) })
$perdidos = 20 - $tiempos.Count
$res.ping = [ordered]@{ host = $hostApi; enviados = 20; recibidos = $tiempos.Count; perdida_pct = [math]::Round(100 * $perdidos / 20, 1)
                        ms = if ($tiempos.Count) { Stats $tiempos } else { $null }; muestras = $tiempos }

# ── B/D. Latencia HTTP: 10 solicitudes consecutivas al mismo endpoint ─────────
Write-Host "B. 10 x GET /productos"
$sol = 1..10 | ForEach-Object { $r = Medir @("$Api/productos"); $r | Add-Member n $_ -PassThru }
$res.http_10 = [ordered]@{ endpoint = "GET $Api/productos"; solicitudes = $sol
  total_ms = Stats ($sol | ForEach-Object total); ttfb_ms = Stats ($sol | ForEach-Object ttfb)
  bytes = Stats ($sol | ForEach-Object bajada); exitosas = @($sol | Where-Object code -eq 200).Count }

# Con conexión reutilizada (keep-alive): separa costo de TLS del costo del servidor.
Write-Host "B'. 10 x GET /productos en UNA conexión"
$urls = 1..10 | ForEach-Object { "$Api/productos" }
$keep = & curl.exe -s -w $fmt -o NUL -o NUL -o NUL -o NUL -o NUL -o NUL -o NUL -o NUL -o NUL -o NUL @urls | ForEach-Object { $_ | ConvertFrom-Json }
foreach ($o in $keep) { foreach ($k in 'dns','tcp','tls','ttfb','total') { $o.$k = [math]::Round($o.$k * 1000, 1) } }
$res.http_keepalive = [ordered]@{ total_ms = Stats ($keep | ForEach-Object total); ttfb_ms = Stats ($keep | ForEach-Object ttfb); solicitudes = $keep }

# ── C. Tasa de transferencia ─────────────────────────────────────────────────
Write-Host "C. descarga (JSON e imagen) y subida"
$prod = (& curl.exe -s "$Api/productos") | ConvertFrom-Json
$img = ($prod | Where-Object { $_.image_url } | Select-Object -First 1).image_url
$descargas = @()
foreach ($i in 1..3) {
  foreach ($u in @("$Api/productos", $img)) {
    $r = Medir @($u)
    $descargas += [pscustomobject]@{ recurso = $u; intento = $i; code = $r.code; bytes = $r.bajada; tiempo_s = [math]::Round($r.total / 1000, 3)
      transferencia_s = [math]::Round(($r.total - $r.ttfb) / 1000, 3)
      mbps_total = [math]::Round(($r.bajada * 8) / ($r.total / 1000) / 1e6, 3)
      mbps_curl = [math]::Round($r.vel_bajada * 8 / 1e6, 3) }
  }
}
# Subida: ~90 KB de JSON a /auth/register con un campo no permitido. El
# ValidationPipe lo rechaza (400) DESPUÉS de recibir el cuerpo completo, así
# que se mide la subida real sin crear ningún registro.
$relleno = 'A' * 90000
$cuerpo = "{""name"":""carga"",""email"":""no-es-correo"",""password"":""x"",""relleno"":""$relleno""}"
$tmp = Join-Path $env:TEMP 'p11_subida.json'
[IO.File]::WriteAllText($tmp, $cuerpo)
$subidas = 1..3 | ForEach-Object {
  $r = Medir @('-X', 'POST', '-H', 'Content-Type: application/json', '--data-binary', "@$tmp", "$Api/auth/register")
  [pscustomobject]@{ intento = $_; code = $r.code; bytes = $r.subida; tiempo_s = [math]::Round($r.total / 1000, 3)
    mbps_total = [math]::Round(($r.subida * 8) / ($r.total / 1000) / 1e6, 3); mbps_curl = [math]::Round($r.vel_subida * 8 / 1e6, 3) }
}
Remove-Item $tmp
$res.descarga = $descargas
$res.subida = $subidas

# ── Códigos HTTP en producción (sin credenciales) ─────────────────────────────
Write-Host "Códigos HTTP en producción"
$casos = @(
  @('200 catálogo', @("$Api/productos")),
  @('200 categorías', @("$Api/categorias")),
  @('404 producto UUID inexistente', @("$Api/productos/00000000-0000-4000-8000-000000000000")),
  @('id no UUID (DEF-05)', @("$Api/productos/abc")),
  @('404 ruta inexistente', @("$Api/no-existe")),
  @('401 sin token', @("$Api/compras/mis-compras")),
  @('401 token inválido', @('-H', 'Authorization: Bearer abc.def.ghi', "$Api/auth/me")),
  @('401 admin sin token', @("$Api/admin/productos")),
  @('400 registro inválido', @('-X', 'POST', '-H', 'Content-Type: application/json', '--data-binary', (CuerpoArchivo '{"name":"","email":"x","password":"1"}'), "$Api/auth/register")),
  @('400 JSON mal formado', @('-X', 'POST', '-H', 'Content-Type: application/json', '--data-binary', (CuerpoArchivo '{"email":'), "$Api/auth/login")),
  @('400 badge fuera de catálogo', @("$Api/productos?badge=gratis"))
)
$res.codigos = foreach ($c in $casos) {
  $body = & curl.exe -s -w "`n%{http_code}" @($c[1])
  $lineas = $body -split "`n"
  [pscustomobject]@{ caso = $c[0]; code = [int]$lineas[-1]; cuerpo = (($lineas[0..($lineas.Count - 2)] -join '') -replace '\s+', ' ').Substring(0, [math]::Min(160, (($lineas[0..($lineas.Count - 2)] -join '')).Length)) }
}

# ── Cabeceras de seguridad ───────────────────────────────────────────────────
$hdr = & curl.exe -s -D - -o NUL "$Api/productos"
$hdr | Out-File -Encoding utf8 "$Salida/cabeceras_productos.txt"
$res.cabeceras = [ordered]@{}
foreach ($h in 'strict-transport-security','x-content-type-options','x-frame-options','content-security-policy','x-powered-by','x-vercel-cache','cache-control','content-encoding','content-type') {
  $m = $hdr | Select-String -Pattern "^${h}:\s*(.*)$"
  $res.cabeceras[$h] = if ($m) { $m.Matches[0].Groups[1].Value.Trim() } else { $null }
}
# ¿Comprime si el cliente lo pide?  (la app Flutter manda Accept-Encoding: gzip)
$gz = Medir @('-H', 'Accept-Encoding: gzip', "$Api/productos")
$res.gzip = [ordered]@{ bytes_con_gzip = $gz.bajada; bytes_sin_gzip = $sol[0].bajada }

$json = $res | ConvertTo-Json -Depth 8
[IO.File]::WriteAllText((Join-Path (Resolve-Path $Salida) 'red.json'), $json)
Write-Host "Listo -> $Salida/red.json"
