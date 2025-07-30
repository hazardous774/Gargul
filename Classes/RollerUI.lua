-- classes/RollerUI.lua (modified)

-- ... original code above ...

function RollerUI:draw(time, itemLink, itemIcon, note, SupportedRolls, userCanUseItem, bth)
    local Window = CreateFrame("Frame", "GargulUI_RollerUI_Window", UIParent, Frame)
    -- existing UI code ...

    -- PLUS1 integration: indicate eligibility and add a checkbox
    GargulPlus1 = GargulPlus1 or {}
    GargulPlus1.buffStatus = GargulPlus1.buffStatus or {}
    GargulPlus1.secondRollPrefs = GargulPlus1.secondRollPrefs or {}

    local myName = GL.User.fqn or UnitName("player")
    local buffed = GargulPlus1.buffStatus[myName]
    if buffed then
        local plus1Text = Window:CreateFontString(nil, "OVERLAY", "GameFontNormal")
        plus1Text:SetPoint("BOTTOMLEFT", Window, "TOPLEFT", 10, 0)
        plus1Text:SetText("|cFF00FF00+1 Eligible|r: You may opt in for an extra roll!")
    end

    -- ... rest of buttons ...

    -- Add opt-in checkbox if buffed
    if buffed then
        local plus1Checkbox = CreateFrame("CheckButton", nil, Window, "UICheckButtonTemplate")
        plus1Checkbox:SetSize(20, 20)
        plus1Checkbox:SetPoint("BOTTOMRIGHT", Window, "BOTTOMRIGHT", -10, 25)
        plus1Checkbox:SetScript("OnClick", function(self)
            GargulPlus1.secondRollPrefs[itemLink] = GargulPlus1.secondRollPrefs[itemLink] or {}
            GargulPlus1.secondRollPrefs[itemLink][myName] = self:GetChecked()
        end)

        local cbText = Window:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
        cbText:SetPoint("LEFT", plus1Checkbox, "RIGHT", 2, 0)
        cbText:SetText("Use +1 extra roll for this item")
        Window.plus1Checkbox = plus1Checkbox
    end
end
