local L = Gargul_L;

---@type GL
local _, GL = ...;

---@class RollerUI
GL.RollerUI = GL.RollerUI or {
    Window = nil,
};
local RollerUI = GL.RollerUI; ---@type RollerUI

-- Ensure GargulPlus1 tables exist
GargulPlus1 = GargulPlus1 or {}
GargulPlus1.buffStatus = GargulPlus1.buffStatus or {}
GargulPlus1.secondRollPrefs = GargulPlus1.secondRollPrefs or {}

---@return boolean
function RollerUI:show(time, itemLink, itemIcon, note, SupportedRolls, bth)
    if (self.Window and self.Window:IsShown()) then
        return false;
    end

    GL:canUserUseItem(itemLink, function (userCanUseItem)
        if (not userCanUseItem and GL.Settings:get("Rolling.dontShowOnUnusableItems", false)) then
            return false;
        end

        self:draw(time, itemLink, itemIcon, note, SupportedRolls, userCanUseItem, bth);
    end);

    return true;
end

function RollerUI:draw(time, itemLink, itemIcon, note, SupportedRolls, userCanUseItem, bth)
    local Window = CreateFrame("Frame", "GargulUI_RollerUI_Window", UIParent, Frame);
    Window:SetSize(350, 68); -- a bit taller to fit checkbox
    Window:SetPoint(GL.Interface:getPosition("Roller"));

    Window:SetMovable(true);
    Window:EnableMouse(true);
    Window:SetClampedToScreen(true);
    Window:SetFrameStrata("FULLSCREEN_DIALOG");
    Window:RegisterForDrag("LeftButton");
    Window:SetScript("OnDragStart", Window.StartMoving);
    Window:SetScript("OnDragStop", function()
        Window:StopMovingOrSizing();
        GL.Interface:storePosition(Window, "Roller");
    end);
    Window:SetScript("OnMouseDown", function (_, button)
        if (button == "RightButton") then
            self:hide();
            return;
        end
        HandleModifiedItemClick(itemLink, button);
    end);
    Window:SetScale(GL.Settings:get("Rolling.scale", 1));
    Window.ownedByGargul = true;
    self.Window = Window;

    local Texture = Window:CreateTexture(nil,"BACKGROUND");
    Texture:SetColorTexture(0, 0, 0, .6);
    Texture:SetAllPoints(Window)
    Window.texture = Texture;

    -- PLUS1: show “+1 Eligible” label if buffed
    local myName = GL.User.fqn or UnitName("player")
    local buffed = GargulPlus1.buffStatus[myName]
    if buffed then
        local plus1Text = Window:CreateFontString(nil, "OVERLAY", "GameFontNormal")
        plus1Text:SetPoint("BOTTOMLEFT", Window, "TOPLEFT", 10, 0)
        plus1Text:SetText("|cFF00FF00+1 Eligible|r: You may opt in for an extra roll!")
    end

    local RollButtons = {};
    local numberOfButtons = #SupportedRolls;
    local rollerUIWidth = 0;

    for i = 1, numberOfButtons do
        local RollDetails = SupportedRolls[i] or {};

        local identifier = RollDetails[1];
        local min = math.floor(tonumber(RollDetails[2]) or 0);
        local max = math.floor(tonumber(RollDetails[3]) or 0);

        if (GL:empty(identifier)) then break; end

        local Button = CreateFrame("Button", nil, Window, "GameMenuButtonTemplate");
        local buttonWidth = math.max(string.len(identifier) * 12, 70);
        rollerUIWidth = rollerUIWidth + buttonWidth + 4;
        Button:SetSize(buttonWidth, 20);
        Button:SetText(identifier);
        Button:SetNormalFontObject("GameFontNormal");
        Button:SetHighlightFontObject("GameFontNormal");

        if (not userCanUseItem) then
            Button:Disable();
            Button:SetMotionScriptsWhileDisabled(true);
            Button:SetScript("OnEnter", function() Button:Enable(); end);
            Button:SetScript("OnLeave", function() Button:Disable(); end);
        end

        Button:SetScript("OnClick", function ()
            RandomRoll(min, max);

            -- Store +1 choice if buffed and checkbox is ticked
            if buffed and Window.plus1Checkbox and Window.plus1Checkbox:GetChecked() then
                GargulPlus1.secondRollPrefs[itemLink] = GargulPlus1.secondRollPrefs[itemLink] or {}
                GargulPlus1.secondRollPrefs[itemLink][myName] = true
            else
                if GargulPlus1.secondRollPrefs[itemLink] then
                    GargulPlus1.secondRollPrefs[itemLink][myName] = false
                end
            end

            if (GL.Settings:get("Rolling.closeAfterRoll")) then
                self:hide();
            else
                local RollAcceptedNotification = GL.AceGUI:Create("InlineGroup");
                RollAcceptedNotification:SetLayout("Fill");
                RollAcceptedNotification:SetWidth(150);
                RollAcceptedNotification:SetHeight(50);
                RollAcceptedNotification.frame:SetParent(Window);
                RollAcceptedNotification.frame:SetPoint("BOTTOMLEFT", Window, "TOPLEFT", 0, 4);

                local Text = GL.AceGUI:Create("Label");
                Text:SetText(L["Roll accepted!"]);
                RollAcceptedNotification:AddChild(Text);
                Text:SetJustifyH("CENTER");

                self.RollAcceptedTimer = GL.Ace:ScheduleTimer(function ()
                    RollAcceptedNotification.frame:Hide();
                end, 2);
            end
        end);

        if (i == 1) then
            Button:SetPoint("TOPLEFT", Window, "TOPLEFT", 2, -1);
        else
            Button:SetPoint("TOPLEFT", RollButtons[i - 1], "TOPRIGHT", 1, 0);
        end

        tinsert(RollButtons, Button);
    end

    -- Pass button
    local PassButton = CreateFrame("Button", "GargulUI_RollerUI_Pass", Window, "GameMenuButtonTemplate");
    PassButton:SetPoint("TOPRIGHT", Window, "TOPRIGHT", -3, -1);
    PassButton:SetSize(50, 20);
    PassButton:SetText(L["Pass"]);
    PassButton:SetNormalFontObject("GameFontNormal");
    PassButton:SetHighlightFontObject("GameFontNormal");
    PassButton:SetScript("OnClick", function ()
        self:hide();
    end);

    rollerUIWidth = math.max(rollerUIWidth + 54, 350);
    Window:SetWidth(rollerUIWidth);

    -- PLUS1: add opt-in checkbox if buffed
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

    ---@type Frame
    local IdentityWindow, position = GL.Interface.Identity:buildForRoller(bth);
    IdentityWindow:SetParent(Window);
    if (type(position) ~= "function") then
        IdentityWindow:SetPoint("TOPLEFT", Window, "TOPRIGHT", 0, 0);
    else
        position(IdentityWindow, Window);
    end

    self:drawCountdownBar(time, itemLink, itemIcon, note, userCanUseItem, rollerUIWidth);
end

function RollerUI:drawCountdownBar(time, itemLink, itemIcon, note, userCanUseItem, width)
    if (not self.Window) then return false; end

    local TimerBar = LibStub("LibCandyBarGargul-3.0"):New(
        "Interface/AddOns/Gargul/Assets/Textures/timer-bar",
        width,
        24
    );
    self.TimerBar = TimerBar;

    TimerBar:SetParent(self.Window);
    TimerBar:SetPoint("BOTTOM", self.Window, "BOTTOM");
    TimerBar.candyBarLabel:SetFont(STANDARD_TEXT_FONT, 12, "OUTLINE");

    TimerBar:AddUpdateFunction(function (Bar)
        if (not userCanUseItem) then
            TimerBar:SetColor(0, 0, 0, .1); return;
        end
        local percentageLeft = 100 / (time / Bar.remaining);
        if (percentageLeft >= 60) then
            Bar:SetColor(0, 1, 0, .3);
        elseif (percentageLeft >= 30) then
            Bar:SetColor(1, 1, 0, .3);
        else
            Bar:SetColor(1, 0, 0, .3);
        end
    end);

    TimerBar:SetScript("OnMouseDown", function(_, button)
        if (button == "RightButton") then self:hide(); end
    end)

    TimerBar:SetDuration(time);
    TimerBar:SetColor(userCanUseItem and 0 or 0, userCanUseItem and 1 or 0, userCanUseItem and 0 or 0, .3);
    note = note or "";
    TimerBar:SetLabel("  " .. itemLink);
    if (not userCanUseItem) then
        TimerBar:SetLabel(("  |c00FFFFFF%s|r"):format(L["You can't use this item!"]));
    end
    TimerBar:SetIcon(itemIcon);
    TimerBar:Set("type", "ROLLER_UI_COUNTDOWN");
    TimerBar:Start();

    local lastShiftStatus;
    local itemTooltipIsShowing = false;
    local refreshTooltip = function ()
        GameTooltip:Hide();
        if (not self.Window) then return; end
        GameTooltip:SetOwner(self.Window, "ANCHOR_TOP");
        GameTooltip:SetHyperlink(itemLink);
        GameTooltip:Show();
        itemTooltipIsShowing = true;
    end;

    TimerBar:SetScript("OnEnter", function()
        lastShiftStatus = IsShiftKeyDown();
        GameTooltip:SetOwner(self.Window, "ANCHOR_TOP");
        GameTooltip:SetHyperlink(itemLink);
        GameTooltip:Show();
        itemTooltipIsShowing = true;
    end);
    TimerBar:SetScript("OnLeave", function()
        GameTooltip:Hide();
        itemTooltipIsShowing = false;
    end);

    GL.Events:register("RollerUIModifierStateChanged", "MODIFIER_STATE_CHANGED", function (_, key, pressed)
        if (not itemTooltipIsShowing or (key ~= "LSHIFT" and key ~= "RSHIFT")) then return; end
        if (lastShiftStatus ~= pressed) then refreshTooltip(); lastShiftStatus = pressed; end
    end);
end

function RollerUI:hide()
    GL.Events:unregister("RollerUIModifierStateChanged");
    if (not self.Window) then return; end
    if (self.TimerBar and self.TimerBar.SetParent) then
        self.TimerBar:SetParent(UIParent);
        self.TimerBar:Stop();
        self.TimerBar = nil;
    end
    GL.Interface:release(self.Window);
    self.Window = nil;
end
