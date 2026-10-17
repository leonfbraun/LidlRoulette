local addonName, addonTable = ...

addonTable.RarityWeights = {
    { rarity="Legendary", weight=5 },
    { rarity="Epic", weight=10 },
    { rarity="Rare", weight=15 },
    { rarity="Uncommon", weight=25 },
    { rarity="Common", weight=45 },
    { rarity="poor", weight=0 },
}

addonTable.ChallengeTags = { "Positiv", "Negativ", "Sport" }

addonTable.Challenges = {
    { rarity= "Common", tags={ "Negativ", "Sport" }, title= "Liegestütze", description="Mache sofort 10 Liegestütze!"},
    { rarity= "Common", tags={ "Negativ" }, title= "Floor is lava", description="Du darfst für 5 Minuten mit keinem Körperteil den Boden berühren. Kleidung schützt nicht vor Verbrennungen."},
    { rarity= "Common", tags={ "Positiv", "Sport" }, title= "You are so tight!", description="Dehne deinen Nacken (3x Kopf nach vorne, 3x Kopf nach links, 3x Kopf nach rechts, 3x Kopf aufrecht und nach links drehen, 3x Kopf aufrecht und nach rechts drehen)"},
    { rarity= "Common", tags={ "Negativ", "Sport" }, title= "10 Hs bitte", description="Mache 10 Push ups"},
    { rarity= "Uncommon", tags={ "Negativ" }, title= "1x Shot", description="Trinke einen Shot deiner Wahl"},
    { rarity= "Uncommon", tags={ "Negativ" }, title= "Feet", description="Schicke Leon Matthes ein Bild deiner Füße"},
    { rarity= "Uncommon", tags={ "Negativ", "Sport" }, title= "Get low", description="Mache 10 Bodyweight Squats, Full ROM"},
    { rarity= "Uncommon", tags={ "Negativ", "Sport" }, title= "I'm planking", description="Mache für 45 Sekunden eine Plank deiner Wahl (Front, Side, Reverse)"},
    { rarity= "Rare", tags={ "Negativ", "Sport" }, title= "Dann doch lieber 10 Hs", description="Mache 3 Burpees"},
    { rarity= "Rare", tags={ "Positiv" }, title= "Wahrheit!", description="Wähle einen Spieler, der dir eine Frage stellen soll"},
    { rarity= "Epic", tags={ "Negativ" }, title= "Mindfuck", description="Spiele für 60 Sekunden mit umgedrehter Maus."},
    { rarity= "Epic", tags={ "Negativ" }, title= "Phasmo", description="Phasmo an dei Eier (Spiele die nächsten 5 Minuten mit nur einer Hand)"},
    { rarity= "Epic", tags={ "Positiv", "Sport" }, title= "Sally goes up", description="Wenn du einen Stehschreibtisch hast, fahre ihn bis zum nächsten Event hoch. Wenn nicht, stehe auf und versuche 60 Sekunden mit durchgestreckten Beinen deine Zehen zu erreichen."},
    { rarity= "Legendary", tags={ "Positiv" }, title= "Mom!", description="Ruf deine Mutter/deinen Vater an, falls das letzte Mal mehr als 1 Woche her ist."},
    { rarity= "Legendary", tags={ "Negativ" }, title= "Ausziehen", description="Zieh deinem Charakter für die nächsten 30 Minuten die Hose aus"},
    { rarity= "Legendary", tags={ "Positiv" }, title= "JACKPOT!", description="Du bist reich! Hol dir den Gilden-Jackpot ab!"}
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
