--[[
TrackLines - KOReader Plugin
A simple plugin that displays horizontal reading guide lines.

This plugin is licensed under the AGPL v3.
]]--

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
local logger = require("logger")

-- TrackLines widget implementation
-- This widget displays horizontal guide lines that help track reading position
local TrackLines = Widget:extend{
    name = "tracklines",
    -- Default values
    is_enabled = false,  -- Default to disabled
    line_thickness = 2,  -- Default line thickness in pixels
    line_color_intensity = 0.3,  -- Default line color (30% gray)
    shift_each_pages = 100,  -- Shift line margin after this many pages
    margin = 0.1,  -- Default margin from page edge (as percentage)
    margin_shift = 0.03,  -- How much to increase margin after shift_each_pages
    increment = 40,  -- Pixels to move when using up/down commands
    page_counter = 0,  -- Current page count for margin shift calculation
    ALMOST_CENTER_OF_THE_SCREEN = 0.37,  -- Maximum margin before stopping auto-shift
    last_screen_mode = nil,  -- Track screen orientation changes
    settings = nil,  -- Settings object reference
    line_width = nil,  -- Will be set to screen width
    line_top_position = nil,  -- Will be calculated based on screen height
    line_widget = nil,  -- Will hold the line widget reference
}

-- Register actions for dispatching movement controls
function TrackLines:onDispatcherRegisterActions()
    Dispatcher:registerAction("tracklines_move_up", {
        category="none", event="TrackLinesMoveUp", title=_("Move up"), general=true,
    })
    Dispatcher:registerAction("tracklines_move_down", {
        category="none", event="TrackLinesMoveDown", title=_("Move down"), general=true,
    })
end

-- Initialize the plugin
function TrackLines:init()
    logger.warn("TrackLines: initializing")
    self:readSettingsFile()
    
    self:onDispatcherRegisterActions()
    
    -- Check if the plugin is enabled in settings
    self.is_enabled = self.settings:isTrue("is_enabled")
    if not self.is_enabled then
        logger.warn("TrackLines: disabled by settings")
        return
    end
    
    -- Create the UI components if enabled
    self:createUI(true)
    
    logger.warn("TrackLines: initialization complete")
end

-- Read settings from the configuration file
function TrackLines:readSettingsFile()
    self.settings = LuaSettings:open(DataStorage:getSettingsDir() .. "/track_lines.lua")
    -- Add error handling for missing settings file
    if not self.settings then
        logger.warn("TrackLines: Could not open settings file, using defaults")
        self.settings = LuaSettings:open(DataStorage:getSettingsDir() .. "/track_lines.lua", true)
    end
end

-- Create or recreate the UI components
-- readSettings: whether to read values from settings file
function TrackLines:createUI(readSettings)
    if readSettings then
        -- Load settings with fallbacks to defaults if not found
        self.line_thickness = tonumber(self.settings:readSetting("line_thick")) or self.line_thickness
        self.margin = tonumber(self.settings:readSetting("margin")) or self.margin
        self.line_color_intensity = tonumber(self.settings:readSetting("line_color_intensity")) or self.line_color_intensity
        self.shift_each_pages = tonumber(self.settings:readSetting("shift_each_pages")) or self.shift_each_pages
        self.page_counter = tonumber(self.settings:readSetting("page_counter")) or self.page_counter
    end

    -- Validate settings to ensure they're within acceptable ranges
    if self.line_thickness < 1 then self.line_thickness = 1 end
    if self.line_color_intensity < 0.1 then self.line_color_intensity = 0.1 end
    if self.line_color_intensity > 1.0 then self.line_color_intensity = 1.0 end
    
    -- Get current screen dimensions
    local screen_width = Screen:getWidth()
    local screen_height = Screen:getHeight()
    
    -- Calculate line dimensions
    self.line_width = screen_width -- 100% of screen width
    self.line_top_position = math.floor(screen_height * 0.05)

    -- Store current screen mode to detect orientation changes
    self.last_screen_mode = Screen:getScreenMode()
    
    -- Create a line widget with appropriate dimensions and color
    local line_widget = LineWidget:new{
        background = Blitbuffer.gray(self.line_color_intensity),
        dimen = Geom:new{
            w = self.line_width,
            h = self.line_thickness,
        },
    }

    -- Position the line widget within a container for proper placement
    self.line_widget = WidgetContainer:new{
        dimen = Geom:new{
            x = 0, -- Start at left edge
            y = self.line_top_position,
            w = self.line_width,
            h = self.line_thickness,
        },
        line_widget
    }

    -- Replace any previous widget in the render tree
    self[1] = self.line_widget
end

-- Handle "move up" action to move the line upward
function TrackLines:onTrackLinesMoveUp()
    if not self.line_widget then 
        return true
    end
    
    -- Move the line up by the configured increment
    self.line_top_position = self.line_top_position - self.increment
    self.line_widget.dimen.y = self.line_top_position
    
    -- Request UI refresh
    if self.view and self.view.dialog then
        UIManager:setDirty(self.view.dialog, "ui")
    end
    
    return true
end

-- Handle "move down" action to move the line downward
function TrackLines:onTrackLinesMoveDown()
    if not self.line_widget then 
        return true
    end
    
    -- Move the line down by the configured increment
    self.line_top_position = self.line_top_position + self.increment
    self.line_widget.dimen.y = self.line_top_position
    
    -- Request UI refresh
    if self.view and self.view.dialog then
        UIManager:setDirty(self.view.dialog, "ui")
    end
    
    return true
end

-- Called when the reader is ready - register menus and view modules
function TrackLines:onReaderReady()
    -- Register this plugin in the reader's main menu
    self.ui.menu:registerToMainMenu(self)
    -- Register as a view module to receive page update events
    self.view:registerViewModule("track_lines", self)
end

-- Handle screen rotation or dimension changes
function TrackLines:resetLayout()
    self:createUI(false)
end

-- Show the settings dialog for configuring the plugin
function TrackLines:showSettingsDialog()
    self.settings_dialog = MultiInputDialog:new{
        title = _("Track lines settings"),
        fields = {
            {
                text = "",
                input_type = "number",
                hint = T(_("Line thickness. Current value: %1"),
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
        buttons = {
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
                        self:saveSettings(self.settings_dialog:getFields())
                        self.settings_dialog:onClose()
                        UIManager:close(self.settings_dialog)
                    end
                },
            },
        },
    }
    UIManager:show(self.settings_dialog)
    self.settings_dialog:onShowKeyboard()
end

-- Add the plugin to the reader's main menu
function TrackLines:addToMainMenu(menu_items)
    menu_items.speed_reading_module_track_lines = {
        text = _("horizontal lines"),
        sub_item_table = {
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
                text = _("About"),
                keep_menu_open = true,
                callback = function()
                    UIManager:show(InfoMessage:new{
                        text = _("A simple plugin to show horizontal reading guide lines."),
                    })
                end,
            },
        },
    }
end

-- Called when the page is updated (turned/scrolled)
function TrackLines:onPageUpdate(pageno)
    if not self.is_enabled then
        return
    end

    -- Reset line position on page update
    local screen_height = Screen:getHeight()
    self.line_top_position = math.floor(screen_height * 0.05)
    if self.line_widget then
        self.line_widget.dimen.y = self.line_top_position
    end
    
    -- If screen mode changed (rotation), recreate UI
    if Screen:getScreenMode() ~= self.last_screen_mode then
        self:createUI(false)
    end

    -- Handle automatic margin increase after configured number of pages
    -- This helps to gradually move the line down as reading progresses
    if self.shift_each_pages ~= 0 and self.page_counter >= self.shift_each_pages and self.margin < self.ALMOST_CENTER_OF_THE_SCREEN then
        self.page_counter = 0
        self.margin = self.margin + self.margin_shift
        -- Recreate UI with new settings
        self:createUI(false)
    else
        self.page_counter = self.page_counter + 1
    end
end

-- Save settings to the configuration file
-- fields: Values from the settings dialog, if provided
function TrackLines:saveSettings(fields)
    if fields then
        -- Update settings from dialog fields if provided
        self.line_thickness = fields[1] ~= "" and tonumber(fields[1]) or self.line_thickness
        self.margin = fields[2] ~= "" and tonumber(fields[2]) or self.margin

        local line_intensity = fields[3] ~= "" and tonumber(fields[3]) or self.line_color_intensity * 10
        if line_intensity then
            self.line_color_intensity = line_intensity * (1/10)
        end
        self.shift_each_pages = fields[4] ~= "" and tonumber(fields[4]) or self.shift_each_pages
    end

    -- Write settings to file
    self.settings:saveSetting("line_thick", self.line_thickness)
    self.settings:saveSetting("margin", self.margin)
    self.settings:saveSetting("line_color_intensity", self.line_color_intensity)
    self.settings:saveSetting("shift_each_pages", self.shift_each_pages)
    self.settings:saveSetting("page_counter", self.page_counter)
    self.settings:saveSetting("is_enabled", self.is_enabled)
    self.settings:flush()
    
    -- Recreate the UI with new settings
    if self.is_enabled then
        self:createUI(false)
    end
end

-- Draw the widget to the screen
-- This is called by the UI framework during rendering
function TrackLines:paintTo(bb, x, y)
    if self.is_enabled and self[1] then
        self[1]:paintTo(bb, x, y)
    end
end

return TrackLines

