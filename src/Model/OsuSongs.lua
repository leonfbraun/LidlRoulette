local addonName, addonTable = ...

addonTable.OsuSongs = {
    {
        title = "Sea Shanty 2 (Trap Remix)",
        music = "Interface\\AddOns\\LidlRoulette\\src\\Media\\Sounds\\OSU\\Songs\\SeaShanty2TrapRemix.ogg",
        chartSourceTitle = "Sea Shanty 2 (Trap Remix)",
        bpm = 120,
        duration = 110,
        beatOffset = 0,
        timingOffset = 0,
        stepsPerBeat = 2,
        difficulty = "hard",
        targetPercent = 0.5,
    },
    {
        -- Legendäre Challenge: eigenes Chart mit Kreisen, Slidern, Reverse-Slidern und Spinnern.
        -- Wird nur gespielt, wenn die Challenge osuSong = "Pizza Tower - It's Pizza Time!" setzt.
        title = "Pizza Tower - It's Pizza Time!",
        music = "Interface\\AddOns\\LidlRoulette\\src\\Media\\Sounds\\OSU\\Songs\\PizzaTower.ogg",
        exclusive = true,
        bpm = 180,
        duration = 229,
        beatOffset = 0.035,
        timingOffset = 0,
        stepsPerBeat = 4,           -- 1 Zeichen im Chart = 1/16-Note
        difficulty = "legendary",
        targetPercent = 0.5,
        -- o = Kreis | s = Slider | r = Reverse-Slider | p = Spinner | ~ = verlängert | - = Pause
        -- Eine Zeile entspricht 4 Takten.
        osuChart = [[
            ----------------r~~~~~~~~~~~--o-s~~~~~~-----o-o-o---o-------o-o-
            s~~~~~--s~~~~~--s~~~~~--o-------r~~~~~~~~~~~--o-----o---s~~~~~~~
            ~~p~~~~~~~~~~~~~~~~~~~~~~~~~~~~~--------o---o---o-o-----o-o-----
            o---s~~~~~~~~~--o---o---o---o---o---s~~~~~~~~~--o-o-o---o-o-o-o-
            o---o---o---o---o---o---o---o---s~~~~~~-----o-o-o---o---o-----o-
            o-o-o---s~~~~~--o---o---o---o---r~~~~~~~~~~~--o-o-o-o---o-o-o-o-
            o---o---o---o---o---o---o---o---s~~~~~~-----o-o-o---o---o-o-----
            o-o-o---s~~~~~--o---o---o-----o-r~~~~~~~~~~~--o-o-o-o---o-o-o-o-
            o---o---o---o---o---o---o-----o-s~~~~~~-----o-o-o---o---o---o---
            o---o-o-o-o-o---o---o-o-o---o-o-r~~~~~~~~~~~--o-o-o-ooo-o-o-o-o-
            o-o-o-o-o---o---o---o-o-o-o-o---s~~~~~~---o-o-o-o---o---o-o-o-o-
            o-o-o-o-o---o---o---o-o-o-o-o---r~~~~~~~~~~~--o-o-o-o-o-o-ooo-o-
            o-o-o---o---o-o-o---o-o-o---o-o-s~~~~~~---o-o-o-o-o-o-o-o---o---
            o---o-o-s~~~~~--o---o---o---o---r~~~~~~~~~~~--o-o-o-o-o-o---o-o-
            o---o-o-----o---o---o-o-----o---s~~~~~~-----o-o-o---o-------o-o-
            o---o-o-s~~~~~--o---o---o---o---r~~~~~~~~~~~--o-o-o-o-o-o-ooo-o-
            o---o-------o-o-o---o-o-----o---s~~~~~~-----o-o-o---o-o-o---o-o-
            o-o-o---s~~~~~--o---o---o---o---r~~~~~~~~~~~--o-o-o-o-o-ooo-o-o-
            o---o-o-----o---o---o-o-----o---s~~~~~~---o-o-o-o---o---o-o-o-o-
            o-o---o-s~~~~~--o---o---o---o---r~~~~~~~~~~~--o-o-ooo-o-o---o---
            o---o---o---o---o---o---o---o---s~~~~~~---o-o---o---o-------o-o-
            o-o-o---s~~~~~--o---o---o---o---r~~~~~~~~~~~--o-o-o-o-o-o-o-ooo-
            o-o-o-o-o---o---o---o-o-o---o-o-s~~~~~~---o-o-o-o---o-o-o---o-o-
            o-o-o-o-o---o---o---o---o-o-o-o-r~~~~~~~~~~~--o-o--oo-o-o-o-ooo-
            o-o-o-o-o---o---o---o---o-o-o-o-s~~~~~~---o-o-o-o---o-o-o---o-o-
            o-o-o-o-o---o---o---o---o-o-o-o-r~~~~~~~~~~~--o-o-o-oo-oo-ooo---
            o-o-o-o-o---o---o---o-o-o---o-o-s~~~~~~---o-o-o-o---o-o-o---o-o-
            o-o-o---o---o-o-o---o-o-o---o-o-r~~~~~~~~~~~--o-o-o-o-o-ooo-o-o-
            o-o-o-o-o---o---o---o-o-o---o-o-s~~~~~~---o-o-o-o-o-o---o---o-o-
            o---o-o-o---o-o-o---o-o-o---o-o-r~~~~~~~~~~~--o-o---o-o-o-o-o-o-
            o-o-o---o---o-o-o---o-o-o---o-o-s~~~~~~---o-o-o-o---o-o-o---o-o-
            o---o-o-o---o-o-o---o-o-o---o-o-r~~~~~~~~~~~--o-o-o-o-o-ooo-o-o-
            r~~~~~~~p~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~-------
            -o--o--os~~~~~--o-o-o---o-o-o---r~~~~~~~~~~~--o-oo--oo--oo---o--
            -o----o---o---o-o--o----o--o----s~~~~~~--o--o---o----o----o--o--
            o-o---o-s~~~~~----o-o---o---o---r~~~~~~~~~~~---ooo---o---oo--oo-
            o-o-------o---o-o--o--o-o---o--os~~~~~~--o--o-o-o---o-o--o---o-o
            o-o----o--o-o-o-o---o-o-o---o--or~~~~~~~~~~~--o-oo---oo--oo-o-oo
            o--o--o-o--o---oo---o--o-----o--s~~~~~~--o--o---o----o----o----o
            o---o-o-s~~~~~--o-------o-o-o---r~~~~~~~~~~~--o-oo-ooo--oo------
            s~~~~~--r~~~~~~~~p~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
            ~~~~~~~~~~---------s~~~--s~~~~--s~~--s~~~~~~~~--s~~~~~~~~~~--o--
            s~~~~~~--s~~~~--r~~~~~~~--s~~~--s~~~~~~~~~--o---o---s~~~~-------
            -
        ]],
    },
}

-- Alle Guitar-Hero-Songs sind automatisch auch in Osu! spielbar (Chart wird beim Start umgewandelt).
-- Ein eigener Eintrag oben mit gleichem chartSourceTitle hat Vorrang.
local TARGET_PERCENT_BY_DIFFICULTY = { easy = 0.6, medium = 0.55, hard = 0.5 }

local configuredCharts = {}
for _, osuSong in ipairs(addonTable.OsuSongs) do
    if osuSong.chartSourceTitle then
        configuredCharts[osuSong.chartSourceTitle] = true
    end
end

for _, guitarSong in ipairs(addonTable.GuitarHeroSongs) do
    if not configuredCharts[guitarSong.title] then
        table.insert(addonTable.OsuSongs, {
            title = guitarSong.title,
            music = guitarSong.music,
            chartSourceTitle = guitarSong.title,
            bpm = guitarSong.bpm,
            duration = guitarSong.duration,
            beatOffset = guitarSong.beatOffset,
            timingOffset = 0,
            stepsPerBeat = guitarSong.stepsPerBeat,
            difficulty = guitarSong.difficulty,
            targetPercent = TARGET_PERCENT_BY_DIFFICULTY[guitarSong.difficulty],
        })
    end
end
