local addonName, addonTable = ...

addonTable.Roulette = {}
local Roulette = addonTable.Roulette

function Roulette.GetChallengeCount()
    return #addonTable.Challenges
end

local function HasTag(challenge, tag)
    for _, challengeTag in ipairs(challenge.tags or {}) do
        if challengeTag == tag then
            return true
        end
    end
    return false
end

local function BuildRarityPools(reason)
    local challengePools = {}
    for challengeID, challenge in ipairs(addonTable.Challenges) do
        if not ((reason == "death" or reason == "duel") and HasTag(challenge, "Positiv")) then
            local rarity = challenge.rarity
            challengePools[rarity] = challengePools[rarity] or {}
            table.insert(challengePools[rarity], challengeID)
        end
    end

    return challengePools
end

local function RollRarity(challengePools)
    local total = 0
    for _, entry in ipairs(addonTable.RarityWeights) do
        if challengePools[entry.rarity] and #challengePools[entry.rarity] > 0 then
            total = total + entry.weight
        end
    end

    if total == 0 then
        return nil
    end

    local roll = math.random() * total

    local cumulative = 0
    for _, entry in ipairs(addonTable.RarityWeights) do
        if challengePools[entry.rarity] and #challengePools[entry.rarity] > 0 then
            cumulative = cumulative + entry.weight
        end
        if roll < cumulative then
            return entry.rarity
        end
    end
    return nil
end

function Roulette.Roll(reason)
    local challengePools = BuildRarityPools(reason)
    local rarity = RollRarity(challengePools)
    if not rarity then
        return nil
    end

    local pool = challengePools[rarity]

    return pool[math.random(#pool)]
end

function Roulette.GetChallenge(id)
    if not id then
        return nil
    end

    return addonTable.Challenges[id]
end

function Roulette.GetRarityColor(rarity)
    local colors = {
        Common = { 1, 1, 1 },
        Uncommon = { 0.12, 1, 0 },
        Rare = { 0, 0.44, 0.87 },
        Epic = { 0.64, 0.21, 0.93 },
        Legendary = { 1, 0.5, 0 },
    }

    return colors[rarity] or { 1, 1, 1 } 
end

function Roulette.GetRarityColorHexCode(rarity)
    local colors = {
        Common = { 1, 1, 1 },
        Uncommon = { 0.12, 1, 0 },
        Rare = { 0, 0.44, 0.87 },
        Epic = { 0.64, 0.21, 0.93 },
        Legendary = { 1, 0.5, 0 },
    }

    local selectedColor = colors[rarity] or { 1, 1, 1 }

    return string.format(
        "%02x%02x%02x",
        math.floor(selectedColor[1] * 255 + 0.5),
        math.floor(selectedColor[2] * 255 + 0.5),
        math.floor(selectedColor[3] * 255 + 0.5)
    )
end