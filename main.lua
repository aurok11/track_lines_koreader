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
    increment = 10
}

function TrackLines:onDispatcherRegisterActions()
    Dispatcher:registerAction("tracklines_move_up", { category="none", event="TrackLinesMoveUp", title=_("Move up"), general=true,})
    Dispatcher:registerAction("tracklines_move_down", { category="none", event="TrackLinesMoveDown", title=_("Move down"), general=true,})
end

function TrackLines:onTrackLinesMoveUp()
    self.left_line.dimen.y = self.left_line.dimen.y - self.increment
    logger.warn("TrackLines decrement y, now render...")
    
    -- UIManager:setDirty (widget, refreshtype, refreshregion, refreshdither)
    -- UIManager:forceRePaint()
    -- UIManager:widgetRepaint (self.left_line, self.left_line.dimen.x, self.left_line.dimen.y)
    UIManager:setDirty(self.left_line, "ui")
    UIManager:forceRePaint()

    logger.warn("TrackLines decrement y, done rendering...")
    return true
end

function TrackLines:onTrackLinesMoveDown()
    self.left_line.dimen.y = self.left_line.dimen.y + self.increment
    logger.warn("TrackLines increment y, now render...")

    UIManager:setDirty(self.left_line, "ui")
    UIManager:forceRePaint()

    logger.warn("TrackLines increment y, done rendering...")
    return true
end

function TrackLines:init()
    logger.warn("TrackLines HELLO")
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

function TrackLines:createUI(readSettings)
    logger.warn("TrackLines about to register and create UI")
    self:onDispatcherRegisterActions()
    if readSettings then
        self.line_thickness = tonumber(self.settings:readSetting("line_thick"))
        self.margin = tonumber(self.settings:readSetting("margin"))
        self.line_color_intensity = tonumber(self.settings:readSetting("line_color_intensity"))
        self.shift_each_pages = tonumber(self.settings:readSetting("shift_each_pages"))
        self.page_counter = tonumber(self.settings:readSetting("page_counter"))
    end

    self.screen_width = Screen:getWidth()

    -- TODO: this is setting line height - we want width
    local screen_height = Screen:getHeight()
    local line_height = math.floor(screen_height * 0.9)
    local line_top_position = math.floor(screen_height * 0.05)

    self.last_screen_mode = Screen:getScreenMode()
    if self.last_screen_mode == "landscape" then
        self.margin = (self.margin - self.margin_shift)
    end

    local line_widget = LineWidget:new{
       background = Blitbuffer.gray(self.line_color_intensity),

       -- TODO: is this where position is set? can we make this horizontal??
        dimen = Geom:new{
            w = line_height,
            h = self.line_thickness,
        },
    }

    self.left_line = WidgetContainer:new{
       -- TODO: is this where position is set? can we make this horizontal??
        dimen = Geom:new{
            x = 0, --self.screen_width * self.margin,
            y = line_top_position,
            w = self.line_thickness,
            h = line_height,
        },
        line_widget
    }

    -- self.right_line = WidgetContainer:new{
    --    -- TODO: is this where position is set? can we make this horizontal??
    --     dimen = Geom:new{
    --         x = self.screen_width - (self.screen_width * self.margin),
    --         y = line_top_position,
    --         w = self.line_thickness,
    --         h = line_height,
    --     },
    --     line_widget
    -- }

    self[1] = HorizontalGroup:new{
        self.left_line,
        -- self.right_line,
    }
end

function TrackLines:onReaderReady()
    self.ui.menu:registerToMainMenu(self)
    self.view:registerViewModule("track_lines", self)
end

function TrackLines:resetLayout()
    self:createUI()
end

function TrackLines:showSettingsDialog()
    self.settings_dialog = MultiInputDialog:new{
        title = _("Track lines settings"),
        fields ={
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
                        self:saveSettings(MultiInputDialog:getFields())
                        self.settings_dialog:onClose()
                        UIManager:close(self.settings_dialog)
                        self:createUI()
                    end
                },
            },
        },
    }
    UIManager:show(self.settings_dialog)
    self.settings_dialog:onShowKeyboard()
end

function TrackLines:addToMainMenu(menu_items)
    menu_items.speed_reading_module_track_lines = {
        text = _("horizontal lines"),
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
                text = _("About"),
                keep_menu_open = true,
                callback = function()
                   -- TODO: MAYBE COPY THIS AND MAKE IT INCREMENT OR DECREMENT LINE WIDTH
                    UIManager:show(InfoMessage:new{
                        text = _("For more information....too bad."),
                    })
                end,
            },
        },
    }
end

function TrackLines:onPageUpdate(pageno)
    if not self.is_enabled then
        return
    end

    -- If this plugin did not apply screen orientation change, redraw plugin UI
    if Screen:getScreenMode() ~= self.last_screen_mode then
        self:createUI()
    end

    if self.shift_each_pages ~= 0 and self.page_counter >= self.shift_each_pages and self.margin < self.ALMOST_CENTER_OF_THE_SCREEN then
        self.page_counter = 0
        self.margin = self.margin + self.margin_shift
        -- self.left_line.dimen.x = self.screen_width * self.margin
        -- self.right_line.dimen.x = self.screen_width - (self.screen_width * self.margin)
    else
        self.page_counter = self.page_counter + 1;
    end
end


function TrackLines:saveSettings(fields)
    if fields then
        self.line_thickness = fields[1] ~= "" and tonumber(fields[1]) or self.line_thickness
        self.margin = fields[2] ~= "" and tonumber(fields[2]) or self.margin

        local line_intensity = fields[3] ~= "" and tonumber(fields[3]) or self.line_color_intensity * 10
        if line_intensity then
            self.line_color_intensity = line_intensity / 10
        end
        self.shift_each_pages = fields[4] ~= "" and tonumber(fields[4]) or self.shift_each_pages
    end

    self.settings:saveSetting("line_thick", self.line_thickness)
    self.settings:saveSetting("margin", self.margin)
    self.settings:saveSetting("line_color_intensity", self.line_color_intensity)
    self.settings:saveSetting("shift_each_pages", self.shift_each_pages)
    self.settings:saveSetting("is_enabled", self.is_enabled)
    self.settings:flush()

    self:createUI()
end

function TrackLines:paintTo(bb, x, y)
    if self.is_enabled and self[1] then
        self[1]:paintTo(bb, x, y)
    end
end

return TrackLines
