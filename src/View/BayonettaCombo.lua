local addonName, addonTable = ...

addonTable.BayonettaComboUi = {}
local ComboUi = addonTable.BayonettaComboUi

local COMBO_TIMEOUT = 8
local SPELL_HIT_WINDOW = 1.25
local MAX_VISIBLE_HITS = 3
local MUSIC_FADE_SECONDS = 3
local frame
local musicFrame
local variantTitle
local pointsText
local pointsLabel
local multiplierText
local countdownText
local accent
local hitRows = {}
local recentHits = {}
local comboPoints = 0
local highScore = 0
local lastHitTime
local pendingSpellHitUntil
local pendingSpellID
local activeVariant
local isActive = false
local isPaused = false
local musicVolumeBeforeCombo
local comboMusicPlaying = false

local variants = {
    [1] = {
        name = "BAYONETTA I",
        subtitle = "UMBRAN WITCH",
        music = "Interface\\AddOns\\LidlRoulette\\src\\Media\\Sounds\\Bayonetta1.ogg",
        background = { 0.035, 0.012, 0.035, 0.96 },
        border = { 0.78, 0.24, 0.48, 1 },
        accent = { 0.95, 0.18, 0.38, 1 },
        score = { 1, 0.78, 0.42 },
        rowBackground = { 0.045, 0.015, 0.075, 0.94 },
    },
    [2] = {
        name = "BAYONETTA II",
        subtitle = "WITCH TIME",
        music = "Interface\\AddOns\\LidlRoulette\\src\\Media\\Sounds\\Bayonetta2.ogg",
        background = { 0.012, 0.035, 0.075, 0.96 },
        border = { 0.26, 0.7, 0.92, 1 },
        accent = { 0.2, 0.82, 1, 1 },
        score = { 0.72, 0.92, 1 },
        rowBackground = { 0.01, 0.035, 0.1, 0.94 },
    },
}

local function FadeMusicVolume(targetVolume, onFinished)
    musicFrame = musicFrame or CreateFrame("Frame")
    local startVolume = tonumber(GetCVar("Sound_MusicVolume")) or targetVolume
    local elapsed = 0

    musicFrame:SetScript("OnUpdate", function(self, delta)
        elapsed = elapsed + delta
        local progress = math.min(elapsed / MUSIC_FADE_SECONDS, 1)
        local volume = startVolume + (targetVolume - startVolume) * progress
        SetCVar("Sound_MusicVolume", string.format("%.3f", volume))

        if progress >= 1 then
            self:SetScript("OnUpdate", nil)
            if onFinished then
                onFinished()
            end
        end
    end)
end

local function StartComboMusic()
    if not activeVariant then
        return
    end

    musicFrame = musicFrame or CreateFrame("Frame")
    musicFrame:SetScript("OnUpdate", nil)

    if musicVolumeBeforeCombo == nil then
        musicVolumeBeforeCombo = tonumber(GetCVar("Sound_MusicVolume"))
    end
    if musicVolumeBeforeCombo == nil then
        return
    end

    SetCVar("Sound_MusicVolume", "0")
    PlayMusic(activeVariant.music)
    comboMusicPlaying = true
    FadeMusicVolume(musicVolumeBeforeCombo)
end

local function StopComboMusic()
    if not comboMusicPlaying or musicVolumeBeforeCombo == nil then
        return
    end

    local originalVolume = musicVolumeBeforeCombo
    FadeMusicVolume(0, function()
        StopMusic()
        SetCVar("Sound_MusicVolume", tostring(originalVolume))
        musicVolumeBeforeCombo = nil
        comboMusicPlaying = false
    end)
end

local function Initialize()
    if frame then
        return
    end

    frame = CreateFrame("Frame", "LidlRouletteBayonettaComboFrame", UIParent, "BackdropTemplate")
    frame:SetSize(430, 245)
    frame:SetPoint("RIGHT", UIParent, "RIGHT", -90, 40)
    frame:SetFrameStrata("HIGH")
    frame:SetClampedToScreen(true)
    frame:SetBackdrop({
        bgFile = "Interface\\Buttons\\WHITE8X8",
        edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border",
        edgeSize = 12,
        insets = { left = 3, right = 3, top = 3, bottom = 3 },
    })
    frame:SetMovable(true)
    frame:EnableMouse(true)
    frame:RegisterForDrag("LeftButton")
    frame:SetScript("OnDragStart", frame.StartMoving)
    frame:SetScript("OnDragStop", frame.StopMovingOrSizing)

    accent = frame:CreateTexture(nil, "ARTWORK")
    accent:SetPoint("TOPLEFT", frame, "TOPLEFT", 8, -8)
    accent:SetPoint("BOTTOMLEFT", frame, "BOTTOMLEFT", 8, 8)
    accent:SetWidth(4)

    variantTitle = frame:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    variantTitle:SetPoint("TOPLEFT", frame, "TOPLEFT", 28, -16)
    variantTitle:SetWidth(105)
    variantTitle:SetJustifyH("LEFT")
    variantTitle:SetFont("Fonts\\FRIZQT__.TTF", 10, "OUTLINE")

    pointsLabel = frame:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
    pointsLabel:SetPoint("TOP", frame, "TOP", 0, -14)
    pointsLabel:SetFont("Fonts\\FRIZQT__.TTF", 22, "OUTLINE")
    pointsLabel:SetText("Combo Points")
    pointsLabel:SetTextColor(1, 0.94, 0.78)

    multiplierText = frame:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    multiplierText:SetPoint("TOPRIGHT", frame, "TOPRIGHT", -28, -20)
    multiplierText:SetFont("Fonts\\FRIZQT__.TTF", 17, "OUTLINE")
    multiplierText:SetText("x1.00")
    multiplierText:SetTextColor(1, 0.94, 0.78)

    pointsText = frame:CreateFontString(nil, "OVERLAY", "GameFontNormalHuge")
    pointsText:SetPoint("CENTER", frame, "CENTER", 0, 50)
    pointsText:SetWidth(360)
    pointsText:SetJustifyH("CENTER")
    pointsText:SetFont("Fonts\\FRIZQT__.TTF", 47, "OUTLINE")

    countdownText = frame:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
    countdownText:SetPoint("BOTTOMRIGHT", frame, "BOTTOMRIGHT", -28, 12)
    countdownText:SetFont("Fonts\\FRIZQT__.TTF", 12, "OUTLINE")
    countdownText:SetTextColor(1, 0.4, 0.55)

    for index = 1, MAX_VISIBLE_HITS do
        local row = CreateFrame("Frame", nil, frame)
        row:SetHeight(25)
        row:SetPoint("TOPLEFT", frame, "TOPLEFT", 31, -112 - ((index - 1) * 31))
        row:SetPoint("TOPRIGHT", frame, "TOPRIGHT", -31, -112 - ((index - 1) * 31))

        row.background = row:CreateTexture(nil, "BACKGROUND")
        row.background:SetAllPoints()
        row.background:SetTexture("Interface\\Buttons\\WHITE8X8")

        row.accent = row:CreateTexture(nil, "ARTWORK")
        row.accent:SetPoint("TOPLEFT", row, "TOPLEFT", 0, 0)
        row.accent:SetPoint("BOTTOMLEFT", row, "BOTTOMLEFT", 0, 0)
        row.accent:SetWidth(3)

        row.icon = row:CreateTexture(nil, "OVERLAY")
        row.icon:SetSize(20, 20)
        row.icon:SetPoint("LEFT", row, "LEFT", 8, 0)

        row.label = row:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
        row.label:SetPoint("LEFT", row.icon, "RIGHT", 8, 0)
        row.label:SetWidth(270)
        row.label:SetJustifyH("LEFT")
        row.label:SetFont("Fonts\\FRIZQT__.TTF", 12, "OUTLINE")

        row.points = row:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
        row.points:SetPoint("RIGHT", row, "RIGHT", -11, 0)
        row.points:SetFont("Fonts\\FRIZQT__.TTF", 17, "OUTLINE")

        hitRows[index] = row
        row:Hide()
    end

    frame:SetScript("OnEvent", function(_, event, unit, eventArg, spellID)
        if not isActive or isPaused then
            return
        end

        if event == "UNIT_SPELLCAST_SUCCEEDED" then
            if unit == "player" and UnitCanAttack("player", "target") then
                pendingSpellHitUntil = GetTime() + SPELL_HIT_WINDOW
                pendingSpellID = spellID
            end
            return
        end

        if event == "UNIT_COMBAT" and unit == "target"
            and UnitCanAttack("player", "target") and eventArg == "WOUND" then
            local isSpellHit = pendingSpellHitUntil and GetTime() <= pendingSpellHitUntil
            local points = isSpellHit and 2 or 1
            local hitSpellID = isSpellHit and pendingSpellID or nil
            pendingSpellHitUntil = nil
            pendingSpellID = nil
            ComboUi:RegisterHit(points, hitSpellID, isSpellHit)
        end
    end)

    frame:Hide()
end

local function ApplyVariant()
    frame:SetBackdropColor(activeVariant.background[1], activeVariant.background[2], activeVariant.background[3], activeVariant.background[4])
    frame:SetBackdropBorderColor(activeVariant.border[1], activeVariant.border[2], activeVariant.border[3], activeVariant.border[4])
    accent:SetColorTexture(activeVariant.accent[1], activeVariant.accent[2], activeVariant.accent[3], activeVariant.accent[4])
    variantTitle:SetText(activeVariant.name .. "  /  " .. activeVariant.subtitle)
    variantTitle:SetTextColor(activeVariant.score[1], activeVariant.score[2], activeVariant.score[3])
    pointsText:SetTextColor(activeVariant.score[1], activeVariant.score[2], activeVariant.score[3])
    multiplierText:SetTextColor(activeVariant.score[1], activeVariant.score[2], activeVariant.score[3])
    for _, row in ipairs(hitRows) do
        row.background:SetColorTexture(activeVariant.rowBackground[1], activeVariant.rowBackground[2], activeVariant.rowBackground[3], activeVariant.rowBackground[4])
        row.accent:SetColorTexture(activeVariant.accent[1], activeVariant.accent[2], activeVariant.accent[3], 1)
    end
end

local function RefreshHitRows()
    for index, row in ipairs(hitRows) do
        local hit = recentHits[index]
        if hit then
            local icon = hit.spellID and C_Spell and C_Spell.GetSpellTexture(hit.spellID)
            row.icon:SetTexture(icon or "Interface\\Icons\\Ability_MeleeDamage")
            row.label:SetText(hit.isSpell and "SPELL HIT" or "AUTO ATTACK")
            row.label:SetTextColor(activeVariant.score[1], activeVariant.score[2], activeVariant.score[3])
            row.points:SetText("+" .. tostring(hit.points))
            row.points:SetTextColor(activeVariant.score[1], activeVariant.score[2], activeVariant.score[3])
            row:Show()
        else
            row:Hide()
        end
    end
end

local function ResetCombo()
    comboPoints = 0
    lastHitTime = nil
    pendingSpellHitUntil = nil
    if frame then
        frame:SetScript("OnUpdate", nil)
        frame:Hide()
    end
    for index = 1, #recentHits do
        recentHits[index] = nil
    end
    for _, row in ipairs(hitRows) do
        row:Hide()
    end
    if countdownText then
        countdownText:SetText("")
    end
    StopComboMusic()
end

local function UpdateComboCountdown()
    if not lastHitTime then
        return
    end

    local remaining = math.max(0, COMBO_TIMEOUT - (GetTime() - lastHitTime))
    countdownText:SetText(string.format("COMBO %.1fs", remaining))
    if remaining <= 0 then
        ResetCombo()
    end
end

function ComboUi:RegisterHit(points, spellID, isSpell)
    if not isActive or isPaused then
        return
    end

    Initialize()
    local wasVisible = frame:IsShown()
    if not wasVisible and not activeVariant then
        activeVariant = variants[math.random(2)]
        ApplyVariant()
    end
    comboPoints = comboPoints + points
    highScore = math.max(highScore, comboPoints)
    lastHitTime = GetTime()

    pointsText:SetText(string.format("%04d", comboPoints))
    table.insert(recentHits, 1, { points = points, spellID = spellID, isSpell = isSpell })
    while #recentHits > MAX_VISIBLE_HITS do
        table.remove(recentHits)
    end
    RefreshHitRows()
    countdownText:SetText(string.format("COMBO %.1fs", COMBO_TIMEOUT))
    frame:Show()
    if not wasVisible then
        StartComboMusic()
    end
    frame:SetScript("OnUpdate", UpdateComboCountdown)
end

function ComboUi:Start()
    Initialize()
    ResetCombo()
    comboPoints = 0
    highScore = 0
    pendingSpellHitUntil = nil
    activeVariant = nil
    isActive = true
    isPaused = false
    frame:RegisterUnitEvent("UNIT_COMBAT", "target")
    frame:RegisterUnitEvent("UNIT_SPELLCAST_SUCCEEDED", "player")
end

function ComboUi:Pause()
    if not isActive or isPaused then
        return
    end

    isPaused = true
    frame:UnregisterEvent("UNIT_COMBAT")
    frame:UnregisterEvent("UNIT_SPELLCAST_SUCCEEDED")
    frame:SetScript("OnUpdate", nil)
    StopComboMusic()
end

function ComboUi:Resume()
    if not isActive or not isPaused then
        return
    end

    isPaused = false
    if frame:IsShown() then
        lastHitTime = GetTime()
        countdownText:SetText(string.format("COMBO %.1fs", COMBO_TIMEOUT))
        StartComboMusic()
        frame:SetScript("OnUpdate", UpdateComboCountdown)
    end
    pendingSpellHitUntil = nil
    frame:RegisterUnitEvent("UNIT_COMBAT", "target")
    frame:RegisterUnitEvent("UNIT_SPELLCAST_SUCCEEDED", "player")
end

function ComboUi:Stop()
    local finalHighScore = isActive and highScore or nil
    if frame then
        if frame:IsEventRegistered("UNIT_COMBAT") then
            frame:UnregisterEvent("UNIT_COMBAT")
        end
        if frame:IsEventRegistered("UNIT_SPELLCAST_SUCCEEDED") then
            frame:UnregisterEvent("UNIT_SPELLCAST_SUCCEEDED")
        end
    end
    isActive = false
    isPaused = false
    ResetCombo()
    comboPoints = 0
    highScore = 0
    activeVariant = nil
    return finalHighScore
end