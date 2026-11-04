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
        title = "Bakemonogatari - Renai Circulation",
        music = "Interface\\AddOns\\LidlRoulette\\src\\Media\\Sounds\\GuitarHero\\RenaiCirculation.ogg",
        chartSourceTitle = "Bakemonogatari - Renai Circulation",
        bpm = 120,
        duration = 90,
        beatOffset = 0,
        timingOffset = 0,
        stepsPerBeat = 2,
        difficulty = "medium",
        targetPercent = 0.55,
    },
    {
        title = "Leni Wöss - Auro",
        music = "Interface\\AddOns\\LidlRoulette\\src\\Media\\Sounds\\GuitarHero\\Aura.ogg",
        chartSourceTitle = "Leni Wöss - Auro",
        bpm = 98,
        duration = 132,
        beatOffset = 0,
        timingOffset = 0,
        stepsPerBeat = 2,
        difficulty = "hard",
        targetPercent = 0.5,
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
        targetPercent = 0.6,
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
        targetPercent = 0.55,
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
        targetPercent = 0.5,
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
        targetPercent = 0.6,
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
        targetPercent = 0.6,
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
        targetPercent = 0.55,
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
        targetPercent = 0.6,
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
        beatOffset = 0,
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
