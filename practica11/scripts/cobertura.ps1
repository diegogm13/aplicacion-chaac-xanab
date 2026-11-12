# Resume coverage/lcov.info (flutter test --coverage --branch-coverage).
# Dart no escribe BRF/BRH, así que se calculan a partir de las líneas BRDA:
#   BRF = destinos de rama instrumentados, BRH = destinos ejecutados (>0).
param(
  [string]$Lcov = "coverage/lcov.info",
  [string]$Salida = "practica11/resultados/cobertura_flutter.csv"
)
$criticos = 'validaciones.dart','api_client.dart','carrito_service.dart','usuario_dao.dart','auth_service.dart','checkout_screen.dart'
$filas = @(); $cur = $null
foreach ($l in Get-Content $Lcov) {
  if ($l -like 'SF:*') { $cur = [ordered]@{ Archivo = ($l.Substring(3) -replace '\\','/'); LH=0; LF=0; BRH=0; BRF=0 } }
  elseif ($l -match '^LF:(\d+)') { $cur.LF = [int]$matches[1] }
  elseif ($l -match '^LH:(\d+)') { $cur.LH = [int]$matches[1] }
  elseif ($l -match '^BRDA:\d+,\d+,\d+,(.+)$') { $cur.BRF++; if ($matches[1] -ne '-' -and [int]$matches[1] -gt 0) { $cur.BRH++ } }
  elseif ($l -eq 'end_of_record') {
    $cur.LineasPct = [math]::Round(100 * $cur.LH / [math]::Max($cur.LF,1), 1)
    $cur.RamasPct  = if ($cur.BRF) { [math]::Round(100 * $cur.BRH / $cur.BRF, 1) } else { $null }
    $cur.Critico   = $criticos -contains (Split-Path $cur.Archivo -Leaf)
    $filas += [pscustomobject]$cur
  }
}
New-Item -ItemType Directory -Force (Split-Path $Salida) | Out-Null
$filas | Export-Csv $Salida -NoTypeInformation -Encoding utf8
$c = $filas | Where-Object Critico
$tot = [pscustomobject]@{
  Archivo='TOTAL módulos críticos'; LH=($c|Measure-Object LH -Sum).Sum; LF=($c|Measure-Object LF -Sum).Sum
  BRH=($c|Measure-Object BRH -Sum).Sum; BRF=($c|Measure-Object BRF -Sum).Sum }
$tot | Add-Member LineasPct ([math]::Round(100*$tot.LH/$tot.LF,1))
$tot | Add-Member RamasPct ([math]::Round(100*$tot.BRH/$tot.BRF,1))
($c + $tot) | Format-Table Archivo, LH, LF, LineasPct, BRH, BRF, RamasPct -AutoSize | Out-String -Width 200
