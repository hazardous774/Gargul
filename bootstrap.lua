-- bootstrap.lua (modified)

-- ... original code above ...

GL.Ace = LibStub("AceAddon-3.0"):NewAddon(GL.name, "AceConsole-3.0", "AceComm-3.0", "AceTimer-3.0")

-- PLUS1 buff tracking tables
GargulPlus1 = GargulPlus1 or {}
GargulPlus1.buffStatus = GargulPlus1.buffStatus or {}
GargulPlus1.secondRollPrefs = GargulPlus1.secondRollPrefs or {}

C_ChatInfo.RegisterAddonMessagePrefix("PLUS1BUFFS")

local plus1Frame = CreateFrame("Frame")
plus1Frame:RegisterEvent("CHAT_MSG_ADDON")
plus1Frame:SetScript("OnEvent", function(_, _, prefix, text, _, sender)
    if prefix == "PLUS1BUFFS" then
        local player, status = strsplit(":", text)
        GargulPlus1.buffStatus[player] = (status == "1")
    end
end)

-- ... rest of bootstrap.lua code unchanged ...
