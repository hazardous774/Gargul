-- classes/RollOff.lua (modified)

-- ... original code above ...

function RollOff:processRoll(message)
    -- existing parsing code...
    if (not Roll) then
        return;
    end

    -- Insert the normal roll
    tinsert(self.CurrentRollOff.Rolls, Roll)

    -- PLUS1 EXTRA ROLL LOGIC:
    if self:startedByMe() then
        local itemLink = self.CurrentRollOff.itemLink
        if GargulPlus1.buffStatus[Roll.player]
            and GargulPlus1.secondRollPrefs[itemLink]
            and GargulPlus1.secondRollPrefs[itemLink][Roll.player]
        then
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

    GL.Events:fire("GL.ROLLOFF_ROLL_ACCEPTED")
    self:refreshRollsTable()
end
