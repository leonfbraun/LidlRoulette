local addonName, addonTable = ...

addonTable.Keybindings = {}

local Keybindings = addonTable.Keybindings
local bindingOwner = CreateFrame("Frame")
local movementKeys = { "W", "A", "S", "D" }
local movementActionNames = {
    MOVEFORWARD = "Vorwärts",
    MOVEBACKWARD = "Rückwärts",
    TURNLEFT = "Links drehen",
    TURNRIGHT = "Rechts drehen",
    STRAFELEFT = "Seitwärts links",
    STRAFERIGHT = "Seitwärts rechts",
}

local activeMode
local bindingsActive = false
local pendingApply = false
local pendingClear = false

local function RegisterForCombatEnd()
    bindingOwner:RegisterEvent("PLAYER_REGEN_ENABLED")
end

local function GetBindings(keys)
    local bindings = {}
    local actionsByKey = {}

    for _, key in ipairs(keys) do
        local action = GetBindingAction(key)
        if not action or action == "" then
            return nil, "Die Taste " .. key .. " ist nicht belegt."
        end
        if actionsByKey[key] then
            return nil, "Die Taste " .. key .. " ist mehrfach belegt."
        end

        actionsByKey[key] = action
        table.insert(bindings, { key = key, action = action })
    end

    return bindings
end

local function IsBindingKey(key)
    return key
        and key ~= ""
        and not key:match("^BINDING_HEADER_")
        and not key:match("^BINDING_NAME_")
end

local function GetActionButtonBindings()
    local buttonGroups = {}
    local actionsByKey = {}
    for index = 1, GetNumBindings() do
        local action, firstKey, secondKey = GetBinding(index)
        local buttonNumber = action and action:match("^ACTIONBUTTON(%d+)$")
        buttonNumber = tonumber(buttonNumber)
        if buttonNumber and buttonNumber >= 1 and buttonNumber <= 12 then
            local group = buttonGroups[buttonNumber]
            if not group then
                group = { action = action, buttonNumber = buttonNumber, keys = {} }
                buttonGroups[buttonNumber] = group
            end

            for keyIndex = 1, 2 do
                local key = keyIndex == 1 and firstKey or secondKey
                if IsBindingKey(key) then
                    if actionsByKey[key] and actionsByKey[key] ~= buttonNumber then
                        return nil, "Die Taste " .. key .. " ist mehreren Action Buttons zugewiesen."
                    end
                    if not actionsByKey[key] then
                        actionsByKey[key] = buttonNumber
                        table.insert(group.keys, key)
                    end
                end
            end
        end
    end

    local groups = {}
    for buttonNumber = 1, 12 do
        if buttonGroups[buttonNumber] then
            table.insert(groups, buttonGroups[buttonNumber])
        end
    end

    if #groups < 2 then
        return nil, "Mindestens zwei der Action Buttons 1–12 müssen belegt sein."
    end

    return groups
end

local function ShuffleBindings(bindings)
    local distinctActions = {}
    for _, binding in ipairs(bindings) do
        distinctActions[binding.action] = true
    end

    local distinctActionCount = 0
    for _ in pairs(distinctActions) do
        distinctActionCount = distinctActionCount + 1
    end
    if distinctActionCount < 2 then
        return nil
    end

    local shuffledBindings
    local changed
    repeat
        shuffledBindings = {}
        for index, binding in ipairs(bindings) do
            shuffledBindings[index] = binding
        end

        for index = #shuffledBindings, 2, -1 do
            local otherIndex = math.random(index)
            shuffledBindings[index], shuffledBindings[otherIndex] =
                shuffledBindings[otherIndex], shuffledBindings[index]
        end

        changed = false
        for index, binding in ipairs(bindings) do
            if binding.action ~= shuffledBindings[index].action then
                changed = true
                break
            end
        end
    until changed

    local result = {}
    for index, binding in ipairs(bindings) do
        result[index] = {
            key = binding.key,
            action = shuffledBindings[index].action,
        }
    end

    return result
end

local function ShuffleActionButtonBindings(groups)
    local shuffledActions = ShuffleBindings(groups)
    if not shuffledActions then
        return nil
    end

    local bindings = {}
    for index, group in ipairs(groups) do
        for _, key in ipairs(group.keys) do
            table.insert(bindings, {
                key = key,
                action = shuffledActions[index].action,
                buttonNumber = group.buttonNumber,
                assignedButtonNumber = tonumber(shuffledActions[index].action:match("^ACTIONBUTTON(%d+)$")),
            })
        end
    end

    return bindings
end

local function GetModeBindings(mode)
    if mode == "wasd" then
        return GetBindings(movementKeys)
    elseif mode == "actionbuttons" then
        return GetActionButtonBindings()
    end

    return nil, "Unbekannter Tasten-Challenge-Modus: " .. tostring(mode)
end

local function ApplyBindings()
    if not activeMode then
        pendingApply = false
        return
    end

    if InCombatLockdown() then
        pendingApply = true
        RegisterForCombatEnd()
        return
    end

    local bindings, errorMessage = GetModeBindings(activeMode)
    if not bindings then
        activeMode = nil
        pendingApply = false
        print("|cffff0000[Lidl Roulette]|r Tasten-Challenge konnte nicht gestartet werden: " .. errorMessage)
        return
    end

    local shuffledBindings
    if activeMode == "actionbuttons" then
        shuffledBindings = ShuffleActionButtonBindings(bindings)
    else
        shuffledBindings = ShuffleBindings(bindings)
    end
    if not shuffledBindings then
        activeMode = nil
        pendingApply = false
        print("|cffff0000[Lidl Roulette]|r Tasten-Challenge konnte nicht gestartet werden: Es gibt nicht genügend unterschiedliche Tastenbindungen zum Vertauschen.")
        return
    end

    local success, bindingError = pcall(function()
        for _, binding in ipairs(shuffledBindings) do
            SetOverrideBinding(bindingOwner, false, binding.key, binding.action)
        end
    end)

    if not success then
        ClearOverrideBindings(bindingOwner)
        activeMode = nil
        pendingApply = false
        bindingsActive = false
        print("|cffff0000[Lidl Roulette]|r Tastenbelegung konnte nicht geändert werden: " .. tostring(bindingError))
        return
    end

    pendingApply = false
    bindingsActive = true

    if activeMode == "wasd" then
        local mapping = {}
        for _, binding in ipairs(shuffledBindings) do
            local actionName = movementActionNames[binding.action] or binding.action
            table.insert(mapping, binding.key .. " = " .. actionName)
        end
        print("|cff2674cc[L|cffff0000i|rDL Roulette]|r Neue WASD-Belegung: " .. table.concat(mapping, ", "))
    else
        local mapping = {}
        for _, binding in ipairs(shuffledBindings) do
            table.insert(mapping, "Button " .. binding.buttonNumber .. " (" .. binding.key ..
                ") -> Button " .. binding.assignedButtonNumber)
        end
        print("|cff2674cc[L|cffff0000i|rDL Roulette]|r Action-Button-Belegung neu gemischt: " ..
            table.concat(mapping, ", "))
    end
end

local function ClearBindings()
    if not bindingsActive then
        pendingClear = false
        return
    end

    if InCombatLockdown() then
        pendingClear = true
        RegisterForCombatEnd()
        return
    end

    ClearOverrideBindings(bindingOwner)
    bindingsActive = false
    pendingClear = false
end

local function ProcessPendingChanges()
    if InCombatLockdown() then
        return
    end

    if pendingClear then
        ClearBindings()
    end
    if pendingApply and activeMode then
        ApplyBindings()
    end

    if not pendingApply and not pendingClear then
        bindingOwner:UnregisterEvent("PLAYER_REGEN_ENABLED")
    end
end

bindingOwner:SetScript("OnEvent", ProcessPendingChanges)

function Keybindings.Start(mode)
    if activeMode or bindingsActive then
        Keybindings.Stop()
    end

    activeMode = mode
    pendingApply = true
    ApplyBindings()
end

function Keybindings.Stop()
    activeMode = nil
    pendingApply = false
    ClearBindings()
    if not pendingClear then
        bindingOwner:UnregisterEvent("PLAYER_REGEN_ENABLED")
    end
end
