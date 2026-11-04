local addonName, addonTable = ...

-- targetPercent bezieht sich auf die Maximalpunktzahl inklusive Combo-Bonus. Der Bonus macht bei
-- langen Songs einen großen Teil aus, deshalb sehen die Werte niedrig aus: Sie entsprechen etwa
-- 70 % (easy), 75 % (medium) und 80 % (hard, legendary) getroffenen Objekten.
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
        targetPercent = 0.28,
    },
    {
        title = "Bakemonogatari - Renai Circulation",
        music = "Interface\\AddOns\\LidlRoulette\\src\\Media\\Sounds\\GuitarHero\\RenaiCirculation.ogg",
        chartSourceTitle = "Bakemonogatari - Renai Circulation",
        bpm = 120,
        duration = 90,
        beatOffset = 0,
        timingOffset = 0,
        stepsPerBeat = 2,
        difficulty = "medium",
        targetPercent = 0.3,
    },
    {
        title = "Leni Wöss - Aura",
        music = "Interface\\AddOns\\LidlRoulette\\src\\Media\\Sounds\\GuitarHero\\Aura.ogg",
        chartSourceTitle = "Leni Wöss - Auro",
        bpm = 98,
        duration = 132,
        beatOffset = 0,
        timingOffset = 0,
        stepsPerBeat = 2,
        difficulty = "hard",
        targetPercent = 0.27,
    },
    {
        title = "JoJo Steel Ball Run - Spin",
        music = "Interface\\AddOns\\LidlRoulette\\src\\Media\\Sounds\\GuitarHero\\Spin.ogg",
        chartSourceTitle = "JoJo Steel Ball Run - Spin",
        bpm = 73,
        duration = 90,
        beatOffset = 0,
        timingOffset = 0,
        stepsPerBeat = 2,
        difficulty = "easy",
        targetPercent = 0.34,
    },
    {
        title = "Micheal Jackson - Chicago",
        music = "Interface\\AddOns\\LidlRoulette\\src\\Media\\Sounds\\GuitarHero\\MichealJackson.ogg",
        chartSourceTitle = "Micheal Jackson - Chicago",
        bpm = 88,
        duration = 87,
        beatOffset = 0,
        timingOffset = 0,
        stepsPerBeat = 2,
        difficulty = "medium",
        targetPercent = 0.34,
    },
    {
        title = "1, 2 Oatmeal",
        music = "Interface\\AddOns\\LidlRoulette\\src\\Media\\Sounds\\GuitarHero\\Oatmeal.ogg",
        chartSourceTitle = "1, 2 Oatmeal",
        bpm = 124.5,
        duration = 132,
        beatOffset = 0,
        timingOffset = 0,
        stepsPerBeat = 2,
        difficulty = "hard",
        targetPercent = 0.24,
    },
    {
        title = "Kiryu - Bakamitai",
        music = "Interface\\AddOns\\LidlRoulette\\src\\Media\\Sounds\\GuitarHero\\Bakamitai.ogg",
        chartSourceTitle = "Kiryu - Bakamitai",
        bpm = 74,
        duration = 121,
        beatOffset = 0,
        timingOffset = 0,
        stepsPerBeat = 2,
        difficulty = "easy",
        targetPercent = 0.32,
    },
    {
        title = "Bring Me To Life",
        music = "Interface\\AddOns\\LidlRoulette\\src\\Media\\Sounds\\GuitarHero\\BringMeToLife.ogg",
        chartSourceTitle = "Bring Me To Life",
        bpm = 95,
        duration = 123,
        beatOffset = 0,
        timingOffset = 0,
        stepsPerBeat = 2,
        difficulty = "easy",
        targetPercent = 0.3,
    },
    {
        title = "Not Cute Anymore x Hit 'Em Up",
        music = "Interface\\AddOns\\LidlRoulette\\src\\Media\\Sounds\\GuitarHero\\NotCuteAnymoreXHitEmUp.ogg",
        chartSourceTitle = "Not Cute Anymore x Hit 'Em Up",
        bpm = 99,
        duration = 137,
        beatOffset = 0,
        timingOffset = 0,
        stepsPerBeat = 2,
        difficulty = "medium",
        targetPercent = 0.26,
    },
    {
        title = "Gary komm heim",
        music = "Interface\\AddOns\\LidlRoulette\\src\\Media\\Sounds\\GuitarHero\\GaryKommHeim.ogg",
        chartSourceTitle = "Gary komm heim",
        bpm = 80.85,
        duration = 104,
        beatOffset = 0,
        timingOffset = 0,
        stepsPerBeat = 2,
        difficulty = "easy",
        targetPercent = 0.34,
    },
    {
        title = "Go-Go Loser Ranger - Jikai Yokoku",
        music = "Interface\\AddOns\\LidlRoulette\\src\\Media\\Sounds\\GuitarHero\\GoGoLoserRanger.ogg",
        chartSourceTitle = "Go-Go Loser Ranger - Jikai Yokoku",
        bpm = 160,
        duration = 90,
        beatOffset = 0,
        timingOffset = 0,
        stepsPerBeat = 2,
        difficulty = "hard",
        targetPercent = 0.3,
    },
    {
        -- Legendäre Challenge: eigenes Chart mit Kreisen, Slidern, Reverse-Slidern und Spinnern.
        -- Wird nur gespielt, wenn die Challenge osuSong = "Pizza Tower - It's Pizza Time!" setzt.
        title = "Pizza Tower - It's Pizza Time!",
        music = "Interface\\AddOns\\LidlRoulette\\src\\Media\\Sounds\\OSU\\Songs\\PizzaTower.ogg",
        exclusive = true,
        bpm = 180,                  -- Grundtempo (bestimmt die Slider-Ticks), das Raster steht in osuSections
        duration = 229,
        beatOffset = 0,
        timingOffset = 0,
        stepsPerBeat = 2,
        difficulty = "legendary",
        targetPercent = 0.18,
        -- Das Chart folgt der Melodie. Hauptmotiv: Triller H-Cis-H-Cis-H-A (Kreis-Stream), danach langes Fis (Slider).
        -- Abschnitte mit bpm = 300 und stepsPerBeat = 8 haben kein festes Raster im Song: 1 Zeichen = 25 ms.
        -- Sonst gilt bei stepsPerBeat = 2: 1 Zeile im Hauptteil und im Chaos-Teil = 16 Beats.
        -- startTime = Sekunde des ersten Zeichens.
        -- o = Kreis | s = Slider | r = Reverse-Slider | p = Spinner | ~ = verlängert | - = Pause
        osuSections = {
            -- Intro
            {
                startTime = 0.5,
                bpm = 300,
                stepsPerBeat = 8,
                chart = [[
                    ---s~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
                    ~~~~~~~~~~~~~~~~~~~~~~~-----------------
                    -o--------------------------------------
                    ----------------------------------------
                    -----------------o-----------o----------
                    ----------------------------------------
                    ---------------------------------o------
                    ----------------------------------------
                    ----------------------------------------
                    ---------o----------o----------o--------
                    --o---------o---------------------------
                    --------o---------------o---------------
                    o-------------------------------------s~
                    ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
                    ~~-----o--------------------
                ]],
            },
            -- Hauptteil: 180 BPM
            {
                startTime = 15.368,
                bpm = 180,
                stepsPerBeat = 2,
                chart = [[
                    oo--o-o--oo---oo--oo--oo-oo-o-s~
                    ~~~~~~--o-o-o-o---o-oooooo-oo-o-
                    o-o-o-o-o--oo-o-o-o-oooooo-oo--o
                    o-o-o-o-o-o-o-o-o-o-oooooos~~~~~
                    ~~~-o-o-o-o-o-o--oo-oooooos~~~~~
                    ~~~-o-o---oo--oo-oo-oooooos~~~~-
                    o-o-o-o-o-o-o-o---o-oooooos~~~~~
                    ~~~-o-o-o-o---oo-oo-oooooos~~~~~
                    ~~~-o-o-o-o---oo--o-oooooos~~~~~
                    ~-o-o-o-oo--o-o-o--oo-o-o-o-o-o-
                    o-o-oo---oo-oo--o--oo-o--oo-o-o-
                    o-o--o-oo-o-o--oo-o--o-oo-o-o--s
                    ~~~~--oo-oo-oo--o--oo-o-o-o-o--o
                    o-o-o--o-oo---oo--oo--oo--o---oo
                    -oo-o-o-o-o-o-o-o-o-oooooos~~~~~
                    ~~~-o-o-o--oo-o--oo-oooooos~~~~~
                    ~~~-o-o--o-o--oo--oo--o----oo--o
                    o-o-oo----o-o--o-oo-o---o-o-o--o
                    o-o-o---o--oo--oo-o--o-oo---o-o-
                    --o-oo--o-o-o-o-o-o-o-o---oo--oo
                    --oo-oo-o-o-o-o-o-o-oo--o-o----o
                    o-o-o-o-o---o-o-o-o-oooooos~~~~~
                    ~~~-oo--o-o-o-o-o-o--o---s~~~~~~
                    ~-o-s~~~~~~~-----oo--s~~~~~~~---
                    ---o--oo--oo--oo--oo----o-o--oo-
                    o-o-o-o--s~~~~~~~------oo----o--
                    s~~~~~~~--o-o--s~~~~~~~-o-o--o--
                    ----oo----oo--oo-oo-oooooos~~~~~
                    ~~~-o-o-o--o-oo-o-o-oooooos~~~~~
                    ~~~-o-s~~~~~~~
                ]],
            },
            -- Übergang: Stabs und langer Akkord
            {
                startTime = 172.5,
                bpm = 300,
                stepsPerBeat = 8,
                chart = [[
                    --------o-----------o-----------o-------
                    -----o----------o-----------o---------o-
                    ---------o--------o---------o-----------
                    ----------------o---------r~~~~~~~~~~~~~
                    ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
                    ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
                    ~~~~~~~~~~~~~~--------o--------o--------
                    ----
                ]],
            },
            -- Chaos: Motiv auf 276 BPM über 138 BPM Kicks
            {
                startTime = 179.704,
                bpm = 276,
                stepsPerBeat = 2,
                chart = [[
                    o---o---o---o---o-s~~~~~~~--o---
                    o---o---o---o---o-s~~~~~~~--o---
                    o---o---o---o---o-s~~~~~~~--o---
                    o---o---o-o-o-o-o-o-o-----o-o-o-
                    o---o-o-o-o-o-o-s~~~~~~~~-o-o-o-
                    --o-o-o-o-o-o-o-s~~~~~~~~-o-o-o-
                    o-o-o---o-o-o-o-s~~~~~~~~-o-o-o-
                    o---o-o-o-o-o-
                ]],
            },
            -- Motiv wird langsamer, langes Fis
            {
                startTime = 205.65,
                bpm = 300,
                stepsPerBeat = 8,
                chart = [[
                    --o-----------o-------------o-----------
                    ---o------------------o-------------o---
                    ------------p~~~~~~~~~~~~~~~~~~~~~~~~~~~
                    ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
                    ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
                    ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
                    ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
                    ~~~~~~~~~~~~~~~~~~~~~~~~--------------
                ]],
            },
            -- Schluss: einzelne Stabs
            {
                startTime = 213.75,
                bpm = 300,
                stepsPerBeat = 8,
                chart = [[
                    ---o------------------------------------
                    --o--------------------o----------------
                    --o-------------------o-----------------
                    --o--------------------o----------------
                    --o-------------------------------------
                    --o-------------------o-----------------
                    --o-------------------o-----------------
                    --o-------------------o-----------------
                    --o-------------------------------------
                    --o-------------------o-----------------
                    --o-------------------o-----------------
                    --o-------------------o-----------------
                    --o---------o---------------------------
                    --o-------------------o---------o-------
                    ---o------------------o---------------
                ]],
            },
        },
    },
}
