local addonName, addonTable = ...

addonTable.DevilMayCryComboUi = {}
local ComboUi = addonTable.DevilMayCryComboUi

local COMBO_TIMEOUT = 8
local MAX_METER_HITS = 40
local MUSIC_FADE_SECONDS = 3
local MUSIC_FILE = "Interface\\AddOns\\LidlRoulette\\src\\Media\\Sounds\\BuryTheLight.ogg"
local frame
local musicFrame
local rankText
local rankNameText
local comboText
local comboLabelText
local countdownText
local meter
local comboCount = 0
local lastHitTime
local isActive = false
local isPaused = false
local musicVolumeBeforeChallenge
local comboMusicPlaying = false

local ranks = {
    { hits = 40, rank = "SSS", name = "Smokin' Sexy Style!", color = { 1, 0.25, 0.42 } },
    { hits = 25, rank = "SS", name = "Sick Skills", color = { 1, 0.3, 0.2 } },
    { hits = 16, rank = "S", name = "Savage!", color = { 1, 0.55, 0.12 } },
    { hits = 10, rank = "A", name = "Apocalyptic!", color = { 1, 0.82, 0.12 } },
    { hits = 6, rank = "B", name = "Badass!", color = { 0.35, 1, 0.42 } },
    { hits = 3, rank = "C", name = "Crazy!", color = { 0.25, 0.8, 1 } },
    { hits = 0, rank = "D", name = "Dismal", color = { 0.9, 0.9, 0.9 } },
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
    musicFrame = musicFrame or CreateFrame("Frame")
    musicFrame:SetScript("OnUpdate", nil)

    if musicVolumeBeforeChallenge == nil then
        musicVolumeBeforeChallenge = tonumber(GetCVar("Sound_MusicVolume"))
    end
    if musicVolumeBeforeChallenge == nil then
        return
    end

    SetCVar("Sound_MusicVolume", "0")
    PlayMusic(MUSIC_FILE)
    comboMusicPlaying = true
    FadeMusicVolume(musicVolumeBeforeChallenge)
end

local function StopComboMusic()
    if not comboMusicPlaying or musicVolumeBeforeChallenge == nil then
        return
    end

    local originalVolume = musicVolumeBeforeChallenge
    FadeMusicVolume(0, function()
        StopMusic()
        SetCVar("Sound_MusicVolume", tostring(originalVolume))
        musicVolumeBeforeChallenge = nil
        comboMusicPlaying = false
    end)
end

local function Initialize()
    if frame then
        return
    end

    frame = CreateFrame("Frame", "LidlRouletteDevilMayCryComboFrame", UIParent, "BackdropTemplate")
    frame:SetSize(330, 150)
    frame:SetPoint("RIGHT", UIParent, "RIGHT", -90, 40)
    frame:SetFrameStrata("HIGH")
    frame:SetClampedToScreen(true)
    frame:SetBackdrop({
        bgFile = "Interface\\Buttons\\WHITE8X8",
        edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border",
        edgeSize = 12,
        insets = { left = 3, right = 3, top = 3, bottom = 3 },
    })
    frame:SetBackdropColor(0.025, 0.015, 0.02, 0.9)
    frame:SetBackdropBorderColor(0.72, 0.06, 0.1, 1)
    frame:SetMovable(true)
    frame:EnableMouse(true)
    frame:RegisterForDrag("LeftButton")
    frame:SetScript("OnDragStart", frame.StartMoving)
    frame:SetScript("OnDragStop", frame.StopMovingOrSizing)

    local accent = frame:CreateTexture(nil, "ARTWORK")
    accent:SetPoint("TOPLEFT", frame, "TOPLEFT", 8, -8)
    accent:SetPoint("BOTTOMLEFT", frame, "BOTTOMLEFT", 8, 8)
    accent:SetWidth(4)
    accent:SetColorTexture(0.88, 0.04, 0.09, 1)

    local styleTitle = frame:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    styleTitle:SetPoint("TOPLEFT", frame, "TOPLEFT", 24, -16)
    styleTitle:SetText("STYLE RANK")
    styleTitle:SetTextColor(1, 0.25, 0.2)

    rankText = frame:CreateFontString(nil, "OVERLAY", "GameFontNormalHuge")
    rankText:SetPoint("TOPLEFT", frame, "TOPLEFT", 20, -27)
    rankText:SetWidth(140)
    rankText:SetJustifyH("LEFT")
    rankText:SetFont("Fonts\\FRIZQT__.TTF", 62, "OUTLINE")

    rankNameText = frame:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
    rankNameText:SetPoint("BOTTOMLEFT", frame, "BOTTOMLEFT", 24, 35)
    rankNameText:SetWidth(165)
    rankNameText:SetJustifyH("LEFT")
    rankNameText:SetFont("Fonts\\FRIZQT__.TTF", 14, "OUTLINE")

    comboText = frame:CreateFontString(nil, "OVERLAY", "GameFontNormalHuge")
    comboText:SetPoint("TOPRIGHT", frame, "TOPRIGHT", -20, -27)
    comboText:SetWidth(145)
    comboText:SetJustifyH("RIGHT")
    comboText:SetFont("Fonts\\FRIZQT__.TTF", 43, "OUTLINE")
    comboText:SetTextColor(1, 1, 1)

    comboLabelText = frame:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    comboLabelText:SetPoint("TOPRIGHT", comboText, "BOTTOMRIGHT", 0, -1)
    comboLabelText:SetText("HIT COMBO")
    comboLabelText:SetTextColor(0.9, 0.82, 0.82)

    countdownText = frame:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
    countdownText:SetPoint("TOPRIGHT", comboLabelText, "BOTTOMRIGHT", 0, -4)
    countdownText:SetFont("Fonts\\FRIZQT__.TTF", 15, "OUTLINE")
    countdownText:SetTextColor(1, 0.35, 0.2)

    meter = CreateFrame("StatusBar", nil, frame)
    meter:SetPoint("BOTTOMLEFT", frame, "BOTTOMLEFT", 24, 17)
    meter:SetPoint("BOTTOMRIGHT", frame, "BOTTOMRIGHT", -20, 17)
    meter:SetHeight(7)
    meter:SetStatusBarTexture("Interface\\TargetingFrame\\UI-StatusBar")
    meter:SetMinMaxValues(0, MAX_METER_HITS)
    meter:SetValue(0)
    meter:SetStatusBarColor(0.9, 0.04, 0.08)

    frame:SetScript("OnEvent", function(_, event, unitTarget, combatAction)
        if event ~= "UNIT_COMBAT" or not isActive or isPaused then
            return
        end

        if unitTarget == "target" and UnitCanAttack("player", "target") and combatAction == "WOUND" then
            ComboUi:RegisterHit()
        end
    end)

    frame:Hide()
end

local function GetRank(hits)
    for _, rank in ipairs(ranks) do
        if hits >= rank.hits then
            return rank
        end
    end
    return ranks[#ranks]
end

local function ResetCombo()
    comboCount = 0
    lastHitTime = nil
    if frame then
        frame:SetScript("OnUpdate", nil)
        frame:Hide()
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
    countdownText:SetText(string.format("%.1fs", remaining))

    if remaining <= 0 then
        ResetCombo()
    end
end

local function StartComboCountdown()
    frame:SetScript("OnUpdate", UpdateComboCountdown)
end

function ComboUi:RegisterHit()
    if not isActive or isPaused then
        return
    end

    Initialize()
    local wasVisible = frame:IsShown()
    comboCount = comboCount + 1
    lastHitTime = GetTime()

    local rank = GetRank(comboCount)
    rankText:SetText(rank.rank)
    rankText:SetTextColor(rank.color[1], rank.color[2], rank.color[3])
    rankNameText:SetText(rank.name)
    rankNameText:SetTextColor(rank.color[1], rank.color[2], rank.color[3])
    comboText:SetText(tostring(comboCount))
    meter:SetValue(math.min(comboCount, MAX_METER_HITS))
    meter:SetStatusBarColor(rank.color[1], rank.color[2], rank.color[3])
    countdownText:SetText(string.format("%.1fs", COMBO_TIMEOUT))
    frame:Show()
    if not wasVisible then
        StartComboMusic()
    end
    StartComboCountdown()
end

function ComboUi:Start()
    Initialize()
    ResetCombo()
    isActive = true
    isPaused = false
    frame:RegisterUnitEvent("UNIT_COMBAT", "target")
end

function ComboUi:Pause()
    if not isActive or isPaused then
        return
    end

    isPaused = true
    frame:UnregisterEvent("UNIT_COMBAT")
    frame:SetScript("OnUpdate", nil)
    StopComboMusic()
end

function ComboUi:Resume()
    if not isActive or not isPaused then
        return
    end

    isPaused = false
    if frame:IsShown() then
        StartComboMusic()
    end
    if lastHitTime then
        lastHitTime = GetTime()
        countdownText:SetText(string.format("%.1fs", COMBO_TIMEOUT))
        StartComboCountdown()
    end
    frame:RegisterUnitEvent("UNIT_COMBAT", "target")
end

function ComboUi:Stop()
    if frame and frame:IsEventRegistered("UNIT_COMBAT") then
        frame:UnregisterEvent("UNIT_COMBAT")
    end
    isActive = false
    isPaused = false
    ResetCombo()
end