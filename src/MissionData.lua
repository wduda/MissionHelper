import "Turbine";

--[[ MissionData - Mission Information Database ]]--
--[[ Contains comprehensive mission data including objectives, tactics, and difficulty ]]--

MissionData = {};

-- Mission database: localized mission name as key
-- Structure: { name, region, objectives, tacticalAdvice, duration, difficulty, delvingEnabled, clickableObjectives, sourceReference, source }
MissionData.Missions = {
    ["The Beast of Belfalas"] = {
        name = "The Beast of Belfalas",
        region = "The Bloody Eagle Tavern (Malthak)",
        objectives = "Kill boss",
        tacticalAdvice = "Ignore mobs and go straight to boss. Find nearby scout and leave immediately once boss is dead.",
        duration = "Very Short (1.5 mins)",
        difficulty = "Easy (Solo T6)",
        delvingEnabled = true,
        clickableObjectives = "",
        sourceReference = "1, 2",
        source = "LOTRO Mission Durations & Delvings - Corsairs of Umbar"
    },
    ["A Dark Treasure"] = {
        name = "A Dark Treasure",
        region = "The Bloody Eagle Tavern (Deshra)",
        objectives = "Kill 12 corsairs, collect treasure, kill boss",
        tacticalAdvice = "Group mobs and AOE down. Ignore mobs on lowest beach. Head south. Boss counts as one of the 12.",
        duration = "Very Short (2 mins)",
        difficulty = "Easy (Solo T6)",
        delvingEnabled = true,
        clickableObjectives = "treasure",
        sourceReference = "1, 2",
        source = "LOTRO Mission Durations & Delvings - Corsairs of Umbar"
    },
    ["Securing Salvage"] = {
        name = "Securing Salvage",
        region = "The Bloody Eagle Tavern (Malthak)",
        objectives = "Kill corsairs, collect boxes.",
        tacticalAdvice = "Run to the end, AOE mobs, collect boxes on way back to starting point, kill boss.",
        duration = "Very Short (2 mins)",
        difficulty = "",
        delvingEnabled = true,
        clickableObjectives = "boxes",
        sourceReference = "1, 2",
        source = "LOTRO Mission Durations & Delvings - Corsairs of Umbar"
    },
    ["Ship of Wraiths"] = {
        name = "Ship of Wraiths",
        region = "The Bloody Eagle Tavern (Deshra)",
        objectives = "Kill 16 undead corsairs, free 4 captives, kill boss",
        tacticalAdvice = "Group mobs and AOE down. Boss is near ship where you free woman. Head south-west.",
        duration = "Very Short (2.5 mins)",
        difficulty = "Easy-Medium (Solo T6)",
        delvingEnabled = true,
        clickableObjectives = "4 captives",
        sourceReference = "1, 2",
        source = "LOTRO Mission Durations & Delvings - Corsairs of Umbar"
    },
    ["A Cut Above"] = {
        name = "A Cut Above",
        region = "The Bloody Eagle Tavern (Malthak)",
        objectives = "Kill 8 deck-hands, 10 look-outs, 3 brutes, then boss",
        tacticalAdvice = "Group mobs and AOE down.",
        duration = "Very Short (2.5 mins)",
        difficulty = "Easy-Medium (Solo T6)",
        delvingEnabled = true,
        clickableObjectives = "",
        sourceReference = "1",
        source = "LOTRO Mission Durations & Delvings - Corsairs of Umbar"
    },
    ["A Taste for Crab"] = {
        name = "A Taste for Crab",
        region = "The Bloody Eagle Tavern (Malthak)",
        objectives = "Kill crabs, click nets, kill boss",
        tacticalAdvice = "Group mobs and AOE down.",
        duration = "Short (4 mins)",
        difficulty = "Easy (Solo T6)",
        delvingEnabled = true,
        clickableObjectives = "nets",
        sourceReference = "1",
        source = "LOTRO Mission Durations & Delvings - Corsairs of Umbar"
    },
    ["A Life's Work"] = {
        name = "A Life's Work",
        region = "The Bloody Eagle Tavern (Malthak)",
        objectives = "Collect 10 research papers, destroy 8 gredbyg nests, kill boss",
        tacticalAdvice = "Ignore initial rockworms. Group gredbyg and click things. You can outrun many gredbyg to get clickables faster.",
        duration = "Short (4.5 mins)",
        difficulty = "Easy (Solo T6)",
        delvingEnabled = true,
        clickableObjectives = "10 research papers, 8 nests",
        sourceReference = "1",
        source = "LOTRO Mission Durations & Delvings - Corsairs of Umbar"
    },
    ["A Natural Disaster"] = {
        name = "A Natural Disaster",
        region = "The Bloody Eagle Tavern (Deshra)",
        objectives = "Kill 8 huorns and 6 wildwoods, then boss",
        tacticalAdvice = "Group mobs and AOE down. It can be easy to miss a mob at start and have to backtrack.",
        duration = "Short-Medium (5.5 mins)",
        difficulty = "Easy-Medium (Solo T6)",
        delvingEnabled = true,
        clickableObjectives = "",
        sourceReference = "1, 2",
        source = "LOTRO Mission Durations & Delvings - Corsairs of Umbar"
    },
    ["Caranost Courtyard"] = {
        name = "Caranost Courtyard",
        region = "Gerwyn Convoy (Andrath)",
        objectives = "Kill all orcs in courtyard.",
        tacticalAdvice = "3 pulls of 3 mobs, plus pathers. Difficulty depends on pull.",
        duration = "Quick",
        difficulty = "Easy-Medium (Duo T12)",
        delvingEnabled = true,
        clickableObjectives = "",
        sourceReference = "1, 2",
        source = "LOTRO Mission Durations & Delvings - Before the Shadow"
    },
    ["Jorthkyn and Hounds"] = {
        name = "Jorthkyn and Hounds",
        region = "Herne",
        objectives = "Kill 8 Jorthkyn and their hounds.",
        tacticalAdvice = "Scout spawns on top after final Jorthkyn. Can avoid some hounds if you focus Jorthkyn.",
        duration = "Quick",
        difficulty = "Medium-Hard (Solo T12)",
        delvingEnabled = true,
        clickableObjectives = "",
        sourceReference = "1, 2",
        source = "LOTRO Mission Durations & Delvings - Before the Shadow"
    },
    ["Patrol the Township"] = {
        name = "Patrol the Township",
        region = "Clégur",
        objectives = "Approach cats with rings to patrol locations, kill all mobs.",
        tacticalAdvice = "Must kill all for scout to spawn. Can get swarmed with mobs.",
        duration = "Long",
        difficulty = "Hard (Solo T12)",
        delvingEnabled = true,
        clickableObjectives = "cats",
        sourceReference = "1, 2",
        source = "LOTRO Mission Durations & Delvings - Before the Shadow"
    },
    ["A Rare Vintage"] = {
        name = "A Rare Vintage",
        region = "Prancing Pony (Anniversary)",
        objectives = "Collect 12 wine-flasks, pick 6 grape clusters, defeat Pampraush",
        tacticalAdvice = "Can walk past sleeping goblins. Use 'select nearest item' for high grape-vines. Run back/up path if boss doesn't spawn.",
        duration = "",
        difficulty = "",
        delvingEnabled = true,
        clickableObjectives = "12 wine-flasks, 6 grape clusters",
        sourceReference = "3",
        source = "LOTRO Anniversary Missions What, Where, How, Why?"
    },
    ["Rescue by Moonlight"] = {
        name = "Rescue by Moonlight",
        region = "Prancing Pony (Anniversary)",
        objectives = "Defeat 12 Dourhands, collect 6 treasure-boxes, locate Irestone, keep Avorthal alive.",
        tacticalAdvice = "Looting treasure-boxes may spawn adds. 'Locate Irestone' is a false-flag; speak to Avorthal on the ship.",
        duration = "",
        difficulty = "",
        delvingEnabled = true,
        clickableObjectives = "6 treasure-boxes",
        sourceReference = "3",
        source = "LOTRO Anniversary Missions What, Where, How, Why?"
    },
    ["Lalia's Safe Passage"] = {
        name = "Lalia's Safe Passage",
        region = "Prancing Pony (Anniversary)",
        objectives = "Escort Lalia to safety; Lalia must stay alive.",
        tacticalAdvice = "Be swift in grabbing aggro; she takes damage quickly. She pauses during combat.",
        duration = "",
        difficulty = "",
        delvingEnabled = true,
        clickableObjectives = "",
        sourceReference = "3",
        source = "LOTRO Anniversary Missions What, Where, How, Why?"
    },
    ["Blight in the Bite"] = {
        name = "Blight in the Bite",
        region = "",
        objectives = "",
        tacticalAdvice = "This is good",
        duration = "",
        difficulty = "",
        delvingEnabled = false,
        clickableObjectives = "",
        sourceReference = "",
        source = "",
        -- Legacy field for backwards compatibility
        helpText = "This is good"
    }
};

-- Get mission information by name
-- @param missionName: string - The localized mission name
-- @return: table or nil - Mission info table or nil if not found
function MissionData:GetMissionInfo(missionName)
    return self.Missions[missionName];
end

-- Check if mission exists in database
-- @param missionName: string - The localized mission name
-- @return: boolean - True if mission is in database
function MissionData:HasMission(missionName)
    return self.Missions[missionName] ~= nil;
end

-- Get total count of missions in database
-- @return: number - Total number of missions
function MissionData:GetMissionCount()
    local count = 0;
    for _ in pairs(self.Missions) do
        count = count + 1;
    end
    return count;
end

-- Get list of all unique regions
-- @return: table - Array of unique region names
function MissionData:GetAllRegions()
    local regions = {};
    local seen = {};

    for _, mission in pairs(self.Missions) do
        if mission.region and mission.region ~= "" and not seen[mission.region] then
            table.insert(regions, mission.region);
            seen[mission.region] = true;
        end
    end

    return regions;
end

-- Get missions filtered by region
-- @param region: string - Region name to filter by
-- @return: table - Array of mission tables matching the region
function MissionData:GetMissionsByRegion(region)
    local missions = {};

    for _, mission in pairs(self.Missions) do
        if mission.region == region then
            table.insert(missions, mission);
        end
    end

    return missions;
end

-- Get missions filtered by difficulty
-- @param difficulty: string - Difficulty rating to filter by
-- @return: table - Array of mission tables matching the difficulty
function MissionData:GetMissionsByDifficulty(difficulty)
    local missions = {};

    for _, mission in pairs(self.Missions) do
        if mission.difficulty == difficulty then
            table.insert(missions, mission);
        end
    end

    return missions;
end
