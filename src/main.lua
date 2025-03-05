-- copied this off the perception expander plugin - so this is AGPLv3

-- maybe can register buttons for call from gestures: https://github.com/koreader/koreader/blob/master/plugins/calibre.koplugin/main.lua#L64

-- adb push main.lua /sdcard/koreader/plugins/tracklines.koplugin/
-- adb logcat | grep KOReader | grep Track

local Widget = require("ui/widget/widget")
local LineWidget = require("ui/widget/linewidget")
local MultiInputDialog = require("ui/widget/multiinputdialog")
local WidgetContainer = require("ui/widget/container/widgetcontainer")
local HorizontalGroup = require("ui/widget/horizontalgroup")
local UIManager = require("ui/uimanager")
local InfoMessage = require("ui/widget/infomessage")
local Geom = require("ui/geometry")
local Screen = require("device").screen
local T = require("ffi/util").template
local _ = require("gettext")
local LuaSettings = require("luasettings")
local DataStorage = require("datastorage")
local Blitbuffer = require("ffi/blitbuffer")
local Dispatcher = require("dispatcher")
local logger=require("logger")
                           
local TrackLines = Widget:extend{
    is_enabled = nil,
    name = "tracklines",
    page_counter = 0,
    shift_each_pages = 100,
    margin = 0.1,
    line_thickness = 2,
    line_color_intensity = 0.3,
    margin_shift = 0.03,
    settings = nil,
    ALMOST_CENTER_OF_THE_SCREEN = 0.37,
    last_screen_mode = nil,
    increment = 20  -- Changed from 40 to make movement more precise
}

function TrackLines:onDispatcherRegisterActions()
    -- Renamed actions to more accurately describe horizontal line movement
    Dispatcher:registerAction("tracklines_move_up", { category="none", event="TrackLinesMoveUp", title=_("Move line up"), general=true,})
    Dispatcher:registerAction("tracklines_move_down", { category="none", event="TrackLinesMoveDown", title=_("Move line down"), general=true,})
end

function TrackLines:onTrackLinesMoveUp()
    -- Move the line up (decrease y position)
    self.top_line.dimen.y = self.top_line.dimen.y - self.increment
    logger.warn("TrackLines moving line up, now render...")
    
    UIManager:setDirty(self.view.dialog, "partial")

    logger.warn("TrackLines move line up, done rendering...")
    return true
end

function TrackLines:onTrackLinesMoveDown()
    -- Move the line down (increase y position)
    self.top_line.dimen.y = self.top_line.dimen.y + self.increment
    logger.warn("TrackLines moving line down, now render...")

    UIManager:setDirty(self.view.dialog, "partial")

    logger.warn("TrackLines move line down, done rendering...")
    return true
end

function TrackLines:init()
    logger.warn("TrackLines initializing")
    if not self.settings then self:readSettingsFile() end
    self.is_enabled = self.settings:isTrue("is_enabled")
    if not self.is_enabled then
         return
    end
    self:createUI(true)
end

function TrackLines:readSettingsFile()
    self.settings = LuaSettings:open(DataStorage:getSettingsDir() .. "/track_lines.lua")
end

function TrackLines:showSettingsDialog()
    self.settings_dialog = MultiInputDialog:new{
        title = _("Track lines settings"),
        fields ={
            {
                text = "",
                input_type = "number",
                hint = T(_("Line thickness. Current value: %1\nChanging requires restart."),
                    self.line_thickness),
            },
            {
                text = "",
                input_type = "number",
                hint = T(_("Margin from edges. Current value: %1"),
                    self.margin),
            },
            {
                text = "",
                input_type = "number",
                hint = T(_("Line color intensity (1-10). Current value: %1"),
                    self.line_color_intensity * 10),
            },
            {
                text = "",
                input_type = "number",
                hint = T(_("Increase margin after pages. Current value: %1\nSet to 0 to disable."),
                    self.shift_each_pages),
            },
        },
        buttons ={
            {
                {
                    text = _("Cancel"),
                    id = "close",
                    callback = function()
                        self.settings_dialog:onClose()
                        UIManager:close(self.settings_dialog)
                    end
                },
                {
                    text = _("Apply"),
                    callback = function()
                        -- Get the input fields
                        local fields = MultiInputDialog:getFields()
                        
                        -- Save current line thickness before changing
                        local old_thickness = self.line_thickness
                        
                        -- Save all settings
                        self:saveSettings(fields)
                        
                        -- Close dialog first
                        self.settings_dialog:onClose()
                        UIManager:close(self.settings_dialog)
                        
                        -- Check if thickness changed
                        if old_thickness ~= self.line_thickness then
                            -- Thickness changed - show restart required message
                            UIManager:show(InfoMessage:new{
                                text = _("Line thickness has been changed. This change will take effect after restarting KOReader."),
                                timeout = 3,
                            })
                            
                            -- Reset to old thickness for current session
                            self.line_thickness = old_thickness
                            
                            -- Only update other settings
                            self:resetWidget()
                            UIManager:setDirty(nil, "ui")
                        else
                            -- If only other settings changed, just recreate UI
                            self:resetWidget()
                            UIManager:setDirty(nil, "ui")
                        end
                    end
                },
            },
        },
    }
    UIManager:show(self.settings_dialog)
    self.settings_dialog:onShowKeyboard()
end

-- New method to completely reset the widget
function TrackLines:resetWidget()
    logger.warn("TrackLines completely resetting widget")
    
    -- Remove old widget
    self[1] = nil
    
    -- Create new widget from scratch
    self:createUI(false)
    
    logger.warn("TrackLines widget reset complete")
end

function TrackLines:createUI(readSettings)
    logger.warn("TrackLines creating UI")
    self:onDispatcherRegisterActions()
    if readSettings then
        self.line_thickness = tonumber(self.settings:readSetting("line_thick")) or self.line_thickness
        self.margin = tonumber(self.settings:readSetting("margin")) or self.margin
        self.line_color_intensity = tonumber(self.settings:readSetting("line_color_intensity")) or self.line_color_intensity
        self.shift_each_pages = tonumber(self.settings:readSetting("shift_each_pages")) or self.shift_each_pages
        self.page_counter = tonumber(self.settings:readSetting("page_counter")) or 0
    end

    -- Ensure line thickness is valid (at least 1 pixel)
    if not self.line_thickness or self.line_thickness < 1 then
        self.line_thickness = 1
        logger.warn("TrackLines invalid line thickness, setting to 1")
    elseif self.line_thickness > 20 then -- Set a reasonable maximum
        self.line_thickness = 20
        logger.warn("TrackLines line thickness too large, setting to 20")
    end

    -- Log current line thickness for debugging
    logger.warn("TrackLines using line thickness: " .. self.line_thickness)

    self.screen_width = Screen:getWidth()
    local screen_height = Screen:getHeight()
    
    -- Create horizontal line that spans the screen width
    local line_width = self.screen_width
    local line_position_y = math.floor(screen_height * 0.3) -- Position at 30% down the screen

    self.last_screen_mode = Screen:getScreenMode()
    if self.last_screen_mode == "landscape" then
        self.margin = (self.margin - self.margin_shift)
    end

    -- Create a new clean line widget
    local line_thickness = math.floor(self.line_thickness) -- Ensure integer value
    
    -- KOReader approach: create a clean BB first
    local line_bb = Blitbuffer.new(line_width, line_thickness, Blitbuffer.TYPE_BB8)
    -- Fill it with the appropriate color
    line_bb:fill(Blitbuffer.gray(self.line_color_intensity))
    
    -- Create a horizontal line widget with the prepared BB
    local line_widget = Widget:new{
        dimen = Geom:new{
            w = line_width,
            h = line_thickness,
        },
        -- Override the paintTo method to use our prepared BB
        paintTo = function(self, bb, x, y)
            bb:blitFrom(line_bb, x, y)
        end,
    }

    -- Create a container for the horizontal line
    self.top_line = WidgetContainer:new{
        dimen = Geom:new{
            x = 0,
            y = line_position_y,
            w = line_width,
            h = line_thickness,
        },
        line_widget
    }

    -- Create and assign the container
    self[1] = HorizontalGroup:new{
        self.top_line,
    }
    
    logger.warn("TrackLines UI creation completed with thickness: " .. line_thickness)
end

function TrackLines:onReaderReady()
    self.ui.menu:registerToMainMenu(self)
    self.view:registerViewModule("track_lines", self)
end

function TrackLines:resetLayout()
    self:resetWidget()
end

function TrackLines:addToMainMenu(menu_items)
    menu_items.speed_reading_module_track_lines = {
        text = _("Reading Guide Lines"),  -- Improved menu text
        sub_item_table ={
            {
                text = _("Enable"),
                checked_func = function() return self.is_enabled end,
                callback = function()
                    self.is_enabled = not self.is_enabled
                    self:saveSettings()
                    if self.is_enabled then self:createUI() end
                    return true
                end,
            },
            {
                text = _("Settings"),
                keep_menu_open = true,
                callback = function()
                    self:showSettingsDialog()
                end,
            },
            {
                text = _("Move Line Up"),  -- Added menu option to move line up
                keep_menu_open = true,
                callback = function()
                    if self.is_enabled and self.top_line then
                        self:onTrackLinesMoveUp()
                    end
                end,
            },
            {
                text = _("Move Line Down"),  -- Added menu option to move line down
                keep_menu_open = true,
                callback = function()
                    if self.is_enabled and self.top_line then
                        self:onTrackLinesMoveDown()
                    end
                end,
            },
            {
                text = _("About"),
                keep_menu_open = true,
                callback = function()
                    UIManager:show(InfoMessage:new{
                        text = _("Reading Guide Lines helps track your position while reading by displaying horizontal guide lines."),
                    })
                end,
            },
        },
    }
end

function TrackLines:onPageUpdate(pageno)
    logger.warn("TrackLines on page update")

    if not self.is_enabled then
        return
    end

    -- Reset line position to default when changing pages
    self.top_line.dimen.y = math.floor(Screen:getHeight() * 0.3)
    logger.warn("TrackLines reset line position")
    UIManager:setDirty(self.view.dialog, "partial")
    
    -- If this plugin did not apply screen orientation change, redraw plugin UI
    if Screen:getScreenMode() ~= self.last_screen_mode then
        self:createUI()
    end

    -- Update page counter logic
    if self.shift_each_pages ~= 0 and self.page_counter >= self.shift_each_pages and self.margin < self.ALMOST_CENTER_OF_THE_SCREEN then
        self.page_counter = 0
        self.margin = self.margin + self.margin_shift
    else
        self.page_counter = self.page_counter + 1;
    end
end

function TrackLines:saveSettings(fields)
    -- If fields are provided, use them to update values
    if fields then
        -- Validate line thickness before saving
        local new_thickness = fields[1] ~= "" and tonumber(fields[1]) or self.line_thickness
        if new_thickness and new_thickness >= 1 and new_thickness <= 20 then
            self.line_thickness = new_thickness
        else
            logger.warn("TrackLines invalid line thickness input:", new_thickness)
            -- Keep current value if invalid
        end
        
        self.margin = fields[2] ~= "" and tonumber(fields[2]) or self.margin

        local line_intensity = fields[3] ~= "" and tonumber(fields[3]) or self.line_color_intensity * 10
        if line_intensity then
            self.line_color_intensity = line_intensity / 10
        end
        self.shift_each_pages = fields[4] ~= "" and tonumber(fields[4]) or self.shift_each_pages
    end

    -- Always save all current settings
    self.settings:saveSetting("line_thick", self.line_thickness)
    self.settings:saveSetting("margin", self.margin)
    self.settings:saveSetting("line_color_intensity", self.line_color_intensity)
    self.settings:saveSetting("shift_each_pages", self.shift_each_pages)
    self.settings:saveSetting("page_counter", self.page_counter)
    self.settings:saveSetting("is_enabled", self.is_enabled)
    self.settings:flush()
    
    logger.warn("TrackLines settings saved, line thickness: " .. self.line_thickness)
end

function TrackLines:paintTo(bb, x, y)
    if self.is_enabled and self[1] then
        logger.warn("TrackLines painting to screen with thickness: " .. self.line_thickness)
        self[1]:paintTo(bb, x, y)
    end
end

return TrackLines
