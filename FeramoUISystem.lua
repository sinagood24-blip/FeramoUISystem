-- RayfieldX.lua
-- A compact, modular GUI library for Roblox inspired by Rayfield but improved.
-- Single-file module: returns a library table. Use like:
-- local RayfieldX = require(path.to.RayfieldX)
-- local win = RayfieldX:CreateWindow({Title = "My UI"})
-- local tab = win:CreateTab("Main")
-- local sec = tab:CreateSection("Controls")
-- sec:AddButton("Click me", function() print("clicked") end)

local TweenService = game:GetService("TweenService")
local UserInputService = game:GetService("UserInputService")
local RunService = game:GetService("RunService")

local RayfieldX = {}
RayfieldX.__index = RayfieldX

-- Default theme
local DefaultTheme = {
    Background = Color3.fromRGB(24,24,24),
    Accent = Color3.fromRGB(0,170,255),
    Text = Color3.fromRGB(235,235,235),
    Secondary = Color3.fromRGB(40,40,40),
    Success = Color3.fromRGB(67,181,129),
    Warning = Color3.fromRGB(255,170,0),
}

-- Utility functions
local function new(class, props)
    local inst = Instance.new(class)
    if props then
        for k,v in pairs(props) do
            inst[k] = v
        end
    end
    return inst
end

local function tween(inst, props, time, style, dir)
    style = style or Enum.EasingStyle.Quad
    dir = dir or Enum.EasingDirection.Out
    local info = TweenInfo.new(time or 0.18, style, dir)
    local t = TweenService:Create(inst, info, props)
    t:Play()
    return t
end

-- Simple helper: make text button
local function makeButton(text)
    local b = new("TextButton", {
        AutoButtonColor = false,
        Text = text,
        Size = UDim2.new(1,0,0,28),
        BackgroundTransparency = 1,
        Font = Enum.Font.GothamSemibold,
        TextSize = 14,
        TextColor3 = DefaultTheme.Text,
    })
    return b
end

-- Core constructor: CreateWindow
function RayfieldX:CreateWindow(opts)
    opts = opts or {}
    local title = opts.Title or "RayfieldX Window"
    local theme = opts.Theme or DefaultTheme

    local screen = new("ScreenGui", {Name = "RayfieldX_GUI", ResetOnSpawn = false, Parent = game:GetService("Players").LocalPlayer:WaitForChild("PlayerGui")})

    local main = new("Frame", {
        Name = "Main",
        Size = UDim2.new(0, 720, 0, 420),
        Position = UDim2.new(0.5, -360, 0.5, -210),
        AnchorPoint = Vector2.new(0.5, 0.5),
        BackgroundColor3 = theme.Background,
        Parent = screen,
        ClipsDescendants = true,
    })

    local uiCorner = new("UICorner", {CornerRadius = UDim.new(0, 8), Parent = main})

    local titleBar = new("Frame", {
        Name = "TitleBar",
        Size = UDim2.new(1,0,0,40),
        BackgroundColor3 = theme.Secondary,
        Parent = main,
    })
    new("UICorner", {Parent = titleBar, CornerRadius = UDim.new(0,8)})

    local titleLabel = new("TextLabel", {
        Text = title,
        BackgroundTransparency = 1,
        Size = UDim2.new(1, -120, 1, 0),
        Position = UDim2.new(0, 16, 0, 0),
        Font = Enum.Font.GothamBold,
        TextSize = 16,
        TextColor3 = theme.Text,
        TextXAlignment = Enum.TextXAlignment.Left,
        Parent = titleBar,
    })

    local buttonClose = new("TextButton", {
        Text = "×",
        Size = UDim2.new(0,36,0,36),
        Position = UDim2.new(1, -44, 0.5, -18),
        BackgroundTransparency = 1,
        Font = Enum.Font.SourceSansBold,
        TextSize = 24,
        TextColor3 = theme.Text,
        Parent = titleBar,
    })

    -- Dragging support
    do
        local dragging, dragInput, dragStart, startPos
        titleBar.InputBegan:Connect(function(input)
            if input.UserInputType == Enum.UserInputType.MouseButton1 then
                dragging = true
                dragStart = input.Position
                startPos = main.Position
                input.Changed:Connect(function()
                    if input.UserInputState == Enum.UserInputState.End then
                        dragging = false
                    end
                end)
            end
        end)
        titleBar.InputChanged:Connect(function(input)
            if input.UserInputType == Enum.UserInputType.MouseMovement then
                dragInput = input
            end
        end)
        UserInputService.InputChanged:Connect(function(input)
            if input == dragInput and dragging then
                local delta = input.Position - dragStart
                main.Position = UDim2.new(startPos.X.Scale, startPos.X.Offset + delta.X, startPos.Y.Scale, startPos.Y.Offset + delta.Y)
            end
        end)
    end

    -- Layout: tabs column and content
    local left = new("Frame", {Parent = main, Size = UDim2.new(0, 200, 1, -40), Position = UDim2.new(0,0,0,40), BackgroundTransparency = 1})
    local right = new("Frame", {Parent = main, Size = UDim2.new(1, -200, 1, -40), Position = UDim2.new(0,200,0,40), BackgroundTransparency = 1})

    local tabList = new("UIListLayout", {Parent = left, Padding = UDim.new(0,8), SortOrder = Enum.SortOrder.LayoutOrder})
    left.Padding = 8

    -- content scroll
    local content = new("ScrollingFrame", {Parent = right, Size = UDim2.new(1,0,1,0), BackgroundTransparency = 1, CanvasSize = UDim2.new(0,0,0,0)})
    local contentLayout = new("UIListLayout", {Parent = content, SortOrder = Enum.SortOrder.LayoutOrder, Padding = UDim.new(0, 8)})
    content:GetPropertyChangedSignal("CanvasSize"):Connect(function()
        content.CanvasSize = UDim2.new(0,0,0,contentLayout.AbsoluteContentSize.Y + 16)
    end)

    -- close behavior
    buttonClose.MouseButton1Click:Connect(function()
        tween(main, {Size = UDim2.new(0,0,0,0)}, 0.18)
        wait(0.18)
        screen:Destroy()
    end)

    -- Window object
    local window = {
        _screen = screen,
        _main = main,
        _left = left,
        _right = right,
        _tabs = {},
        theme = theme,
    }
    setmetatable(window, RayfieldX)

    -- API: create tab
    function window:CreateTab(name)
        local tabBtn = makeButton(name)
        tabBtn.Parent = left
        tabBtn.TextColor3 = self.theme.Text
        tabBtn.BackgroundTransparency = 1

        -- tab content frame
        local tabContent = new("Frame", {Parent = content, Size = UDim2.new(1,0,0,0), BackgroundTransparency = 1, Visible = false})
        local tabLayout = new("UIListLayout", {Parent = tabContent, SortOrder = Enum.SortOrder.LayoutOrder, Padding = UDim.new(0,6)})

        local tabObj = {name = name, _button = tabBtn, _content = tabContent}

        function tabObj:CreateSection(title)
            local secFrame = new("Frame", {Parent = tabContent, Size = UDim2.new(1,0,0,40), BackgroundColor3 = self._lib and self._lib.theme.Secondary or DefaultTheme.Secondary})
            secFrame.BackgroundTransparency = 0
            secFrame.ClipsDescendants = true
            new("UICorner", {Parent = secFrame, CornerRadius = UDim.new(0,6)})

            local secTitle = new("TextLabel", {Parent = secFrame, Text = title, BackgroundTransparency = 1, Size = UDim2.new(1,-12,0,28), Position = UDim2.new(0,6,0,6), Font = Enum.Font.GothamBold, TextSize = 14, TextColor3 = self._lib and self._lib.theme.Text or DefaultTheme.Text, TextXAlignment = Enum.TextXAlignment.Left})

            local inner = new("Frame", {Parent = secFrame, Size = UDim2.new(1,-12,0,28), Position = UDim2.new(0,6,0,34), BackgroundTransparency = 1})
            local innerLayout = new("UIListLayout", {Parent = inner, FillDirection = Enum.FillDirection.Vertical, SortOrder = Enum.SortOrder.LayoutOrder, Padding = UDim.new(0,4)})

            -- maintain size
            local function refreshSize()
                wait() -- allow layout
                local h = secTitle.AbsoluteSize.Y + innerLayout.AbsoluteContentSize.Y + 18
                secFrame.Size = UDim2.new(1,0,0,h)
            end

            local section = {}

            function section:AddButton(text, callback)
                local btn = makeButton(text)
                btn.Parent = inner
                btn.MouseButton1Click:Connect(function()
                    tween(btn, {TextTransparency = 0.5}, 0.08)
                    pcall(callback)
                end)
                refreshSize()
                return btn
            end

            function section:AddToggle(text, default, callback)
                local container = new("Frame", {Parent = inner, Size = UDim2.new(1,0,0,28), BackgroundTransparency = 1})
                local lbl = new("TextLabel", {Parent = container, Text = text, BackgroundTransparency = 1, Size = UDim2.new(1,-40,1,0), Position = UDim2.new(0,0,0,0), Font = Enum.Font.Gotham, TextSize = 14, TextColor3 = self._lib and self._lib.theme.Text or DefaultTheme.Text, TextXAlignment = Enum.TextXAlignment.Left})
                local toggle = new("TextButton", {Parent = container, Size = UDim2.new(0,36,0,20), Position = UDim2.new(1,-36,0.5,-10), BackgroundColor3 = default and (self._lib and self._lib.theme.Accent or DefaultTheme.Accent) or Color3.fromRGB(60,60,60), Text = "", AutoButtonColor = false})
                new("UICorner", {Parent = toggle, CornerRadius = UDim.new(0,6)})
                local state = default or false
                toggle.MouseButton1Click:Connect(function()
                    state = not state
                    tween(toggle, {BackgroundColor3 = state and (self._lib and self._lib.theme.Accent or DefaultTheme.Accent) or Color3.fromRGB(60,60,60)}, 0.12)
                    pcall(callback, state)
                end)
                refreshSize()
                return toggle
            end

            function section:AddSlider(label, min, max, default, callback)
                min = min or 0
                max = max or 100
                default = default or min
                local sliderFrame = new("Frame", {Parent = inner, Size = UDim2.new(1,0,0,36), BackgroundTransparency = 1})
                local lbl = new("TextLabel", {Parent = sliderFrame, Text = label.." — "..tostring(default), BackgroundTransparency = 1, Size = UDim2.new(1,0,0,14), Position = UDim2.new(0,0,0,0), Font = Enum.Font.Gotham, TextSize = 13, TextColor3 = self._lib and self._lib.theme.Text or DefaultTheme.Text, TextXAlignment = Enum.TextXAlignment.Left})
                local barBg = new("Frame", {Parent = sliderFrame, Size = UDim2.new(1,0,0,12), Position = UDim2.new(0,0,0,18), BackgroundColor3 = Color3.fromRGB(60,60,60)})
                new("UICorner", {Parent = barBg, CornerRadius = UDim.new(0,6)})
                local fill = new("Frame", {Parent = barBg, Size = UDim2.new((default - min)/(max-min),0,1,0), BackgroundColor3 = self._lib and self._lib.theme.Accent or DefaultTheme.Accent})
                new("UICorner", {Parent = fill, CornerRadius = UDim.new(0,6)})

                local dragging = false
                local function updateFromInput(x)
                    local relative = math.clamp((x - barBg.AbsolutePosition.X)/barBg.AbsoluteSize.X, 0, 1)
                    fill.Size = UDim2.new(relative,0,1,0)
                    local val = min + relative * (max-min)
                    lbl.Text = label.." — "..string.format("%.2f", val)
                    pcall(callback, val)
                end

                barBg.InputBegan:Connect(function(input)
                    if input.UserInputType == Enum.UserInputType.MouseButton1 then
                        dragging = true
                        updateFromInput(input.Position.X)
                    end
                end)
                barBg.InputChanged:Connect(function(input)
                    if input.UserInputType == Enum.UserInputType.MouseMovement and dragging then
                        updateFromInput(input.Position.X)
                    end
                end)
                UserInputService.InputEnded:Connect(function(input)
                    if input.UserInputType == Enum.UserInputType.MouseButton1 then
                        dragging = false
                    end
                end)

                refreshSize()
                return {frame = sliderFrame, set = function(v) updateFromInput(barBg.AbsolutePosition.X + (v-min)/(max-min) * barBg.AbsoluteSize.X) end}
            end

            function section:AddDropdown(label, options, callback)
                options = options or {}
                local ddFrame = new("Frame", {Parent = inner, Size = UDim2.new(1,0,0,28), BackgroundTransparency = 1})
                local lbl = new("TextLabel", {Parent = ddFrame, Text = label, BackgroundTransparency = 1, Size = UDim2.new(1,-24,1,0), Position = UDim2.new(0,0,0,0), Font = Enum.Font.Gotham, TextSize = 14, TextColor3 = self._lib and self._lib.theme.Text or DefaultTheme.Text, TextXAlignment = Enum.TextXAlignment.Left})
                local btn = new("TextButton", {Parent = ddFrame, Size = UDim2.new(0,20,0,20), Position = UDim2.new(1,-20,0.5,-10), Text = ">", BackgroundTransparency = 1})

                local expanded = false
                local list
                btn.MouseButton1Click:Connect(function()
                    expanded = not expanded
                    if expanded then
                        list = new("Frame", {Parent = tabContent, Size = UDim2.new(1,0,0,#options*28), BackgroundColor3 = self._lib and self._lib.theme.Secondary or DefaultTheme.Secondary})
                        new("UICorner", {Parent = list, CornerRadius = UDim.new(0,6)})
                        list.Position = UDim2.new(0,0,0, tabContent.AbsoluteSize.Y)
                        for i,opt in ipairs(options) do
                            local it = makeButton(opt)
                            it.Parent = list
                            it.MouseButton1Click:Connect(function()
                                pcall(callback, opt)
                                list:Destroy()
                                expanded = false
                                refreshSize()
                            end)
                        end
                    else
                        if list then list:Destroy() end
                    end
                end)

                refreshSize()
                return ddFrame
            end

            function section:AddTextbox(label, placeholder, callback)
                local boxFrame = new("Frame", {Parent = inner, Size = UDim2.new(1,0,0,36), BackgroundTransparency = 1})
                local lbl = new("TextLabel", {Parent = boxFrame, Text = label, BackgroundTransparency = 1, Size = UDim2.new(1,0,0,14), Position = UDim2.new(0,0,0,0), Font = Enum.Font.Gotham, TextSize = 13, TextColor3 = self._lib and self._lib.theme.Text or DefaultTheme.Text, TextXAlignment = Enum.TextXAlignment.Left})
                local txt = new("TextBox", {Parent = boxFrame, Size = UDim2.new(1,0,0,18), Position = UDim2.new(0,0,0,18), Text = "", PlaceholderText = placeholder or "", ClearTextOnFocus = false, Font = Enum.Font.Gotham, TextSize = 14, TextColor3 = self._lib and self._lib.theme.Text or DefaultTheme.Text})
                txt.FocusLost:Connect(function(enter)
                    pcall(callback, txt.Text)
                end)
                refreshSize()
                return txt
            end

            function section:AddColorPicker(label, default, callback)
                default = default or Color3.fromRGB(255,255,255)
                local cpFrame = new("Frame", {Parent = inner, Size = UDim2.new(1,0,0,36), BackgroundTransparency = 1})
                local lbl = new("TextLabel", {Parent = cpFrame, Text = label, BackgroundTransparency = 1, Size = UDim2.new(1,-48,1,0), Position = UDim2.new(0,0,0,0), Font = Enum.Font.Gotham, TextSize = 14, TextColor3 = self._lib and self._lib.theme.Text or DefaultTheme.Text, TextXAlignment = Enum.TextXAlignment.Left})
                local swatch = new("Frame", {Parent = cpFrame, Size = UDim2.new(0,28,0,18), Position = UDim2.new(1,-34,0.5,-9), BackgroundColor3 = default})
                new("UICorner", {Parent = swatch, CornerRadius = UDim.new(0,6)})

                swatch.InputBegan:Connect(function(input)
                    if input.UserInputType == Enum.UserInputType.MouseButton1 then
                        -- Minimal color chooser: show 3 sliders: R, G, B
                        local chooser = new("Frame", {Parent = tabContent, Size = UDim2.new(0,200,0,120), BackgroundColor3 = self._lib and self._lib.theme.Secondary or DefaultTheme.Secondary})
                        new("UICorner", {Parent = chooser, CornerRadius = UDim.new(0,6)})
                        chooser.Position = UDim2.new(0,0,0, tabContent.AbsoluteSize.Y)
                        local y = 6
                        local function makeRGBSlider(name, init, setfunc)
                            local lab = new("TextLabel", {Parent = chooser, Text = name.." — "..tostring(init), BackgroundTransparency = 1, Size = UDim2.new(1, -12, 0, 20), Position = UDim2.new(0,6,0,y), Font = Enum.Font.Gotham, TextSize = 12, TextColor3 = self._lib and self._lib.theme.Text or DefaultTheme.Text, TextXAlignment = Enum.TextXAlignment.Left})
                            local bar = new("Frame", {Parent = chooser, Size = UDim2.new(1,-12,0,12), Position = UDim2.new(0,6,0,y+20), BackgroundColor3 = Color3.fromRGB(60,60,60)})
                            new("UICorner", {Parent = bar, CornerRadius = UDim.new(0,6)})
                            local fill = new("Frame", {Parent = bar, Size = UDim2.new(init/255,0,1,0), BackgroundColor3 = self._lib and self._lib.theme.Accent or DefaultTheme.Accent})
                            new("UICorner", {Parent = fill, CornerRadius = UDim.new(0,6)})
                            local dragging = false
                            local function upd(x)
                                local rel = math.clamp((x - bar.AbsolutePosition.X)/bar.AbsoluteSize.X, 0, 1)
                                fill.Size = UDim2.new(rel,0,1,0)
                                local val = math.floor(rel*255)
                                lab.Text = name.." — "..tostring(val)
                                setfunc(val)
                            end
                            bar.InputBegan:Connect(function(i)
                                if i.UserInputType == Enum.UserInputType.MouseButton1 then dragging = true; upd(i.Position.X) end
                            end)
                            bar.InputChanged:Connect(function(i) if i.UserInputType == Enum.UserInputType.MouseMovement and dragging then upd(i.Position.X) end end)
                            UserInputService.InputEnded:Connect(function(i) if i.UserInputType == Enum.UserInputType.MouseButton1 then dragging = false end end)
                            y = y + 40
                        end
                        local r,g,b = default.R * 255, default.G*255, default.B*255
                        local col = {r=r,g=g,b=b}
                        makeRGBSlider("R", col.r, function(v) col.r = v swatch.BackgroundColor3 = Color3.fromRGB(col.r, col.g, col.b) pcall(callback, Color3.fromRGB(col.r,col.g,col.b)) end)
                        makeRGBSlider("G", col.g, function(v) col.g = v swatch.BackgroundColor3 = Color3.fromRGB(col.r, col.g, col.b) pcall(callback, Color3.fromRGB(col.r,col.g,col.b)) end)
                        makeRGBSlider("B", col.b, function(v) col.b = v swatch.BackgroundColor3 = Color3.fromRGB(col.r, col.g, col.b) pcall(callback, Color3.fromRGB(col.r,col.g,col.b)) end)

                        local closeBtn = new("TextButton", {Parent = chooser, Text = "Close", Size = UDim2.new(1,-12,0,26), Position = UDim2.new(0,6,0,y+6), BackgroundTransparency = 1})
                        closeBtn.MouseButton1Click:Connect(function() chooser:Destroy() end)
                    end
                end)

                refreshSize()
                return swatch
            end

            -- attach backref
            section._lib = self._lib or window
            refreshSize()
            return section
        end

        -- wire button to show tab
        tabBtn.MouseButton1Click:Connect(function()
            for _,t in ipairs(self._tabs) do
                t._content.Visible = false
            end
            tabContent.Visible = true
        end)

        -- store
        tabObj._lib = window
        table.insert(window._tabs, tabObj)

        -- if first tab, show it
        if #window._tabs == 1 then
            tabBtn:MouseButton1Click()
        end

        return tabObj
    end

    -- theme setter
    function window:SetTheme(t)
        self.theme = t
        self._main.BackgroundColor3 = t.Background
        self._main.TitleBar.BackgroundColor3 = t.Secondary
        -- Rest of elements can be themed on creation (for brevity we don't recolor all existing elements here)
    end

    -- Helper: notification
    function window:Notify(text, duration)
        duration = duration or 3
        local notif = new("Frame", {Parent = self._screen, Size = UDim2.new(0,280,0,50), Position = UDim2.new(1,-300,1,-80), BackgroundColor3 = self.theme.Secondary})
        new("UICorner", {Parent = notif, CornerRadius = UDim.new(0,8)})
        local lbl = new("TextLabel", {Parent = notif, Text = text, BackgroundTransparency = 1, Size = UDim2.new(1,-12,1,0), Position = UDim2.new(0,6,0,0), Font = Enum.Font.Gotham, TextSize = 14, TextColor3 = self.theme.Text, TextWrapped = true})
        notif.Position = UDim2.new(1, -320, 1, 20)
        tween(notif, {Position = UDim2.new(1, -300, 1, -80)}, 0.24)
        delay(duration, function()
            tween(notif, {Position = UDim2.new(1, -320, 1, 20)}, 0.22)
            wait(0.22)
            notif:Destroy()
        end)
    end

    return window
end

return RayfieldX
