$ErrorActionPreference = 'Stop'

$projectRoot = Split-Path -Parent $PSScriptRoot
$dataDirectory = Join-Path $projectRoot 'data'
$photoDirectory = Join-Path $projectRoot 'fotos-tse'
$temporaryDirectory = Join-Path $env:TEMP 'colinha-tse-2026'
$candidateZipPath = Join-Path $temporaryDirectory 'consulta_cand_2026.zip'

$candidateDataUrl = 'https://cdn.tse.jus.br/estatistica/sead/odsele/consulta_cand/consulta_cand_2026.zip'
$sources = @(
  @{
    Uf = 'DF'
    CandidateFile = 'consulta_cand_2026_DF.csv'
    PhotoPrefix = 'FDF'
    PhotoUrl = 'https://cdn.tse.jus.br/estatistica/sead/eleicoes/eleicoes2026/fotos/foto_cand2026_DF_div.zip'
    PhotoZip = 'foto_cand2026_DF_div.zip'
  },
  @{
    Uf = 'BR'
    CandidateFile = 'consulta_cand_2026_BR.csv'
    PhotoPrefix = 'FBR'
    PhotoUrl = 'https://cdn.tse.jus.br/estatistica/sead/eleicoes/eleicoes2026/fotos/foto_cand2026_BR_div.zip'
    PhotoZip = 'foto_cand2026_BR_div.zip'
  }
)

New-Item -ItemType Directory -Force -Path $temporaryDirectory, $dataDirectory, $photoDirectory | Out-Null
Invoke-WebRequest -UseBasicParsing -Uri $candidateDataUrl -OutFile $candidateZipPath
Add-Type -AssemblyName System.IO.Compression.FileSystem

$candidates = [System.Collections.Generic.List[object]]::new()

foreach ($source in $sources) {
  $photoZipPath = Join-Path $temporaryDirectory $source.PhotoZip
  Invoke-WebRequest -UseBasicParsing -Uri $source.PhotoUrl -OutFile $photoZipPath

  $candidateArchive = [System.IO.Compression.ZipFile]::OpenRead($candidateZipPath)
  $photoArchive = [System.IO.Compression.ZipFile]::OpenRead($photoZipPath)

  try {
    $candidateEntry = $candidateArchive.GetEntry($source.CandidateFile)
    if (-not $candidateEntry) {
      throw "CSV não encontrado: $($source.CandidateFile)"
    }

    $reader = [System.IO.StreamReader]::new($candidateEntry.Open(), [System.Text.Encoding]::GetEncoding(1252))
    try {
      $rows = @($reader.ReadToEnd() | ConvertFrom-Csv -Delimiter ';')
    } finally {
      $reader.Dispose()
    }

    $selectedRows = $rows | Where-Object { $_.CD_CARGO -in @('1', '3', '5', '6', '8') }
    foreach ($row in $selectedRows) {
      $photoName = '{0}{1}_div.jpg' -f $source.PhotoPrefix, $row.SQ_CANDIDATO
      $photoEntry = $photoArchive.GetEntry($photoName)
      if (-not $photoEntry) {
        throw "Foto oficial não encontrada: $photoName"
      }

      $photoPath = Join-Path $photoDirectory $photoName
      [System.IO.Compression.ZipFileExtensions]::ExtractToFile($photoEntry, $photoPath, $true)

      $candidates.Add([pscustomobject]@{
        cargo = [string]$row.CD_CARGO
        numero = [string]$row.NR_CANDIDATO
        nome = [string]$row.NM_CANDIDATO
        nomeUrna = [string]$row.NM_URNA_CANDIDATO
        partido = [string]$row.SG_PARTIDO
        foto = "./fotos-tse/$photoName"
      })
    }
  } finally {
    $candidateArchive.Dispose()
    $photoArchive.Dispose()
  }
}

$json = ConvertTo-Json -InputObject $candidates.ToArray() -Depth 4 -Compress
$javascript = "window.CANDIDATOS_TSE = $json;"
$outputPath = Join-Path $dataDirectory 'candidatos-2026.js'
[System.IO.File]::WriteAllText($outputPath, $javascript, [System.Text.UTF8Encoding]::new($false))

Write-Host "Gerados $($candidates.Count) candidatos e suas fotos em $photoDirectory"
Write-Host "Índice salvo em $outputPath"