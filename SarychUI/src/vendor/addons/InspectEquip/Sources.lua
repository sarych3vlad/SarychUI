-- InspectEquip 1.7.7 source decoding (emelio), adapted to the SarychUI owner.
local IE = SarychUI.InspectEquip
local L = LibStub("AceLocale-3.0"):GetLocale("SarychUI_InspectEquip")
local gmatch, tinsert = string.gmatch, table.insert
local embJustice, embHeroism, embValor = "Badge of Justice", "Emblem of Heroism", "Emblem of Valor"
local embConquest, embTriumph, embFrost = "Emblem of Conquest", "Emblem of Triumph", "Emblem of Frost"

local srctypes_d = { -- Instances
  ["n"] = L["Normal"], ["h"] = L["Heroic"], ["q"] = L["Quest Reward"], 
}
local srctypes_r = { -- Raids with 10 man, 25 man, 10 man heroic, 25 man heroic modes
  ["N"] = L["Heroic"], ["H"] = L["Heroic"], ["q"] = L["Quest Reward"], ["Q"] = L["Quest Reward"] 
}
local pvptypes = {
  ["m"] = L["Accessories"], ["l"] = L["Low level PvP"], ["w"] = L["World PvP"], ["s1"] = L["Season 1"],
  ["s2"] = L["Season 2"], ["s3"] = L["Season 3"], ["s4"] = L["Season 4"], ["s5"] = L["Season 5"], 
  ["s6"] = L["Season 6"], ["s7"] = L["Season 7"], ["s8"] = L["Season 8"], ["g"] = L["Lake Wintergrasp"],
}

function IE:FindItem(itemLink, includeUnknown)
  local id = tonumber(itemLink:match("item:(%d+)"))
  if not id then return nil end

  -- Returns a list of (strings localized):
  --  category name ("Raid", "PvP", ...)
  --  subcategory ("Naxxramas", "Season 1", nil, ...)
  --  loot table ("Normal", "Heroic", "Quest Reward", nil, ...)
  --  boss ("Patchwerk", nil, ...)
  --  price (100, nil, ...) <- for badge rewards
  --  set (T7, nil, ...)

  local IS = self.ItemSources
  if not IS then return nil end
  local data = IS.Items[id]
  if data then
    local sources = {}
    for entry in gmatch(data, "[^;]+") do
      local next_field = gmatch(entry, "[^_]+")
      local cat = next_field()

      if cat == "r" or cat == "d" then -- Raid/Dungeon: r_ZONE_SRCTYPE_BOSS
        local catname
        if cat == "r" then catname = L["Raid"] else catname = L["Instances"] end
        local zoneId = tonumber(next_field() or 0)
        local zone = IS.Zones[zoneId]
        local lootTable = next_field()
        local srctype
        if cat == "r" then
          srctype = srctypes_r[lootTable]
          if lootTable == "n" or lootTable == "N" or lootTable == "q" then
            zone = zone .. "-10"
          elseif lootTable == "h" or lootTable == "H" or lootTable == "Q" then
            zone = zone .. "-25"
          elseif lootTable == "4" then
            zone = zone .. "-40"
          end
        else
          srctype = srctypes_d[lootTable]
        end
        local boss = IS.Bosses[tonumber(next_field() or 0)]
        local setname = next_field()
        if setname == "+" then
          setname = L["Hard mode"]
        end
        tinsert(sources, {catname, zone, srctype, boss, nil, setname})
      elseif cat == "j" then -- Badge of Justice: j_COST
        tinsert(sources, {L["Emblem rewards"], embJustice, nil, nil, tonumber(next_field()), next_field()})
      elseif cat == "h" then -- Emblem of Heroism: h_COST
        tinsert(sources, {L["Emblem rewards"], embHeroism, nil, nil, tonumber(next_field()), next_field()})
      elseif cat == "v" then -- Emblem of Valor: v_COST
        tinsert(sources, {L["Emblem rewards"], embValor, nil, nil, tonumber(next_field()), next_field()})
      elseif cat == "u" then -- Emblem of Conquest: u_COST
        tinsert(sources, {L["Emblem rewards"], embConquest, nil, nil, tonumber(next_field()), next_field()})
      elseif cat == "i" then -- Emblem of Triumph: u_COST
        tinsert(sources, {L["Emblem rewards"], embTriumph, nil, nil, tonumber(next_field()), next_field()})
      elseif cat == "o" then -- Emblem of Frost: o_COST
        tinsert(sources, {L["Emblem rewards"], embFrost, nil, nil, tonumber(next_field()), next_field()})
      elseif cat == "t" then -- Argent Tournament: t_COST
        tinsert(sources, {L["Argent Tournament"], nil, nil, nil, tonumber(next_field())})
      elseif cat == "c" then -- Crafted: c_PROFESSION
        local prof = GetSpellInfo(tonumber(next_field() or "0"))
        tinsert(sources, {L["Crafted"], nil, nil, prof})
      elseif cat == "f" then -- Faction rewards: f
        tinsert(sources, {L["Reputation rewards"]})
      elseif cat == "e" then -- World events: e
        tinsert(sources, {L["World events"]})
      elseif cat == "m" then -- Darkmoon Cards: m
        tinsert(sources, {L["Darkmoon Faire"]})
      elseif cat == "g" then -- Vendor (Gold): g
        tinsert(sources, {L["Vendor"]})
      elseif cat == "p" then -- PvP: p_PVPTYPE
        local pvptype = pvptypes[next_field()]
        tinsert(sources, {L["PvP"], pvptype})
      end

    end
    if #sources > 0 then
      return sources
    end
  else
    if includeUnknown then
      local _,_,rarity,lvl = GetItemInfo(id)
      if not rarity or rarity >= 2 then
        return {{L["Unknown"]}}
      end
    end
  end
  return nil
end

function IE:GetItemNames()
  embJustice = GetItemInfo(29434) or embJustice
  embHeroism = GetItemInfo(40752) or embHeroism
  embValor = GetItemInfo(40753) or embValor
  embConquest = GetItemInfo(45624) or embConquest
  embTriumph = GetItemInfo(47241) or embTriumph
  embFrost = GetItemInfo(49426) or embFrost
end

