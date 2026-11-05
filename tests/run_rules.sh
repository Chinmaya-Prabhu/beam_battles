#!/bin/bash
# Runs tests/clash_rules.spec.luau against the real shared modules (no Roblox needed).
cd "$(dirname "$0")/.."
LUAU=${LUAU:-$HOME/Documents/Titan/.tools/luau/luau}
TMP=$(mktemp -t rules).luau
{
  echo 'local Color3 = { fromRGB = function(...) return { ... } end, new = function(...) return { ... } end }'
  echo 'local Vector3 = { new = function(x, y, z) return { X = x, Y = y, Z = z } end }'
  echo 'local Vector2 = { new = function(x, y) return { X = x, Y = y } end }'
  echo 'local Config_src = function()'; sed 's/^return Config$/return Config/' src/shared/Config.lua; echo 'end'
  echo 'local function CONFIG() return Config_src() end'
  echo 'local function RULES(Config)'; sed 's/require(script.Parent.Config)/Config/' src/shared/ClashRules.lua; echo 'end'
  cat tests/clash_rules.spec.luau
} > "$TMP"
"$LUAU" "$TMP" || exit 1
TMP2=$(mktemp -t training).luau
{
  echo 'local Color3 = { fromRGB = function(...) return { ... } end, new = function(...) return { ... } end }'
  echo 'local function TRAINING()'; cat src/shared/Training.lua; echo 'end'
  cat tests/training.spec.luau
} > "$TMP2"
"$LUAU" "$TMP2" || exit 1
TMP3=$(mktemp -t stock).luau
{
  echo 'local Color3 = { fromRGB = function(...) return { ... } end, new = function(...) return { ... } end }'
  echo 'local function TRAINING()'; cat src/shared/Training.lua; echo 'end'
  echo 'local function STOCK(Training)'; sed 's/require(script.Parent.Training)/Training/' src/shared/Stock.lua; echo 'end'
  cat tests/stock.spec.luau
} > "$TMP3"
"$LUAU" "$TMP3" || exit 1
TMP4=$(mktemp -t rewards).luau
{
  echo 'local function REWARDS()'; cat src/shared/Rewards.lua; echo 'end'
  echo 'local function FIGHTERS()'; cat src/shared/Fighters.lua; echo 'end'
  echo 'local function COLLECTION()'; sed 's/require(script.Parent.Fighters)/FIGHTERS()/' src/shared/Collection.lua; echo 'end'
  cat tests/rewards.spec.luau
} > "$TMP4"
"$LUAU" "$TMP4" || exit 1
TMP5=$(mktemp -t liveops).luau
{
  echo 'local Color3 = { fromRGB = function(...) return { ... } end, new = function(...) return { ... } end }'
  echo 'local game = nil'
  echo 'local function LIVEOPS()'; cat src/shared/LiveOps.lua; echo 'end'
  cat tests/liveops.spec.luau
} > "$TMP5"
"$LUAU" "$TMP5" || exit 1
TMP6=$(mktemp -t market).luau
{
  echo 'local Color3 = { fromRGB = function(...) return { ... } end, new = function(...) return { ... } end }'
  echo 'local Vector3 = { new = function(x, y, z) return { X = x, Y = y, Z = z } end }'
  echo 'local Vector2 = { new = function(x, y) return { X = x, Y = y } end }'
  echo 'local function CONFIG()'; cat src/shared/Config.lua; echo 'end'
  echo 'local function FIGHTERS()'; cat src/shared/Fighters.lua; echo 'end'
  echo 'local function PRODUCTS()'; cat src/shared/Products.lua; echo 'end'
  echo 'local function MARKET()'
  echo '  local Config, Fighters, Products = CONFIG(), FIGHTERS(), PRODUCTS()'
  echo '  local Market = (function()'
  sed 's/require(script.Parent.Fighters)/Fighters/' src/shared/Market.lua
  echo '  end)()'
  echo '  return Market, Fighters, Config, Products'
  echo 'end'
  cat tests/market.spec.luau
} > "$TMP6"
"$LUAU" "$TMP6" || exit 1
TMP7=$(mktemp -t odds).luau
{
  echo 'local Color3 = { fromRGB = function(...) return { ... } end, new = function(...) return { ... } end }'
  echo 'local Vector3 = { new = function(x, y, z) return { X = x, Y = y, Z = z } end }'
  echo 'local Vector2 = { new = function(x, y) return { X = x, Y = y } end }'
  echo 'local function CONFIG()'; cat src/shared/Config.lua; echo 'end'
  echo 'local function FIGHTERS()'; cat src/shared/Fighters.lua; echo 'end'
  echo 'local function ODDS()'
  echo '  local Config, Fighters = CONFIG(), FIGHTERS()'
  echo '  local Odds = (function()'
  sed -e 's/require(script.Parent.Config)/Config/' -e 's/require(script.Parent.Fighters)/Fighters/' src/shared/Odds.lua
  echo '  end)()'
  echo '  return Odds, Config'
  echo 'end'
  cat tests/odds.spec.luau
} > "$TMP7"
"$LUAU" "$TMP7" || exit 1
TMP8=$(mktemp -t codes).luau
{
  echo 'local Color3 = { fromRGB = function(...) return { ... } end, new = function(...) return { ... } end }'
  echo 'local function CODES()'
  echo '  local Codes = (function()'; cat src/shared/Codes.lua; echo '  end)()'
  echo '  local LiveOps = (function()'; cat src/shared/LiveOps.lua; echo '  end)()'
  echo '  return Codes, LiveOps'
  echo 'end'
  cat tests/codes.spec.luau
} > "$TMP8"
"$LUAU" "$TMP8" || exit 1
