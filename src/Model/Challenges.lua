local addonName, addonTable = ...

addonTable.RarityWeights = {
    { rarity="Legendary", weight=3 },
    { rarity="Epic", weight=12 },
    { rarity="Rare", weight=20 },
    { rarity="Uncommon", weight=25 },
    { rarity="Common", weight=40 },
    { rarity="poor", weight=0 },
}

addonTable.ChallengeTags = { "Positiv", "Negativ", "Sport", "Clanker", "Musik" }

addonTable.Challenges = {
    { rarity= "Common", tags={ "Negativ", "Sport" }, title= "Jump-Style", description="Mache 30 Jumping Jacks!"},
    { rarity= "Common", tags={ "Negativ", "Sport" }, title= "Liegestütze", description="Mache sofort 10 Liegestütze!"},
    { rarity= "Common", tags={ "Negativ" }, timeInSeconds=300, title= "Floor is lava", description="Du darfst für 5 Minuten mit keinem Körperteil den Boden berühren. Kleidung schützt nicht vor Verbrennungen."},
    { rarity= "Common", tags={ "Positiv", "Sport" }, title= "You are so tight!", description="Dehne deinen Nacken! (3x mal in jede Richtung)"},
    { rarity= "Common", tags={ "Negativ" }, timeInSeconds=1200, title= "Sprich Deutsch du hs", description="Keine Anglizismen für 20 Minuten. Jeder Verstoß kostet 1 Silber! (Lvl 10 => 2s, Lvl 20 => 3s, ...)" },
    { rarity= "Common", tags={ "Negativ"}, title="Janitor", description="Crafte einem anderen Spieler ein Item" },
    { rarity= "Common", tags={ "Negativ"}, timeInSeconds=600, title="POV", description="Spiele die nächsten 10 Minuten in First Person" },
    { rarity= "Common", tags={ "Negativ" }, title="Grindset", description="Steigere einen deiner Berufe um 5 Level" },
    { rarity= "Common", tags={ "Positiv" }, timeInSeconds=900, title="Lidl-DJ", description="Du bist jetzt für 15 Minuten DJ. Spiele mit dem Lidl Einkaufshits bot ein paar Banger ab"},
    { rarity= "Common", tags={ "Negativ", "Sport" }, title= "Get low", description="Mache 10 Bodyweight Squats, Full ROM"},
    { rarity= "Uncommon", tags={ "Negativ", "Clanker" }, timeInSeconds=600, keybindingShuffle="wasd", title="Gehfehler", description="Für die nächsten 10 Minuten läufst du komisch..." },
    { rarity= "Uncommon", tags={ "Negativ", "Clanker" }, timeInSeconds=300, popupChallenge=true, title="Virus", description="Das hättest du lieber nicht herunterladen sollen" },
    { rarity= "Uncommon", tags={ "Negativ", "Clanker" }, timeInSeconds=300, fartSounds=true, title="Stinky-Abilities", description="Für die nächsten 5 Minuten stinkt es, wenn du eine Fähigkeit benutzt" },
    { rarity= "Uncommon", tags={ "Positiv" }, timeInSeconds=120, title="Bob Ross", description="Male innerhalb 2 Minuten eine kleine World of Warcraft Impression in Paint und poste sie auf Discord" },
    { rarity= "Uncommon", tags={ "Negativ" }, title= "Shots, shots, shots!", description="Trinke einen Shot deiner Wahl"},
    { rarity= "Uncommon", tags={ "Negativ", "Sport" }, title= "I'm planking", description="Mache für 90 Sekunden eine Plank deiner Wahl (Front, Side, Reverse)"},
    { rarity= "Uncommon", tags={ "Negativ" }, title="Hell's Kitchen", description="Koche für jemanden eine leckere Mahlzeit" },
    { rarity= "Uncommon", tags={ "Negativ" }, timeInSeconds=600, title="Nice-Guy", description="Begrüße ALLE Spieler*innen den du in den nächsten 10 Minunten begegnest" },
    { rarity= "Uncommon", tags={ "Negativ" }, title="Fischverkäufer", description="Angle einen Fisch und verkauf ihn an einen anderen Spieler. Dein Ertrag kommt in die Gildenbank"},
    { rarity= "Uncommon", tags={ "Negativ" }, title= "Feet", description="Schicke Leon Matthes ein Bild deiner Füße"},
    { rarity= "Uncommon", tags={ "Negativ", "Sport" }, title= "Dann doch lieber 10 Hs", description="Mache 3 Burpees"},
    { rarity= "Uncommon", tags={ "Negativ", "Clanker", "Musik" }, guitarHero=true, guitarHeroDifficulty="medium", title="WoW-Hero: Medium", description="Spiele einen zufälligen Song der Schwierigkeitsstufe Medium in WoW-Hero. Verfehlst du den Zielscore, zahle Steuern gemäß \"/lidl steuer\" in Silber an die Gilde."},
    { rarity= "Rare", tags={ "Negativ"}, timeInSeconds=600, title= "Rettungssanitäter", description="Heile für die nächsten 15 Minuten ALLE verletzten Spieler in deiner Nähe. Zur Not müssen Verbände herhalten"},
    { rarity= "Rare", tags={ "Negativ" }, title="Bisschen Kleingeld?", description="Bettle bei einem Spieler für ein bisschen Kleingeld. Dein Ertrag kommt in die Gildenbank"},
    { rarity= "Rare", tags={ "Negativ" }, title="Prost!", description="Besorg dir in der Taverne etwas alkohilisches zum Trinken und sauf dich voll!" },
    { rarity= "Rare", tags={ "Positiv", "Clanker" }, timeInSeconds=300, devilMayCryCombo=true, title="Devil May Cry", description="Für 5 Minuten lassen Treffer an Monstern deinen Combo-Meter steigen. Halte die Kombo am Leben und knacke den Highscore!" },
    { rarity= "Rare", tags={ "Positiv", "Clanker" }, timeInSeconds=300, bayonettaCombo=true, title="Witchtime", description="Sammle in 5 Minuten Combo Points. Halte die Kombo am Leben und schlage den Highscore!" },
    { rarity= "Rare", tags={ "Positiv" }, title="For me? *blushes*", description="Deine Mitspieler haben dich lieb. Lass dir von jedem Mitspieler (der Online ist) ein Geschenk geben. (per Post geht auch)"},
    { rarity= "Rare", tags={ "Positiv" }, title= "Story Time", description="Erzähle den anderen eine Geschichte :)"},
    { rarity= "Rare", tags={ "Negativ" }, timeInSeconds=600,  title= "/Muted", description="Sprich die nächsten 10 Minuten nur noch über /say oder Flüster-Chat (kein Voice-Chat)"},
    { rarity= "Rare", tags={ "Negativ", "Clanker", "Musik" }, guitarHero=true, guitarHeroDifficulty="hard", title="WoW-Hero: Hard", description="Spiele einen zufälligen Song der Schwierigkeitsstufe Hard in WoW-Hero. Verfehlst du den Zielscore, zahle Steuern gemäß \"/lidl steuer\" in Silber an die Gilde."},
    { rarity= "Rare", tags={ "Negativ", "Clanker", "Musik" }, osu=true, osuDifficulty="medium", title="Osu!: Medium", description="Spiele einen zufälligen Song der Schwierigkeitsstufe Medium in Osu!. Verfehlst du den Zielscore, zahle Steuern gemäß \"/lidl steuer\" in Silber an die Gilde."},
    { rarity= "Rare", tags={ "Negativ", "Clanker" }, timeInSeconds=300, keybindingShuffle="actionbuttons", title="Switcharoo", description="Die Tastenbelegung deiner Aktionsleiste ist für 5 Minuten vertauscht" },
    { rarity= "Epic", tags={ "Negativ" }, timeInSeconds=120, title= "Mindfuck", description="Spiele für 2 Minuten mit umgedrehter Maus."},
    { rarity= "Epic", tags={ "Positiv" }, title= "Zeit für ein D-d-duell", description="Fordere einen Spieler zu einem Duell heraus. Gewinnst du, erhältst du vom Verlierer Steuern gemäß \"/lidl steuer\". Verlierst du, zahlst du Steuern in die Gildenbank."},
    { rarity= "Epic", tags={ "Negativ" }, timeInSeconds=900, title= "Console-Gamer", description="Spiel die nächsten 15 Minuten mit Controller"},
    { rarity= "Epic", tags={ "Negativ" }, timeInSeconds=300, title= "Phasmo", description="Phasmo an dei Eier (Spiele die nächsten 5 Minuten mit nur einer Hand)"},
    { rarity= "Epic", tags={ "Positiv" }, title= "Shotcaller", description="Du bestimmst mit deinem nächsten Call was gemacht wird. Dein Call ist Gesetz!"},
    { rarity= "Epic", tags={ "Positiv", "Sport" }, title= "Sally goes up", description="Wenn du einen Stehschreibtisch hast, fahre ihn bis zum nächsten Event hoch. Wenn nicht, stehe auf und versuche 60 Sekunden mit durchgestreckten Beinen deine Zehen zu erreichen."},
    { rarity= "Epic", tags={ "Negativ", "Clanker", "Musik" }, guitarHero=true, guitarHeroDifficulty="extreme", title="WoW-Hero: Extreme", description="Spiele einen zufälligen Song der Schwierigkeitsstufe Extreme in WoW-Hero. Verfehlst du den Zielscore, zahle Steuern gemäß \"/lidl steuer\" in Silber an die Gilde."},
    { rarity= "Epic", tags={ "Negativ", "Clanker", "Musik" }, osu=true, osuDifficulty="hard", title="Osu!: Hard", description="Spiele einen zufälligen Song der Schwierigkeitsstufe Hard in Osu!. Verfehlst du den Zielscore, zahle Steuern gemäß \"/lidl steuer\" in Silber an die Gilde."},
    { rarity= "Legendary", tags={ "Negativ" }, timeInSeconds=1200, title= "Die Socken bleiben an", description="Zieh deinem Charakter für die nächsten 20 Minuten alles außer die Schuhe aus"},
    { rarity= "Legendary", tags={ "Negativ"}, title="Time to say goodbye", description= "Verabschiede dich von einem deiner aktuell getragenen Ausrüstungsgegenständen (Hemd ausgeschlossen!) und verkauf es"},
    { rarity= "Legendary", tags={ "Positiv" }, title= "JACKPOT!", description="Du bist reich! Hol dir den Gilden-Jackpot ab!"},
    { rarity= "Legendary", tags={ "Negativ", "Clanker", "Musik" }, osu=true, osuSong="Pizza Tower - It's Pizza Time!", title="Osu!: Legendary", description="It's Pizza Time! Verfehlst du den Zielscore, zahle DOPPELTE Steuern gemäß \"/lidl steuer\" in Silber an die Gilde."},
}

local knownTags = {}
for _, tag in ipairs(addonTable.ChallengeTags) do
    knownTags[tag] = true
end

for _, challenge in ipairs(addonTable.Challenges) do
    for _, tag in ipairs(challenge.tags or {}) do
        if not knownTags[tag] then
            knownTags[tag] = true
            table.insert(addonTable.ChallengeTags, tag)
        end
    end
end
