local addonName, addonTable = ...

addonTable.FartSoundsUi = {}
local FartSoundsUi = addonTable.FartSoundsUi

local frame = CreateFrame("Frame")
local isActive = false
local isPaused = false
local sounds = {
    "Interface\\AddOns\\LidlRoulette\\src\\Media\\Sounds\\Farts\\BarkFart.ogg",
    "Interface\\AddOns\\LidlRoulette\\src\\Media\\Sounds\\Farts\\Fart1.ogg",
    "Interface\\AddOns\\LidlRoulette\\src\\Media\\Sounds\\Farts\\Fart2.ogg",
    "Interface\\AddOns\\LidlRoulette\\src\\Media\\Sounds\\Farts\\Fart3.ogg",
    "Interface\\AddOns\\LidlRoulette\\src\\Media\\Sounds\\Farts\\RipperFart.ogg",
}

frame:SetScript("OnEvent", function(_, event, unit)
    if event == "UNIT_SPELLCAST_SUCCEEDED" and unit == "player" and isActive and not isPaused then
        PlaySoundFile(sounds[math.random(#sounds)], "SFX")
    end
end)

function FartSoundsUi:Start()
    isActive = true
    isPaused = false
    frame:RegisterUnitEvent("UNIT_SPELLCAST_SUCCEEDED", "player")
end

function FartSoundsUi:Pause()
    if not isActive or isPaused then
        return
    end

    isPaused = true
    frame:UnregisterEvent("UNIT_SPELLCAST_SUCCEEDED")
end

function FartSoundsUi:Resume()
    if not isActive or not isPaused then
        return
    end

    isPaused = false
    frame:RegisterUnitEvent("UNIT_SPELLCAST_SUCCEEDED", "player")
end

function FartSoundsUi:Stop()
    if frame:IsEventRegistered("UNIT_SPELLCAST_SUCCEEDED") then
        frame:UnregisterEvent("UNIT_SPELLCAST_SUCCEEDED")
    end
    isActive = false
    isPaused = false
end