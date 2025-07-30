local L = Gargul_L;

---@type GL
local _, GL = ...;

---@type TMB
local TMB = GL.TMB;

---@class RollOff
GL.RollOff = GL.RollOff or {
    inProgress = false,
    listeningForRolls = false,
    rollPattern = GL:createPattern(RANDOM_ROLL_RESULT),
    CountDownTimer = nil,
    CurrentRollOff = {
        initiator = nil,
        time = nil,
        itemID = nil,
        itemName = nil,
        itemLink = nil,
        itemIcon = nil,
        note = nil,
        Rolls = {},
    },
    InitiateCountDownTimer = nil;
    StopRollOffTimer = nil,
    rollListenerCancelTimerId = nil,
};
local RollOff = GL.RollOff; ---@type RollOff

local CommActions = GL.Data.Constants.Comm.Actions;
local Events = GL.Events; ---@type Events

-- PLUS1 tables
GargulPlus1 = GargulPlus1 or {}
GargulPlus1.buffStatus = GargulPlus1.buffStatus or {}
GargulPlus1.secondRollPrefs = GargulPlus1.secondRollPrefs or {}

--------------------------------------------------------------
-- Start / Announce / Stop methods (unchanged from your file)
--------------------------------------------------------------

function RollOff:announceStart(itemLink, time, note)
    time = tonumber(time);
    if (not GL:isValidItemLink(itemLink)) then
        GL:warning(L["Invalid data provided for roll start!"]);
        return false;
    end
    if (not GL:gte(time, 5)) then
        GL:warning(L["Timer needs to be 5 seconds or more"]);
        return false;
    end
    if (not GL:empty(self.CurrentRollOff.itemLink)
        and self.CurrentRollOff.itemLink ~= itemLink
    ) then
        self:reset();
        GL.MasterLooterUI:reset(true);
        self.CurrentRollOff = self.CurrentRollOff or {};
        self.CurrentRollOff.Rolls = {};
    end

    self:stopListeningForRolls();
    self:listenForRolls();

    local BoostedRolls;
    if (GL.BoostedRolls:enabled() and GL.BoostedRolls:available()) then
        BoostedRolls = {};
        BoostedRolls.identifier = string.sub(GL.Settings:get("BoostedRolls.identifier", "BR"), 1, 3);
        BoostedRolls.RangePerPlayer = {};
        for _, Player in pairs(GL.User:groupMembers()) do
            (function()
                local normalizedName = GL.BoostedRolls:normalizedName(Player.fqn);
                if (not GL.BoostedRolls:hasPoints(normalizedName)) then return; end
                local points = GL.BoostedRolls:getPoints(normalizedName);
                BoostedRolls.RangePerPlayer[normalizedName] = ("%d-%d"):format(GL.BoostedRolls:minBoostedRoll(points), GL.BoostedRolls:maxBoostedRoll(points));
            end)();
        end
    end

    GL.CommMessage.new{
        action = CommActions.startRollOff,
        content = {
            item = itemLink,
            time = time,
            note = note,
            bth = GL.User:bth(),
            SupportedRolls = GL.Settings:get("RollTracking.Brackets", {}) or {},
            BoostedRollData = BoostedRolls,
        },
        channel = "GROUP",
    }:send();

    GL.Settings:set("UI.RollOff.timer", time);
    return true;
end

-- (postStartMessage, announceStop, start functions are unchanged)
-- (stop function is unchanged)
-- (award function is unchanged)

--------------------------------------------------------------
-- Listen/Stop listening
--------------------------------------------------------------
function RollOff:listenForRolls()
    if (self.rollListenerCancelTimerId) then
        GL.Ace:CancelTimer(self.rollListenerCancelTimerId);
    end
    if (self.listeningForRolls) then return; end
    self.listeningForRolls = true;
    Events:register("RollOffChatMsgSystemListener", "CHAT_MSG_SYSTEM", function (_, message)
        self:processRoll(message);
    end);
end

function RollOff:stopListeningForRolls()
    if (self.rollListenerCancelTimerId) then
        GL.Ace:CancelTimer(self.rollListenerCancelTimerId);
    end
    self.listeningForRolls = false;
    Events:unregister("RollOffChatMsgSystemListener");
end

--------------------------------------------------------------
-- Modified: processRoll
--------------------------------------------------------------
function RollOff:processRoll(message)
    if (not RollOff.listeningForRolls) then return; end

    local Roll = false;
    for roller, roll, low, high in string.gmatch(message, GL.RollOff.rollPattern) do
        GL:debug(string.format("Roll detected: %s rolls %s (%s-%s)", roller, roll, low, high));
        roll = tonumber(roll) or 0
        low = tonumber(low) or 0
        high = tonumber(high) or 0

        local RollType = (function()
            for _, RollType in pairs(GL.Settings:get("RollTracking.Brackets", {})) do
                if (low == RollType[2] and high == RollType[3]) then
                    return RollType;
                end
            end
            return false;
        end)();

        if (not RollType
            and GL.BoostedRolls:enabled()
            and GL.BoostedRolls:available()
            and GL.BoostedRolls:isBoostedRoll(low, high)
        ) then
            local points = GL.BoostedRolls:getPoints(roller);
            local allowedMinimumRoll = GL.BoostedRolls:minBoostedRoll(points);
            local allowedMaximumRoll = GL.BoostedRolls:maxBoostedRoll(points);
            if (low == allowedMinimumRoll and high == allowedMaximumRoll) then
                RollType = {
                    [1] = GL.Settings:get("BoostedRolls.identifier", "BR"),
                    [4] = GL.Settings:get("BoostedRolls.priority", 1),
                };
            end
        end

        if (not RollType and not GL.Settings:get("RollTracking.trackAll")) then
            return;
        elseif (not RollType) then
            RollType = {};
            RollType[1] = ("%s-%s"):format(low, high);
            RollType[4] = 10;
        end

        local rollerName = GL:nameFormat(roller);
        for _, Player in pairs(GL.User:groupMembers()) do
            if (GL:iEquals(rollerName, Player.name)) then
                Roll = {
                    player = GL:nameIsUnique(Player.name) and GL:nameFormat(Player.fqn) or roller,
                    class = Player.class,
                    amount = roll,
                    time = GetServerTime(),
                    classification = RollType[1],
                    priority = RollType[4],
                };
                break;
            end
        end
    end

    if (not Roll) then return; end

    -- Insert the normal roll
    tinsert(self.CurrentRollOff.Rolls, Roll)

    -- PLUS1 EXTRA ROLL LOGIC:
    if self:startedByMe() then
        local itemLink = self.CurrentRollOff.itemLink
        if GargulPlus1.buffStatus[Roll.player]
            and GargulPlus1.secondRollPrefs[itemLink]
            and GargulPlus1.secondRollPrefs[itemLink][Roll.player]
        then
            -- Grant an extra roll
            local secondRoll = {
                player = Roll.player,
                class = Roll.class,
                amount = math.random(1,100),
                time = GetServerTime(),
                classification = Roll.classification,
                priority = Roll.priority,
                bonus = true,
            }
            tinsert(self.CurrentRollOff.Rolls, secondRoll)
            print("|cFF00FF00PLUS1: Extra roll added for " .. Roll.player .. "|r")
        end
    end

    GL.Events:fire("GL.ROLLOFF_ROLL_ACCEPTED");
    self:refreshRollsTable();
end

--------------------------------------------------------------
-- The rest (formatRollerName, formatRollNotes, refreshRollsTable, reset)
-- are unchanged from your original file
--------------------------------------------------------------

function RollOff:formatRollerName(playerName, numberOfTimesRolledByPlayer)
    if (numberOfTimesRolledByPlayer > 1) then
        playerName = ("%s [%s]"):format(playerName, numberOfTimesRolledByPlayer);
    end
    return playerName;
end

function RollOff:formatRollNotes(rollNotes)
    return table.concat(rollNotes, ", ");
end

function RollOff:refreshRollsTable()
    -- unchanged
    local RollTableData = {};
    local Rolls = self.CurrentRollOff.Rolls;
    local RollsTable = GL.Interface:get(GL.MasterLooterUI, "Table.Players");
    local NumberOfRollsPerPlayer = {};
    if (not RollsTable) then return; end
    local importedFromDFTOrRRobin = GL.TMB:wasImportedFromDFT() or GL.TMB:wasImportedFromRRobin();
    local sortByTMBWishlist = GL.Settings:get("RollTracking.sortByTMBWishlist");
    local sortByTMBPrio = GL.Settings:get("RollTracking.sortByTMBPrio");

    for _, Roll in pairs(Rolls) do
        local playerName = GL:disambiguateName(Roll.player);
        NumberOfRollsPerPlayer[playerName] = (NumberOfRollsPerPlayer[playerName] or 0) + 1
        local numberOfTimesRolledByPlayer = NumberOfRollsPerPlayer[playerName];
        local rollPriority = (Roll.priority or 1) + 10000;
        local rollNotes = {};

        local normalizedPlayerName = string.lower(GL:disambiguateName(playerName));
        if (GL.SoftRes:itemIDIsReservedByPlayer(self.CurrentRollOff.itemID, normalizedPlayerName)) then
            if (GL.Settings:get("RollTracking.sortBySoftRes")) then
                rollPriority = 1;
            end
            local numberOfReserves = GL.SoftRes:playerReservesOnItem(self.CurrentRollOff.itemID, normalizedPlayerName) or 0;
            if (numberOfReserves > 0) then
                if (numberOfReserves > 1) then
                    tinsert(rollNotes, ("|c00F48CBA" .. L["SR [%sx]"] .. "|r"):format(numberOfReserves));
                else
                    tinsert(rollNotes, ("|c00F48CBA%s|r"):format(L["SR"] ));
                end
            end
        end

        local TMBData = TMB:byItemIDAndPlayer(self.CurrentRollOff.itemID, GL:nameFormat{ name = playerName, forceRealm = true, func = strlower, });
        if (TMBData) then
            local TopEntry = false;
            for _, Entry in pairs(TMBData) do
                (function ()
                    if (not TopEntry) then TopEntry = Entry; return; end
                    if (TopEntry.type == GL.Data.Constants.tmbTypePrio and Entry.type == GL.Data.Constants.tmbTypeWish) then return; end
                    if (TopEntry.type == GL.Data.Constants.tmbTypeWish and Entry.type == GL.Data.Constants.tmbTypePrio) then TopEntry = Entry; return; end
                    if ((importedFromDFTOrRRobin and Entry.prio > TopEntry.prio)
                        or (not importedFromDFTOrRRobin and Entry.prio < TopEntry.prio)
                    ) then
                        TopEntry = Entry; return;
                    end
                end)();
            end
            if (TopEntry) then
                if (TopEntry.type == GL.Data.Constants.tmbTypePrio) then
                    if (sortByTMBPrio) then
                        rollPriority = 2;
                        if (importedFromDFTOrRRobin) then rollPriority = rollPriority - TopEntry.prio;
                        else rollPriority = rollPriority + TopEntry.prio; end
                    end
                    tinsert(rollNotes, string.format("|c00FF7C0A" .. L["Prio [%s]"] .. "|r", TopEntry.prio));
                else
                    if (sortByTMBWishlist) then
                        rollPriority = 3;
                        rollPriority = rollPriority + TopEntry.prio;
                    end
                    tinsert(rollNotes, string.format("|c00FFFFFF" .. L["Wish [%s]"] .. "|r", TopEntry.prio));
                end
            end
        end

        local class = Roll.class;
        local plusOnes = GL.PlusOnes:getPlusOnes(playerName);
        local Row = {
            cols = {
                { value = self:formatRollerName(playerName, numberOfTimesRolledByPlayer), color = GL:classRGBAColor(class) },
                { value = Roll.amount, color = GL:classRGBAColor(class) },
                { value = GL:higherThanZero(plusOnes) and L["+"] .. plusOnes or "", color = GL:classRGBAColor(class) },
                { value = Roll.classification, color = GL:classRGBAColor(class) },
                { value = self:formatRollNotes(rollNotes), color = GL:classRGBAColor(class) },
                { value = rollPriority },
                { value = plusOnes or 0 },
            },
        };
        tinsert(RollTableData, Row);
    end
    RollsTable:SetData(RollTableData);
    RollsTable:SortData();
end

function RollOff:reset()
    self.CurrentRollOff.itemLink = "";
end
