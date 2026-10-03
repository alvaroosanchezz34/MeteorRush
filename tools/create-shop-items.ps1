# Crea en Roblox los game passes y productos de desarrollador de Config/Shop.luau.
# Uso:  powershell -ExecutionPolicy Bypass -File tools\create-shop-items.ps1
# Requiere la variable de entorno de usuario ROBLOX_API_KEY.
# Se puede ejecutar varias veces: lo que ya existe (mismo nombre) no se vuelve a crear.
# Las respuestas de Roblox se guardan en tools\shop-ids.json.

$ErrorActionPreference = "Stop"

$UniverseId = 10769178796
$Base = "https://apis.roblox.com"
$OutFile = Join-Path $PSScriptRoot "shop-ids.json"

$Key = [Environment]::GetEnvironmentVariable("ROBLOX_API_KEY", "User")
if (-not $Key) { $Key = $env:ROBLOX_API_KEY }
if (-not $Key) { throw "Falta la variable de entorno ROBLOX_API_KEY." }

$Passes = @(
    @{ key = "doubleCoins"; name = "2x Coins"; price = 199; desc = "Double income from all your pedestals." },
    @{ key = "vipBackpack"; name = "VIP Backpack"; price = 149; desc = "+10 backpack capacity." },
    @{ key = "autoCollect"; name = "Auto Collect"; price = 249; desc = "Your base income is collected automatically." },
    @{ key = "extraPedestals"; name = "+6 Pedestals"; price = 299; desc = "6 extra pedestals in your base." },
    @{ key = "vip"; name = "VIP"; price = 399; desc = "VIP chat tag, exclusive gold trail and +10% walk speed." }
)

$Products = @(
    @{ key = "carryShield30"; name = "Carry Shield (30 min)"; price = 49; desc = "Nobody can hit you while carrying for 30 minutes." },
    @{ key = "magnet30"; name = "Magnet (30 min)"; price = 39; desc = "Pick up dropped minerals from 20 studs away for 30 minutes." },
    @{ key = "luck30"; name = "2x Luck (30 min)"; price = 79; desc = "Double rare luck for 30 minutes." },
    @{ key = "coinsSmall"; name = "Coin Pouch"; price = 49; desc = "A small pack of coins. Scales with your rebirths." },
    @{ key = "coinsMedium"; name = "Coin Bag"; price = 149; desc = "A medium pack of coins. Scales with your rebirths." },
    @{ key = "coinsLarge"; name = "Coin Chest"; price = 399; desc = "A large pack of coins. Scales with your rebirths." },
    @{ key = "pickaxeGold"; name = "Golden Pickaxe"; price = 99; desc = "A golden pickaxe skin." },
    @{ key = "pickaxeCrystal"; name = "Crystal Pickaxe"; price = 149; desc = "A crystal pickaxe skin." },
    @{ key = "trailFire"; name = "Fire Trail"; price = 99; desc = "A fiery trail that follows you." },
    @{ key = "trailCosmic"; name = "Cosmic Trail"; price = 149; desc = "A cosmic purple trail that follows you." },
    @{ key = "baseOcean"; name = "Ocean Base"; price = 79; desc = "Paint your base floor ocean blue." },
    @{ key = "baseForest"; name = "Forest Base"; price = 79; desc = "Paint your base floor forest green." }
)

function Invoke-Roblox([string[]]$CurlArgs) {
    $raw = & curl.exe -s -w "`n%{http_code}" -H "x-api-key: $Key" @CurlArgs
    $lines = @($raw)
    $status = [int]$lines[-1]
    $body = ($lines[0..($lines.Count - 2)] -join "`n")
    return @{ status = $status; body = $body }
}

function Get-Existing([string]$Url, [string]$ListField) {
    $res = Invoke-Roblox @("$Url`?pageSize=100")
    if ($res.status -ne 200) { throw "No se pudo listar ($($res.status)): $($res.body)" }
    $byName = @{}
    foreach ($item in ($res.body | ConvertFrom-Json).$ListField) { $byName[$item.name] = $item }
    return $byName
}

function New-Items([string]$Label, [string]$Url, [string]$ListField, $Items) {
    $result = @{}
    $existing = Get-Existing "$Url/creator" $ListField
    foreach ($item in $Items) {
        if ($existing.ContainsKey($item.name)) {
            Write-Host "[$Label] ya existe: $($item.name)"
            $result[$item.key] = $existing[$item.name]
            continue
        }
        $res = Invoke-Roblox @(
            "-X", "POST",
            "-F", "name=$($item.name)",
            "-F", "description=$($item.desc)",
            "-F", "isForSale=true",
            "-F", "price=$($item.price)",
            $Url
        )
        if ($res.status -lt 200 -or $res.status -ge 300) {
            throw "[$Label] fallo al crear '$($item.name)' ($($res.status)): $($res.body)"
        }
        Write-Host "[$Label] creado: $($item.name) ($($item.price) R$)"
        $result[$item.key] = $res.body | ConvertFrom-Json
        Start-Sleep -Milliseconds 500
    }
    return $result
}

$out = @{
    gamePasses = New-Items "pass" "$Base/game-passes/v1/universes/$UniverseId/game-passes" "gamePasses" $Passes
    products = New-Items "producto" "$Base/developer-products/v2/universes/$UniverseId/developer-products" "developerProducts" $Products
}

[IO.File]::WriteAllText($OutFile, ($out | ConvertTo-Json -Depth 6))
Write-Host ""
Write-Host "Listo. Ids guardados en $OutFile"
