-- DEValueTooltip.lua
-- Shows disenchant results and Auctionator AH prices on item tooltips.
-- WoW Forever (Classic-era, Interface 16001, level cap 60).
--
-- Disenchant table sourced from:
--   https://www.wow-professions.com/forever/disenchanting-guide
--
-- Auctionator integration modelled on WaylaidCrateAdvisor.

local ADDON_NAME = "DEValueTooltip"
local DEV = {}
_G[ADDON_NAME] = DEV

-------------------------------------------------------------------------------
-- Disenchant table
-- Keyed by REQUIRED LEVEL (the "Requires Level X" line on the tooltip).
-- This is what the game engine actually uses to determine DE results.
--
-- Required level brackets per wow-professions.com/forever/disenchanting-guide:
--   req  1-15  → Strange Dust / Magic Essence    / Small Glimmering Shard
--   req 16-20  → Strange Dust / Astral Essence   / Small Glimmering Shard
--   req 21-25  → Soul Dust    / Astral Essence   / Large Glimmering Shard
--   req 26-30  → Soul Dust    / Mystic Essence   / Small Glowing Shard
--   req 31-35  → Vision Dust  / Mystic Essence   / Large Glowing Shard
--   req 36-40  → Vision Dust  / Nether Essence   / Small Radiant Shard
--   req 41-45  → Dream Dust   / Nether Essence   / Large Radiant Shard
--   req 46-50  → Dream Dust   / Eternal Essence  / Small Brilliant Shard
--   req 51-55  → Illusion Dust / Eternal Essence / Large Brilliant Shard
--   req 56-60  → Illusion Dust / Eternal Essence / Large Brilliant Shard / Nexus Crystal
--
-- Green (uncommon) items:
--   Armor:  75% dust pool, 20% essence pool, ~4% shard pool (independent rolls)
--   Weapon: 20% dust pool, 75% essence pool, ~4% shard pool (independent rolls)
-- Blue (rare) items:    always 1 shard
-- Epic items req <=50:  always 1 shard
-- Epic items req  51+:  always 1 Nexus Crystal
-- Items with no required level (req 0) are treated as req 1.
-------------------------------------------------------------------------------
local GREEN_SHARD_CHANCE = 0.04   -- ~4% chance; shown as separate optional result

local DE_TABLE = {
    { min=1,  max=15,
      dust    = {"Strange Dust",            1, 2},
      essence = {"Lesser Magic Essence",    1, 2},
      shard   = {"Small Glimmering Shard"} },
    { min=16, max=20,
      dust    = {"Strange Dust",            4, 6},
      essence = {"Lesser Astral Essence",   1, 2},
      shard   = {"Small Glimmering Shard"} },
    { min=21, max=25,
      dust    = {"Soul Dust",               1, 2},
      essence = {"Greater Astral Essence",  1, 2},
      shard   = {"Large Glimmering Shard"} },
    { min=26, max=30,
      dust    = {"Soul Dust",               2, 5},
      essence = {"Lesser Mystic Essence",   1, 2},
      shard   = {"Small Glowing Shard"} },
    { min=31, max=35,
      dust    = {"Vision Dust",             1, 2},
      essence = {"Greater Mystic Essence",  1, 2},
      shard   = {"Large Glowing Shard"} },
    { min=36, max=40,
      dust    = {"Vision Dust",             2, 5},
      essence = {"Lesser Nether Essence",   1, 2},
      shard   = {"Small Radiant Shard"} },
    { min=41, max=45,
      dust    = {"Dream Dust",              1, 2},
      essence = {"Greater Nether Essence",  1, 2},
      shard   = {"Large Radiant Shard"} },
    { min=46, max=50,
      dust    = {"Dream Dust",              2, 5},
      essence = {"Lesser Eternal Essence",  1, 2},
      shard   = {"Small Brilliant Shard"} },
    { min=51, max=55,
      dust    = {"Illusion Dust",           1, 2},
      essence = {"Greater Eternal Essence", 1, 2},
      shard   = {"Large Brilliant Shard"},
      nexus   = {"Nexus Crystal"} },
    { min=56, max=60,
      dust    = {"Illusion Dust",           2, 5},
      essence = {"Greater Eternal Essence", 1, 3},
      shard   = {"Large Brilliant Shard"},
      nexus   = {"Nexus Crystal"} },
}

local function GetDERow(reqLevel)
    for _, row in ipairs(DE_TABLE) do
        if reqLevel >= row.min and reqLevel <= row.max then
            return row
        end
    end
    return nil
end

-------------------------------------------------------------------------------
-- Price lookup — mirrors WaylaidCrateAdvisor's proven approach exactly
-------------------------------------------------------------------------------
function DEV:GetPrice(itemID)
    -- 1) Try the official Auctionator API first (most reliable)
    if Auctionator and Auctionator.API and Auctionator.API.v1 then
        local ok, price = pcall(Auctionator.API.v1.GetAuctionPriceByItemID, ADDON_NAME, itemID)
        if ok and price and price > 0 then return price end
    end
    -- 2) Fall back to raw SavedVariable
    if AUCTIONATOR_PRICE_DATABASE then
        local realm = GetRealmName() .. " " .. (UnitFactionGroup("player") or "")
        local realmDB = AUCTIONATOR_PRICE_DATABASE[realm]
        if type(realmDB) == "table" then
            local entry = realmDB[tostring(itemID)]
            if type(entry) == "table" and entry.m and entry.m > 0 then return entry.m end
        end
    end
    return nil
end

-- Look up price by item name — used for enchanting mats which we know by name, not ID.
-- We resolve name→ID once via C_Item.GetItemInfoInstant for known mat IDs.
local MAT_NAME_TO_ID = {
    ["Strange Dust"]            = 10940,
    ["Lesser Magic Essence"]    = 10938,
    ["Greater Magic Essence"]   = 10939,
    ["Small Glimmering Shard"]  = 10978,
    ["Large Glimmering Shard"]  = 11084,
    ["Soul Dust"]               = 11083,
    ["Lesser Astral Essence"]   = 10998,
    ["Greater Astral Essence"]  = 11082,
    ["Small Glowing Shard"]     = 11138,
    ["Large Glowing Shard"]     = 11139,
    ["Vision Dust"]             = 11137,
    ["Lesser Mystic Essence"]   = 11134,
    ["Greater Mystic Essence"]  = 11135,
    ["Small Radiant Shard"]     = 11177,
    ["Large Radiant Shard"]     = 11178,
    ["Dream Dust"]              = 11176,
    ["Lesser Nether Essence"]   = 11174,
    ["Greater Nether Essence"]  = 11175,
    ["Small Brilliant Shard"]   = 14343,
    ["Large Brilliant Shard"]   = 14344,
    ["Lesser Eternal Essence"]  = 16202,
    ["Greater Eternal Essence"] = 16203,
    ["Illusion Dust"]           = 16204,
    ["Nexus Crystal"]           = 20725,
}

function DEV:GetMatPrice(matName)
    local id = MAT_NAME_TO_ID[matName]
    if not id then return nil end
    return self:GetPrice(id)
end

-------------------------------------------------------------------------------
-- Money formatting — identical to WaylaidCrateAdvisor
-------------------------------------------------------------------------------
function DEV:Coins(copper)
    if not copper then return "|cffaaaaaa—|r" end
    local g = math.floor(copper / 10000)
    local s = math.floor((copper % 10000) / 100)
    local c = copper % 100
    local parts = {}
    if g > 0 then parts[#parts+1] = ("|cffffd700%dg|r"):format(g) end
    if s > 0 then parts[#parts+1] = ("|cffc0c0c0%ds|r"):format(s) end
    if c > 0 or #parts == 0 then parts[#parts+1] = ("|cffb87333%dc|r"):format(c) end
    return table.concat(parts, " ")
end

-------------------------------------------------------------------------------
-- Build tooltip lines for one material result
-- Returns nil if the material doesn't apply
-------------------------------------------------------------------------------
local function QtyStr(minQ, maxQ)
    if minQ == maxQ then return tostring(minQ) end
    return minQ .. "-" .. maxQ
end

-- Colors matching each material's in-game icon appearance.
local MAT_COLORS = {
    -- Dusts
    ["Strange Dust"]            = "a8d8a0",  -- pale green
    ["Soul Dust"]               = "b0c8f0",  -- soft blue-lavender (unchanged, not in correction list)
    ["Vision Dust"]             = "a0e8e0",  -- pale cyan
    ["Dream Dust"]              = "ff3090",  -- hot pink
    ["Illusion Dust"]           = "c03070",  -- dark pink

    -- Magic Essences (blue / indigo)
    ["Lesser Magic Essence"]    = "6060e0",
    ["Greater Magic Essence"]   = "6060e0",

    -- Astral Essences (golden yellow — not in correction list, keeping)
    ["Lesser Astral Essence"]   = "ffc040",
    ["Greater Astral Essence"]  = "ffc040",

    -- Mystic Essences (magenta)
    ["Lesser Mystic Essence"]   = "e040c0",
    ["Greater Mystic Essence"]  = "e040c0",

    -- Nether Essences (teal green)
    ["Lesser Nether Essence"]   = "30c090",
    ["Greater Nether Essence"]  = "30c090",

    -- Eternal Essences (bright sky blue — not in correction list, keeping)
    ["Lesser Eternal Essence"]  = "80c8ff",
    ["Greater Eternal Essence"] = "80c8ff",

    -- Glimmering Shards (purple-blue)
    ["Small Glimmering Shard"]  = "7060d8",
    ["Large Glimmering Shard"]  = "7060d8",

    -- Glowing Shards (violet-pink)
    ["Small Glowing Shard"]     = "c060d0",
    ["Large Glowing Shard"]     = "c060d0",

    -- Radiant Shards (orange-red — not in correction list, keeping)
    ["Small Radiant Shard"]     = "ff8030",
    ["Large Radiant Shard"]     = "ff8030",

    -- Brilliant Shards (warm yellow)
    ["Small Brilliant Shard"]   = "ffd050",
    ["Large Brilliant Shard"]   = "ffd050",

    -- Nexus Crystal (arcane purple — not in correction list, keeping)
    ["Nexus Crystal"]           = "cc66ff",
}

-- AddMatLine: draws one result row and returns its expected copper value (or nil if no price).
-- Expected value = chance * avgQty * unitPrice
function DEV:AddMatLine(tooltip, matName, minQty, maxQty, chance)
    local chanceStr = ("%.0f%%"):format(chance * 100)
    local price = self:GetMatPrice(matName)
    local avgQty = (minQty + maxQty) / 2

    local color = MAT_COLORS[matName] or "ffffff"
    local left = ("|cff%s%s|r x%s |cff888888(%s)|r"):format(
        color, matName, QtyStr(minQty, maxQty), chanceStr)

    if price then
        local avgValue = math.floor(price * avgQty)
        local right
        if minQty == maxQty then
            right = self:Coins(price * minQty)
        else
            right = self:Coins(avgValue) .. " |cff888888avg|r"
        end
        tooltip:AddDoubleLine(left, right, 1,1,1, 1,1,1)
        -- Expected contribution: chance * avgQty * price
        return chance * avgQty * price
    else
        tooltip:AddDoubleLine(left, "|cff888888no AH data|r", 1,1,1, 0.53,0.53,0.53)
        return nil
    end
end

-------------------------------------------------------------------------------
-- Core: add DE section to a tooltip given an item link
-------------------------------------------------------------------------------
-- Disenchantability check
-- There is no CanDisenchantItem() API in Classic / Forever. We replicate the
-- same heuristic every addon uses: equippable + uncommon/rare/epic + armor or
-- weapon class, minus a known set of non-DE subclasses (shirts, cosmetics,
-- fishing poles, thrown weapons, wands, etc. that the game silently rejects).
--
-- Subclass strings that block DE are stored in localized form because
-- Classic-era GetItemInfo returns class/subclass as localized strings, not IDs.
-- We cover enUS here; add your locale's strings if needed.
-- This will never be a perfect list, but it covers all the common cases.
-------------------------------------------------------------------------------

-- Item class names that are weapons (for dust/essence split)
local WEAPON_CLASS_NAMES = {
    ["Weapon"]  = true,  -- enUS
    ["Waffe"]   = true,  -- deDE
    ["Arme"]    = true,  -- frFR
    ["Arma"]    = true,  -- esES / esMX / itIT / ptBR
    ["武器"]    = true,  -- zhCN / zhTW
    ["무기"]    = true,  -- koKR
    ["Оружие"]  = true,  -- ruRU
}

-- Item class names that are armor (the other disenchantable class)
local ARMOR_CLASS_NAMES = {
    ["Armor"]   = true,  -- enUS
    ["Rüstung"] = true,  -- deDE
    ["Armure"]  = true,  -- frFR
    ["Armadura"]= true,  -- esES / esMX / ptBR
    ["防具"]    = true,  -- zhCN / zhTW
    ["방어구"]  = true,  -- koKR
    ["Броня"]   = true,  -- ruRU
}

-- Armor subclasses that CANNOT be disenchanted.
-- Shirts and Cosmetic items look equippable but the game rejects them.
-- Fishing Poles share the Weapon class but are not DE-able.
local NON_DE_SUBCLASSES = {
    -- Armor subclasses
    ["Shirt"]              = true,
    ["Tabard"]             = true,
    ["Cosmetic"]           = true,
    -- Weapon subclasses that are not DE-able in Classic / Forever
    ["Fishing Pole"]       = true,
    ["Miscellaneous"]      = true,  -- catches "Miscellaneous" weapons (some quest items)
    -- Some locales
    ["Hemd"]               = true,  -- Shirt deDE
    ["Chemise"]            = true,  -- Shirt frFR
    ["Camisa"]             = true,  -- Shirt esES
    ["Tabard"]             = true,  -- same in most locales
    ["Angelrute"]          = true,  -- Fishing Pole deDE
    ["Canne à pêche"]      = true,  -- Fishing Pole frFR
    ["Caña de pescar"]     = true,  -- Fishing Pole esES
    ["钓鱼竿"]             = true,  -- Fishing Pole zhCN
    ["낚싯대"]             = true,  -- Fishing Pole koKR
    ["Удочка"]             = true,  -- Fishing Pole ruRU
}

-- equipLoc tokens that are never disenchantable regardless of class/subclass
local NON_DE_EQUIPLOC = {
    ["INVTYPE_NON_EQUIP"]       = true,
    ["INVTYPE_BAG"]             = true,
    ["INVTYPE_QUIVER"]          = true,
    ["INVTYPE_AMMO"]            = true,
    ["INVTYPE_THROWN"]          = true,  -- thrown weapons not DE-able in vanilla
    ["INVTYPE_TABARD"]          = true,
    ["INVTYPE_BODY"]            = true,  -- shirts
}

local function IsDisenchantable(quality, itemClass, itemSubClass, equipLoc)
    -- Must be uncommon, rare, or epic
    if not quality or quality < 2 or quality > 4 then
        return false, "wrong quality"
    end

    -- Must have an equip location and not be on the blocked list
    if not equipLoc or equipLoc == "" then
        return false, "not equippable"
    end
    if NON_DE_EQUIPLOC[equipLoc] then
        return false, "cannot be disenchanted"
    end

    -- Must be armor or weapon class
    local isArmor  = ARMOR_CLASS_NAMES[itemClass]
    local isWeapon = WEAPON_CLASS_NAMES[itemClass]
    if not isArmor and not isWeapon then
        return false, "cannot be disenchanted"
    end

    -- Block known non-DE subclasses
    if NON_DE_SUBCLASSES[itemSubClass] then
        return false, "cannot be disenchanted"
    end

    return true, isWeapon
end

-------------------------------------------------------------------------------
function DEV:AddTooltip(tooltip, link)
    if not link then return end
    local itemID = tonumber(link:match("item:(%d+)"))
    if not itemID then return end

    -- C_Item.GetItemInfo return order (Classic / WoW Forever):
    --   1 name  2 link  3 quality  4 itemLevel  5 requiredLevel
    --   6 class (localized)  7 subclass (localized)  8 maxStack
    --   9 equipSlot  10 icon  11 vendorPrice
    local name, _, quality, itemLevel, minLevel, itemClass, itemSubClass, _, equipLoc = C_Item.GetItemInfo(link)
    if not name then return end

    -- Only show anything on uncommon+ quality items that are equippable
    if not quality or quality < 2 or quality > 4 then return end
    if not equipLoc or equipLoc == "" then return end

    local canDE, isWeaponOrReason = IsDisenchantable(quality, itemClass, itemSubClass, equipLoc)

    tooltip:AddLine(" ")

    if not canDE then
        -- Item passes the quality check but is not disenchantable
        tooltip:AddLine("|cffa335ee[Disenchant]|r |cffff4444Cannot be disenchanted|r")
        tooltip:Show()
        return
    end

    local isWeapon = isWeaponOrReason  -- true/false

    local ilvl   = (itemLevel and itemLevel > 0) and itemLevel or 1
    local reqLvl = (minLevel  and minLevel  > 0) and minLevel  or 1
    local row = GetDERow(reqLvl)
    if not row then
        tooltip:AddLine("|cffa335ee[Disenchant]|r |cff888888(req " .. reqLvl .. " — no data)|r")
        tooltip:Show()
        return
    end

    tooltip:AddLine(("|cffa335ee[Disenchants into]|r |cff888888(ilvl %d, req %d)|r"):format(ilvl, reqLvl))

    -- Accumulate expected copper from each result that has AH data.
    -- For greens, dust and essence are independent rolls (both can drop), so we sum them.
    -- The shard pool is also independent (~4% chance on top of dust/essence).
    local totalExpected = 0   -- copper
    local anyPrice      = false
    local missingPrice  = false

    local function Accum(ev)
        if ev then
            totalExpected = totalExpected + ev
            anyPrice = true
        else
            missingPrice = true
        end
    end

    if quality == 2 then
        local dustChance    = isWeapon and 0.20 or 0.75
        local essenceChance = isWeapon and 0.75 or 0.20

        if row.dust    then Accum(self:AddMatLine(tooltip, row.dust[1],    row.dust[2],    row.dust[3],    dustChance))    end
        if row.essence then Accum(self:AddMatLine(tooltip, row.essence[1], row.essence[2], row.essence[3], essenceChance)) end
        if row.shard   then Accum(self:AddMatLine(tooltip, row.shard[1],   1, 1, GREEN_SHARD_CHANCE)) end
        if row.nexus   then Accum(self:AddMatLine(tooltip, row.nexus[1],   1, 1, GREEN_SHARD_CHANCE)) end

    elseif quality == 3 then
        if row.shard then Accum(self:AddMatLine(tooltip, row.shard[1], 1, 1, 1.0)) end

    elseif quality == 4 then
        if row.nexus then
            Accum(self:AddMatLine(tooltip, row.nexus[1], 1, 1, 1.0))
        elseif row.shard then
            Accum(self:AddMatLine(tooltip, row.shard[1], 1, 1, 1.0))
        end
    end

    -- Average yield summary line
    if anyPrice then
        local label = "|cff00ff96Avg DE value:|r"
        local valueStr = self:Coins(math.floor(totalExpected))
        if missingPrice then
            valueStr = valueStr .. " |cffff6600*|r"  -- asterisk = some mats had no price
        end
        tooltip:AddLine(" ")
        tooltip:AddDoubleLine(label, valueStr, 1,1,1, 1,1,1)
        if missingPrice then
            tooltip:AddLine("|cff888888* some mats missing AH data|r")
        end
    end

    tooltip:Show()
end

-------------------------------------------------------------------------------
-- Tooltip hooks
-------------------------------------------------------------------------------
local function HandleTooltip(tooltip, link)
    if not link then return end
    local ok, err = pcall(DEV.AddTooltip, DEV, tooltip, link)
    if not ok then
        print("|cffff0000DEValueTooltip error:|r " .. tostring(err))
    end
end

-- Hook a tooltip frame's SetHyperlink so chat-link popups work.
-- ItemRefTooltip is the frame shown when you click a link in chat —
-- it is separate from GameTooltip and must be hooked independently.
local function HookTooltipFrame(tooltipFrame)
    hooksecurefunc(tooltipFrame, "SetHyperlink", function(tooltip, link)
        HandleTooltip(tooltip, link)
    end)
end

local initFrame = CreateFrame("Frame")
initFrame:RegisterEvent("ADDON_LOADED")
initFrame:SetScript("OnEvent", function(self, event, arg1)
    if event ~= "ADDON_LOADED" or arg1 ~= ADDON_NAME then return end

    local ok, err = pcall(function()
        -- Bag item hover
        hooksecurefunc(GameTooltip, "SetBagItem", function(tooltip, bag, slot)
            local info = C_Container.GetContainerItemInfo(bag, slot)
            HandleTooltip(tooltip, info and info.hyperlink)
        end)

        -- GameTooltip SetHyperlink — AH rows, unit-frame items, etc.
        HookTooltipFrame(GameTooltip)

        -- ItemRefTooltip — the popup shown when you CLICK a linked item in chat.
        -- This is a completely separate frame from GameTooltip; without this hook
        -- chat-link clicks show no DE data.
        HookTooltipFrame(ItemRefTooltip)

        -- ItemRefShoppingTooltip1/2 — comparison tooltips shown alongside ItemRefTooltip
        if ItemRefShoppingTooltip1 then HookTooltipFrame(ItemRefShoppingTooltip1) end
        if ItemRefShoppingTooltip2 then HookTooltipFrame(ItemRefShoppingTooltip2) end

        -- Equipped item hover (character frame / paperdoll)
        hooksecurefunc(GameTooltip, "SetInventoryItem", function(tooltip, unit, slot)
            local link = GetInventoryItemLink(unit, slot)
            HandleTooltip(tooltip, link)
        end)

        -- Merchant / vendor items.
        -- SetMerchantItem fires on GameTooltip with the merchant slot index as arg.
        -- GetMerchantItemLink(index) returns the full item link for that slot.
        hooksecurefunc(GameTooltip, "SetMerchantItem", function(tooltip, index)
            local link = GetMerchantItemLink(index)
            HandleTooltip(tooltip, link)
        end)

        -- Loot window items
        hooksecurefunc(GameTooltip, "SetLootItem", function(tooltip, index)
            local link = GetLootSlotLink(index)
            HandleTooltip(tooltip, link)
        end)

        -- Pre-cache mat item info so names resolve immediately
        for _, id in pairs(MAT_NAME_TO_ID) do
            C_Item.GetItemInfo(id)
        end
    end)

    if not ok then
        print("|cffff0000DEValueTooltip load error:|r " .. tostring(err))
    end
end)
