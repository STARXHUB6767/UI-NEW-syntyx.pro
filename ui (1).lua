-- ============================================================
-- syntyx.pro UI Library (Topographic Theme) - v2
-- ============================================================
-- API (เข้ากันได้กับเวอร์ชันเดิม):
--   local Win = Library.CreateLib("syntyx.pro", nil, "logoId")   หรือ  Library.CreateLib({ Title=..., Logo=..., ToggleKey=Enum.KeyCode.RightShift })
--   local Tab = Win:NewTab("Farm", "81535612333178")             -- icon ใส่หรือไม่ใส่ก็ได้
--   local Sec = Tab:NewSection("Auto Farm")
--   Sec:NewButton(text, info, callback)              -> :UpdateButton(text)
--   Sec:NewToggle(text, info, [initial], callback)   -> :Set(bool, silent) / :Get()
--   Sec:NewSlider(text, info, max, min, callback, [default]) -> :Set(n, silent) / :Get()
--   Sec:NewDropdown(text, info, list, callback, [default])   -> :Set(v) / :Refresh(list) / :Get()
--   Sec:NewTextBox(text, info, callback, [placeholder])      -> :Set(text) / :Get()
--   Sec:NewKeybind(text, info, defaultKey, callback)         -> :Set(KeyCode) / :Get()
--   Sec:NewLabel(text)                                       -> :UpdateLabel(text)
--   Win:Notify(title, text, "info"|"ok"|"warn"|"err", duration)
--   Win:SetStatus(text, [kind]) / Win:SetCounter(n) / Win:SetToggleKey(KeyCode)
--   Win:Minimize() / Win:Restore() / Win:Toggle() / Win:Destroy()
-- ============================================================
local Players          = game:GetService("Players")
local UserInputService = game:GetService("UserInputService")
local TweenService     = game:GetService("TweenService")
local SoundService     = game:GetService("SoundService")

local LP = Players.LocalPlayer
local PG = LP:WaitForChild("PlayerGui")

local Library = {}

-- ============================================================
-- CONFIG & THEME
-- ============================================================
local GUI_NAME      = "SyntyxPro"
local BRAND_NAME    = "syntyx.pro"
local BRAND_SUB     = "discord.gg"
-- ใส่ Roblox Image/Decal ID ของโลโก้ ถ้าว่างจะแสดงตัว "S" สีแดงแทน
local LOGO_IMAGE_ID = ""
local TOPO_IMAGE_ID = "rbxassetid://137559326703430" -- ลาย Topographic
local DEFAULT_TOGGLE_KEY = Enum.KeyCode.RightShift   -- ปุ่มซ่อน/แสดง UI

local SOUND_IDS = { click = "6895079853", on = "6895079853", off = "6895079853" }
local SOUND_VOLUME = 0.5

local function fixId(id)
    if id == nil then return "" end
    id = tostring(id)
    if id ~= "" and tonumber(id) then return "rbxassetid://" .. id end
    return id
end
LOGO_IMAGE_ID = fixId(LOGO_IMAGE_ID)

local C = {
    Window = Color3.fromRGB(22, 16, 18), Window2 = Color3.fromRGB(14, 10, 11),
    Sidebar = Color3.fromRGB(13, 9, 10), Bar = Color3.fromRGB(13, 9, 10), Card = Color3.fromRGB(20, 18, 19),
    Text = Color3.fromRGB(244, 238, 240), Dim = Color3.fromRGB(170, 160, 164), Faint = Color3.fromRGB(120, 110, 114),
    Accent = Color3.fromRGB(228, 16, 30), Accent2 = Color3.fromRGB(110, 4, 12), AccentText = Color3.fromRGB(255, 120, 130),
    Off = Color3.fromRGB(60, 50, 54), Plate = Color3.fromRGB(236, 228, 231), Input = Color3.fromRGB(10, 7, 8),
    Red = Color3.fromRGB(229, 72, 77), Yellow = Color3.fromRGB(242, 182, 61), Green = Color3.fromRGB(63, 191, 107),
    White = Color3.fromRGB(255, 255, 255), ScrollBar = Color3.fromRGB(120, 100, 105),
}
local T = { Window = 0.18, Sidebar = 0.04, Bar = 0.28, Card = 0.35, Line = 0.92, Stroke = 0.88 }
local KNOB_OFF = Color3.fromRGB(207, 197, 201)
local FONT, FONT_B, FONT_BLACK = Enum.Font.Gotham, Enum.Font.GothamBold, Enum.Font.GothamBlack

-- ============================================================
-- HELPERS
-- ============================================================
local Connections = {}           -- ถูกแทนที่ด้วยตารางของหน้าต่างปัจจุบันตอน CreateLib
local ToastHolder = nil
local soundCache = {}
local keybindListening = false   -- กันปุ่มลัด UI ทำงานตอนกำลังตั้งคีย์

local function bind(sig, fn)
    local c = sig:Connect(fn)
    table.insert(Connections, c)
    return c
end

local function mk(class, props, parent)
    local o = Instance.new(class)
    for k, v in pairs(props) do o[k] = v end
    if parent then o.Parent = parent end
    return o
end

local function corner(parent, r) return mk("UICorner", { CornerRadius = UDim.new(0, r) }, parent) end
local function stroke(parent, color, transp, thickness)
    return mk("UIStroke", { Color = color, Transparency = transp or 0, Thickness = thickness or 1, ApplyStrokeMode = Enum.ApplyStrokeMode.Border }, parent)
end
local function padding(parent, l, r, t, b)
    return mk("UIPadding", { PaddingLeft = UDim.new(0, l or 0), PaddingRight = UDim.new(0, r or 0), PaddingTop = UDim.new(0, t or 0), PaddingBottom = UDim.new(0, b or 0) }, parent)
end
local function line(parent, props)
    local p = { Size = UDim2.new(1, 0, 0, 1), BackgroundColor3 = C.White, BackgroundTransparency = T.Line, BorderSizePixel = 0 }
    for k, v in pairs(props or {}) do p[k] = v end
    return mk("Frame", p, parent)
end

-- tween ที่ยกเลิกตัวเก่าอัตโนมัติเมื่อ property เดียวกันถูก tween ซ้ำ (กันอนิเมชันตีกัน)
local tweenReg = setmetatable({}, { __mode = "k" })
local function tw(obj, t, props, style, dir)
    if not obj or not obj.Parent then
        for k, v in pairs(props) do pcall(function() obj[k] = v end) end
        return nil
    end
    local keys = {}
    for k in pairs(props) do keys[#keys + 1] = k end
    table.sort(keys)
    local key = table.concat(keys, ",")
    local reg = tweenReg[obj]
    if not reg then reg = {}; tweenReg[obj] = reg end
    local old = reg[key]
    if old then old:Cancel() end
    local tween = TweenService:Create(obj, TweenInfo.new(t, style or Enum.EasingStyle.Quint, dir or Enum.EasingDirection.Out), props)
    reg[key] = tween
    tween:Play()
    return tween
end

local function playSound(kind)
    local id = fixId(SOUND_IDS[kind])
    if id == "" then return end
    local s = soundCache[kind]
    if not s or not s.Parent then
        s = Instance.new("Sound")
        s.SoundId = id; s.Volume = SOUND_VOLUME; s.Parent = SoundService
        soundCache[kind] = s
    end
    s.TimePosition = 0
    s:Play()
end

-- เรียก callback แบบไม่ทำให้ UI ค้าง + แสดง error ใน console แทนการกลืนเงียบ
local function safeCall(fn, ...)
    if type(fn) ~= "function" then return end
    local args = table.pack(...)
    task.spawn(function()
        local ok, err = pcall(fn, table.unpack(args, 1, args.n))
        if not ok then warn("[" .. BRAND_NAME .. "] callback error: " .. tostring(err)) end
    end)
end

local function label(parent, props)
    local p = { BackgroundTransparency = 1, TextColor3 = C.Text, Font = FONT, TextSize = 14, TextXAlignment = Enum.TextXAlignment.Left, TextYAlignment = Enum.TextYAlignment.Center }
    for k, v in pairs(props) do p[k] = v end
    return mk("TextLabel", p, parent)
end

local function redGradient(parent, rotation)
    return mk("UIGradient", { Rotation = rotation or 0, Color = ColorSequence.new(C.Accent2, C.Accent) }, parent)
end

local function escapeRich(s)
    s = tostring(s)
    s = s:gsub("&", "&amp;"):gsub("<", "&lt;"):gsub(">", "&gt;")
    return s
end

local function hasText(s) return type(s) == "string" and s ~= "" end

local function press(btn, target, silent)
    target = target or btn
    local sc = mk("UIScale", { Scale = 1 }, target)
    bind(btn.MouseButton1Down, function()
        if not silent then playSound("click") end
        tw(sc, 0.1, { Scale = 0.94 }, Enum.EasingStyle.Quad)
    end)
    local function up() tw(sc, 0.35, { Scale = 1 }, Enum.EasingStyle.Back) end
    bind(btn.MouseButton1Up, up); bind(btn.MouseLeave, up)
    return sc
end

local function hover(btn, onEnter, onLeave)
    bind(btn.MouseEnter, onEnter)
    bind(btn.MouseLeave, onLeave)
end

local function isPointer(input)
    return input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch
end
local function isMove(input)
    return input.UserInputType == Enum.UserInputType.MouseMovement or input.UserInputType == Enum.UserInputType.Touch
end

local function getGuiParent()
    if typeof(gethui) == "function" then
        local ok, h = pcall(gethui)
        if ok and typeof(h) == "Instance" then return h end
    end
    return PG
end

local function makeLogo(parent, size, radius, textSize, z)
    local logo = mk("Frame", { Size = UDim2.fromOffset(size, size), BackgroundColor3 = C.White, BorderSizePixel = 0, ZIndex = z }, parent)
    corner(logo, radius)
    if LOGO_IMAGE_ID ~= "" then
        logo.BackgroundTransparency = 1
        mk("ImageLabel", { Size = UDim2.fromScale(1, 1), BackgroundTransparency = 1, Image = LOGO_IMAGE_ID, ScaleType = Enum.ScaleType.Fit, ZIndex = z }, logo)
    else
        mk("UIGradient", { Rotation = 45, Color = ColorSequence.new(C.Accent, C.Accent2) }, logo)
        label(logo, { Size = UDim2.fromScale(1, 1), Text = "S", Font = FONT_BLACK, TextSize = textSize, TextColor3 = C.White, TextXAlignment = Enum.TextXAlignment.Center, ZIndex = z + 1 })
    end
    return logo
end

-- ============================================================
-- NOTIFICATIONS
-- ============================================================
local toastCount = 0
local TOAST_COLORS = { info = C.Accent, ok = C.Green, warn = C.Yellow, err = C.Red }
local TOAST_ICONS  = { info = "i", ok = "✓", warn = "!", err = "×" }

local function notify(title, text, kind, duration)
    if not ToastHolder or not ToastHolder.Parent then return end
    kind = TOAST_COLORS[kind] and kind or "info"
    duration = tonumber(duration) or 3.5
    toastCount += 1

    local slots = {}
    for _, ch in ipairs(ToastHolder:GetChildren()) do
        if ch:IsA("Frame") then table.insert(slots, ch) end
    end
    table.sort(slots, function(a, b) return a.LayoutOrder < b.LayoutOrder end)
    while #slots >= 4 do table.remove(slots, 1):Destroy() end

    local color = TOAST_COLORS[kind]
    local hasBody = hasText(text)
    local H = hasBody and 62 or 44
    local slot = mk("Frame", { Size = UDim2.new(1, 0, 0, H), BackgroundTransparency = 1, LayoutOrder = toastCount }, ToastHolder)
    local card = mk("CanvasGroup", { Size = UDim2.fromScale(1, 1), Position = UDim2.new(1, 40, 0, 0), BackgroundColor3 = C.Window, BackgroundTransparency = 0.05, BorderSizePixel = 0, GroupTransparency = 1 }, slot)
    corner(card, 12); stroke(card, C.White, 0.86, 1)

    local icon = mk("Frame", { Size = UDim2.fromOffset(26, 26), Position = UDim2.new(0, 12, 0.5, -13), BackgroundColor3 = color, BackgroundTransparency = 0.8, BorderSizePixel = 0 }, card)
    corner(icon, 13); stroke(icon, color, 0.4, 1)
    label(icon, { Size = UDim2.fromScale(1, 1), Text = TOAST_ICONS[kind], Font = FONT_BLACK, TextSize = 14, TextColor3 = color, TextXAlignment = Enum.TextXAlignment.Center })

    label(card, { Size = UDim2.new(1, -60, 0, 18), Position = UDim2.fromOffset(48, hasBody and 11 or 13), Text = tostring(title or ""), Font = FONT_B, TextSize = 14, TextTruncate = Enum.TextTruncate.AtEnd })
    if hasBody then
        label(card, { Size = UDim2.new(1, -60, 0, 16), Position = UDim2.fromOffset(48, 31), Text = text, TextSize = 12, TextColor3 = C.Dim, TextTruncate = Enum.TextTruncate.AtEnd })
    end
    local timer = mk("Frame", { Size = UDim2.new(1, 0, 0, 2), Position = UDim2.new(0, 0, 1, -2), BackgroundColor3 = color, BackgroundTransparency = 0.2, BorderSizePixel = 0 }, card)

    tw(card, 0.5, { Position = UDim2.new(0, 0, 0, 0), GroupTransparency = 0 }, Enum.EasingStyle.Back)
    tw(timer, duration, { Size = UDim2.new(0, 0, 0, 2) }, Enum.EasingStyle.Linear)
    task.delay(duration, function()
        if not slot.Parent then return end
        tw(card, 0.3, { Position = UDim2.new(1, 40, 0, 0), GroupTransparency = 1 }, Enum.EasingStyle.Quint, Enum.EasingDirection.In)
        task.wait(0.3)
        if not slot.Parent then return end
        tw(slot, 0.2, { Size = UDim2.new(1, 0, 0, 0) })
        task.wait(0.2)
        if slot.Parent then slot:Destroy() end
    end)
end

-- ============================================================
-- CLASS DEFINITIONS
-- ============================================================
local Window = {}; Window.__index = Window
local Tab = {}; Tab.__index = Tab
local Section = {}; Section.__index = Section

-- ============================================================
-- WINDOW CREATION
-- ============================================================
function Library.CreateLib(title, theme, logoId, ...)
    -- รองรับทั้ง Library.CreateLib(...) และ Library:CreateLib(...)
    if title == Library then title, theme, logoId = theme, logoId, ... end
    local toggleKey = DEFAULT_TOGGLE_KEY
    -- รองรับแบบตาราง เช่น CreateLib({ Title = "syntyx.pro", Logo = "123" })
    if type(title) == "table" then
        local cfg = title
        title = cfg.Title or cfg.Name or cfg.title or cfg.name
        theme = cfg.Theme or cfg.theme or theme
        logoId = cfg.Logo or cfg.LogoId or cfg.logo or logoId
        toggleKey = cfg.ToggleKey or cfg.Keybind or toggleKey
    end
    if title ~= nil and type(title) ~= "string" then title = tostring(title) end

    -- ปิดหน้าต่างเก่า (รวมถึง connection ทั้งหมด) ก่อนสร้างใหม่ — กันรันสคริปต์ซ้ำแล้วค้าง/ซ้อน
    if Library._window then pcall(function() Library._window:Destroy(true) end) end
    local guiParent = getGuiParent()
    for _, parent in ipairs({ guiParent, PG }) do
        for _, g in ipairs(parent:GetChildren()) do
            if g.Name == GUI_NAME or g.Name == "StarXHub" then g:Destroy() end
        end
    end
    if logoId and logoId ~= "" then LOGO_IMAGE_ID = fixId(logoId) end

    local self = setmetatable({}, Window)
    Connections = {}
    self._conns = Connections
    self._alive = true
    self.Title = (title and title ~= "") and title or BRAND_NAME
    self.Tabs = {}
    self.Minimized = false
    self.Maximized = false
    self.ToggleKey = toggleKey
    Library._window = self

    local GUI = mk("ScreenGui", { Name = GUI_NAME, ResetOnSpawn = false, IgnoreGuiInset = true, DisplayOrder = 999, ZIndexBehavior = Enum.ZIndexBehavior.Sibling }, guiParent)
    self.GUI = GUI

    local WIN_W, WIN_H, SIDE_W, TOP_H, BOT_H = 700, 440, 190, 44, 32
    local MAX_W, MAX_H = 880, 540

    -- Holder = ตัวที่ถูกลาก/ย่อขยาย มีทั้ง Glow และหน้าต่างอยู่ข้างใน (ไม่ต้องใช้ RenderStepped ตามตำแหน่งอีกต่อไป)
    local Holder = mk("Frame", { Name = "Holder", Size = UDim2.fromOffset(WIN_W, WIN_H), AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.5), BackgroundTransparency = 1, ZIndex = 1 }, GUI)
    local HolderScale = mk("UIScale", { Scale = 0.85 }, Holder)
    self.Holder, self.HolderScale = Holder, HolderScale

    local function fitScale()
        local vp = GUI.AbsoluteSize
        if vp.X < 100 or vp.Y < 100 then return 1 end
        local w, h = Holder.Size.X.Offset, Holder.Size.Y.Offset
        return math.clamp(math.min(vp.X / (w + 40), vp.Y / (h + 80)), 0.45, 1)
    end
    self._fitScale = fitScale

    -- Glow
    local GLOW_PAD = 70
    local Glow = mk("CanvasGroup", { Name = "Glow", Size = UDim2.new(1, GLOW_PAD * 2, 1, GLOW_PAD * 2), Position = UDim2.fromOffset(-GLOW_PAD, -GLOW_PAD), BackgroundTransparency = 1, BorderSizePixel = 0, GroupTransparency = 1, ZIndex = 1 }, Holder)
    for i = 1, 9 do
        local e = i * 5
        local layer = mk("Frame", { BackgroundColor3 = C.Accent, BackgroundTransparency = 0.955, BorderSizePixel = 0, Position = UDim2.new(0, GLOW_PAD - e, 0.42, -e * 0.2), Size = UDim2.new(1, -2 * (GLOW_PAD - e), 0.58, e * 1.2 - GLOW_PAD + 10) }, Glow)
        corner(layer, 16 + e)
    end
    self.Glow = Glow

    -- Main Window
    local Main = mk("CanvasGroup", { Name = "Main", Size = UDim2.fromScale(1, 1), BackgroundColor3 = C.Window, BackgroundTransparency = T.Window, BorderSizePixel = 0, GroupTransparency = 1, ZIndex = 2 }, Holder)
    corner(Main, 16); stroke(Main, C.White, T.Stroke - 0.02, 1)
    self.Main = Main

    -- พื้นหลังไล่สีเบาๆ
    local bgGrad = mk("Frame", { Size = UDim2.fromScale(1, 1), BackgroundColor3 = C.White, BackgroundTransparency = 0.6, BorderSizePixel = 0, ZIndex = 0 }, Main)
    mk("UIGradient", { Rotation = 120, Color = ColorSequence.new({ ColorSequenceKeypoint.new(0, Color3.fromRGB(45, 14, 20)), ColorSequenceKeypoint.new(0.5, C.Window), ColorSequenceKeypoint.new(1, C.Window2) }) }, bgGrad)

    tw(Main, 0.45, { GroupTransparency = 0 }); tw(Glow, 0.45, { GroupTransparency = 0 })
    tw(HolderScale, 0.55, { Scale = fitScale() }, Enum.EasingStyle.Back)

    -- Top Line
    local TopLine = mk("Frame", { Size = UDim2.new(1, 0, 0, 2), BackgroundColor3 = C.White, BorderSizePixel = 0, ZIndex = 10 }, Main)
    mk("UIGradient", { Color = ColorSequence.new({ ColorSequenceKeypoint.new(0, Color3.fromRGB(59, 50, 54)), ColorSequenceKeypoint.new(0.5, C.Accent), ColorSequenceKeypoint.new(1, Color3.fromRGB(59, 50, 54)) }) }, TopLine)

    -- Sidebar (Topographic) — ไม่ต้องใส่ corner เอง เพราะ CanvasGroup ตัดมุมให้แล้ว (เดิมมีมุมโค้งโผล่ด้านขวา)
    local Sidebar = mk("Frame", { Size = UDim2.new(0, SIDE_W, 1, 0), BackgroundColor3 = C.Sidebar, BackgroundTransparency = T.Sidebar, BorderSizePixel = 0, ZIndex = 2, ClipsDescendants = true }, Main)
    line(Sidebar, { Size = UDim2.new(0, 1, 1, 0), Position = UDim2.new(1, -1, 0, 0) })
    mk("ImageLabel", { Size = UDim2.fromScale(1, 1), BackgroundTransparency = 1, Image = TOPO_IMAGE_ID, ImageColor3 = Color3.fromRGB(100, 90, 95), ImageTransparency = 0.6, ScaleType = Enum.ScaleType.Crop, ZIndex = 0 }, Sidebar)

    -- Brand / Logo
    local Brand = mk("Frame", { Size = UDim2.new(1, 0, 0, 72), BackgroundTransparency = 1, ZIndex = 2 }, Sidebar)
    local logo = makeLogo(Brand, 44, 13, 26, 2)
    logo.Position = UDim2.fromOffset(14, 14)
    stroke(logo, C.AccentText, 0.7, 1)
    label(Brand, { Size = UDim2.new(1, -76, 0, 20), Position = UDim2.fromOffset(68, 17), Text = self.Title, Font = FONT_B, TextSize = 17, TextTruncate = Enum.TextTruncate.AtEnd, ZIndex = 2 })
    label(Brand, { Size = UDim2.new(1, -76, 0, 14), Position = UDim2.fromOffset(68, 38), Text = BRAND_SUB, TextSize = 12, TextColor3 = C.Dim, TextTruncate = Enum.TextTruncate.AtEnd, ZIndex = 2 })
    line(Sidebar, { Size = UDim2.new(1, -28, 0, 1), Position = UDim2.fromOffset(14, 72), ZIndex = 2 })

    -- Tab List
    label(Sidebar, { Size = UDim2.new(1, -28, 0, 22), Position = UDim2.fromOffset(16, 80), Text = "MENU", Font = FONT_B, TextSize = 10, TextColor3 = C.Faint, ZIndex = 2 })
    local NavList = mk("ScrollingFrame", { Size = UDim2.new(1, -12, 1, -104 - 56), Position = UDim2.fromOffset(6, 104), BackgroundTransparency = 1, BorderSizePixel = 0, ScrollBarThickness = 2, ScrollBarImageColor3 = C.ScrollBar, CanvasSize = UDim2.new(), AutomaticCanvasSize = Enum.AutomaticSize.Y, ScrollingDirection = Enum.ScrollingDirection.Y, ZIndex = 2 }, Sidebar)
    padding(NavList, 4, 6, 2, 4)
    mk("UIListLayout", { Padding = UDim.new(0, 4), SortOrder = Enum.SortOrder.LayoutOrder }, NavList)
    self.NavList = NavList

    -- Profile
    local Profile = mk("Frame", { Size = UDim2.new(1, 0, 0, 56), Position = UDim2.new(0, 0, 1, -56), BackgroundTransparency = 1, ZIndex = 2 }, Sidebar)
    line(Profile, { Size = UDim2.new(1, -28, 0, 1), Position = UDim2.fromOffset(14, 0) })
    local avatar = mk("ImageLabel", { Size = UDim2.fromOffset(32, 32), Position = UDim2.fromOffset(14, 12), BackgroundColor3 = Color3.fromRGB(58, 50, 54), BorderSizePixel = 0, Image = "rbxthumb://type=AvatarHeadShot&id=" .. LP.UserId .. "&w=60&h=60" }, Profile)
    corner(avatar, 16); stroke(avatar, C.AccentText, 0.6, 1)
    local onlineDot = mk("Frame", { Size = UDim2.fromOffset(9, 9), Position = UDim2.new(1, -8, 1, -8), BackgroundColor3 = C.Green, BorderSizePixel = 0, ZIndex = 3 }, avatar)
    corner(onlineDot, 5); stroke(onlineDot, C.Sidebar, 0, 2)
    label(Profile, { Size = UDim2.new(1, -64, 0, 16), Position = UDim2.fromOffset(54, 12), Text = LP.DisplayName, Font = FONT_B, TextSize = 13, TextTruncate = Enum.TextTruncate.AtEnd })
    label(Profile, { Size = UDim2.new(1, -64, 0, 14), Position = UDim2.fromOffset(54, 29), Text = "@" .. LP.Name, TextSize = 11, TextColor3 = C.Faint, TextTruncate = Enum.TextTruncate.AtEnd })

    -- Content Area
    local Content = mk("Frame", { Size = UDim2.new(1, -SIDE_W, 1, 0), Position = UDim2.fromOffset(SIDE_W, 0), BackgroundTransparency = 1, ZIndex = 2 }, Main)

    -- TopBar (Topographic)
    local TopBar = mk("Frame", { Size = UDim2.new(1, 0, 0, TOP_H), BackgroundColor3 = C.Bar, BackgroundTransparency = T.Bar, BorderSizePixel = 0, ZIndex = 2, ClipsDescendants = true }, Content)
    mk("ImageLabel", { Size = UDim2.fromScale(1, 1), BackgroundTransparency = 1, Image = TOPO_IMAGE_ID, ImageColor3 = Color3.fromRGB(100, 90, 95), ImageTransparency = 0.7, ScaleType = Enum.ScaleType.Crop, ZIndex = 0 }, TopBar)
    line(TopBar, { Position = UDim2.new(0, 0, 1, -1), ZIndex = 2 })
    self.Crumb = label(TopBar, { Size = UDim2.new(1, -110, 1, 0), Position = UDim2.fromOffset(18, 0), RichText = true, Text = "", TextSize = 13, TextColor3 = C.Dim, TextTruncate = Enum.TextTruncate.AtEnd, ZIndex = 2 })

    -- Window Controls (Traffic Lights)
    local Controls = mk("Frame", { Size = UDim2.fromOffset(80, TOP_H), Position = UDim2.new(1, -80, 0, 0), BackgroundTransparency = 1, ZIndex = 3 }, TopBar)
    local function trafficLight(x, color, glyph)
        local b = mk("TextButton", { Size = UDim2.fromOffset(13, 13), AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.new(0, x, 0.5, 0), BackgroundColor3 = color, BorderSizePixel = 0, AutoButtonColor = false, Text = "", ZIndex = 3 }, Controls)
        corner(b, 7); press(b)
        local g = label(b, { Size = UDim2.fromScale(1, 1), Text = glyph, Font = FONT_BLACK, TextSize = 9, TextColor3 = Color3.fromRGB(60, 10, 14), TextTransparency = 1, TextXAlignment = Enum.TextXAlignment.Center, ZIndex = 4 })
        hover(b, function()
            tw(b, 0.15, { Size = UDim2.fromOffset(15, 15) }); tw(g, 0.15, { TextTransparency = 0.2 })
        end, function()
            tw(b, 0.15, { Size = UDim2.fromOffset(13, 13) }); tw(g, 0.15, { TextTransparency = 1 })
        end)
        return b
    end
    local MinBtn   = trafficLight(22, C.Yellow, "–")
    local MaxBtn   = trafficLight(42, C.Green, "+")
    self.CloseBtn  = trafficLight(62, C.Red, "×")

    -- Page Holder
    local PageHolder = mk("Frame", { Size = UDim2.new(1, 0, 1, -(TOP_H + BOT_H)), Position = UDim2.fromOffset(0, TOP_H), BackgroundTransparency = 1, ClipsDescendants = true, ZIndex = 2 }, Content)
    self.PageHolder = PageHolder

    -- Status Bar
    local StatusBar = mk("Frame", { Size = UDim2.new(1, 0, 0, BOT_H), Position = UDim2.new(0, 0, 1, -BOT_H), BackgroundColor3 = C.Bar, BackgroundTransparency = T.Bar, BorderSizePixel = 0, ZIndex = 2 }, Content)
    line(StatusBar, {})
    local StatusDot = mk("Frame", { Size = UDim2.fromOffset(7, 7), Position = UDim2.new(0, 18, 0.5, -3), BackgroundColor3 = C.Green, BorderSizePixel = 0, ZIndex = 2 }, StatusBar)
    corner(StatusDot, 4)
    local dotStroke = stroke(StatusDot, C.Green, 0.4, 2)
    TweenService:Create(dotStroke, TweenInfo.new(1, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut, -1, true), { Transparency = 0.95, Thickness = 4 }):Play()
    self.StatusDot, self.StatusDotStroke = StatusDot, dotStroke

    self.StatusLabel = label(StatusBar, { Size = UDim2.new(1, -182, 1, 0), Position = UDim2.fromOffset(34, 0), Text = "พร้อมใช้งาน", TextSize = 12, TextColor3 = C.Dim, TextTruncate = Enum.TextTruncate.AtEnd, ZIndex = 2 })
    self.CounterLabel = label(StatusBar, { Size = UDim2.fromOffset(70, BOT_H), Position = UDim2.new(1, -150, 0, 0), Text = "รอบ: 0", TextSize = 12, TextColor3 = C.Dim, TextXAlignment = Enum.TextXAlignment.Right, ZIndex = 2 })
    local ClockLabel = label(StatusBar, { Size = UDim2.fromOffset(60, BOT_H), Position = UDim2.new(1, -74, 0, 0), Text = "00:00", Font = FONT_B, TextSize = 12, TextColor3 = C.AccentText, TextXAlignment = Enum.TextXAlignment.Right, ZIndex = 2 })

    -- นาฬิกาเวลาที่ใช้งาน
    local startClock = os.clock()
    task.spawn(function()
        while self._alive and ClockLabel.Parent do
            local t = math.floor(os.clock() - startClock)
            local h, m, s = math.floor(t / 3600), math.floor(t / 60) % 60, t % 60
            ClockLabel.Text = h > 0 and string.format("%d:%02d:%02d", h, m, s) or string.format("%02d:%02d", m, s)
            task.wait(1)
        end
    end)

    -- Toasts
    ToastHolder = mk("Frame", { Name = "Toasts", Size = UDim2.new(0, 290, 1, -80), AnchorPoint = Vector2.new(1, 0), Position = UDim2.new(1, -16, 0, 64), BackgroundTransparency = 1, ZIndex = 30 }, GUI)
    mk("UIListLayout", { Padding = UDim.new(0, 8), SortOrder = Enum.SortOrder.LayoutOrder, HorizontalAlignment = Enum.HorizontalAlignment.Right }, ToastHolder)
    self._toastHolder = ToastHolder

    -- ============ Draggable (รองรับเมาส์ + ทัชแบบติดตามนิ้วที่จับอยู่) ============
    local function clampPos(x, y)
        local vp = GUI.AbsoluteSize
        local s = HolderScale.Scale
        local hw, hh = Holder.AbsoluteSize.X / 2, Holder.AbsoluteSize.Y / 2
        if hw <= 0 then hw = Holder.Size.X.Offset * s / 2; hh = Holder.Size.Y.Offset * s / 2 end
        local limX = math.max(vp.X / 2 + hw - 120, 0)
        local limY = math.max(vp.Y / 2 + hh - 60, 0)
        return math.clamp(x, -limX, limX), math.clamp(y, -limY, limY)
    end

    local dragInput, dragStart, startPos
    local function makeDraggable(handle)
        bind(handle.InputBegan, function(input)
            if not isPointer(input) or self.Minimized then return end
            -- ไม่เริ่มลากถ้ากดโดนปุ่มควบคุมหน้าต่าง
            if input.Position.X >= Controls.AbsolutePosition.X and handle == TopBar then return end
            dragInput, dragStart, startPos = input, input.Position, Holder.Position
        end)
    end
    makeDraggable(TopBar); makeDraggable(Brand)

    bind(UserInputService.InputChanged, function(input)
        if not dragInput or not isMove(input) then return end
        if dragInput.UserInputType == Enum.UserInputType.Touch and input ~= dragInput then return end
        local d = input.Position - dragStart
        local nx, ny = clampPos(startPos.X.Offset + d.X, startPos.Y.Offset + d.Y)
        Holder.Position = UDim2.new(startPos.X.Scale, nx, startPos.Y.Scale, ny)
    end)
    bind(UserInputService.InputEnded, function(input)
        if not dragInput then return end
        if input == dragInput or input.UserInputType == Enum.UserInputType.MouseButton1 then dragInput = nil end
    end)

    -- ปรับขนาดอัตโนมัติเมื่อหน้าจอเปลี่ยน (หมุนจอ/ปรับหน้าต่าง)
    bind(GUI:GetPropertyChangedSignal("AbsoluteSize"), function()
        if self.Minimized or not self._alive then return end
        tw(HolderScale, 0.25, { Scale = fitScale() })
        task.delay(0.26, function()
            if not self._alive then return end
            local p = Holder.Position
            local nx, ny = clampPos(p.X.Offset, p.Y.Offset)
            Holder.Position = UDim2.new(p.X.Scale, nx, p.Y.Scale, ny)
        end)
    end)

    bind(self.CloseBtn.Activated, function() self:Destroy() end)
    bind(MinBtn.Activated, function() self:Minimize() end)
    bind(MaxBtn.Activated, function()
        if self.Minimized then return end
        self.Maximized = not self.Maximized
        local w, h = WIN_W, WIN_H
        if self.Maximized then w, h = MAX_W, MAX_H end
        tw(Holder, 0.45, { Size = UDim2.fromOffset(w, h) }, Enum.EasingStyle.Quint)
        -- คำนวณ scale จากขนาดเป้าหมาย เพื่อไม่ให้ล้นจอ
        local vp = GUI.AbsoluteSize
        local target = (vp.X < 100 or vp.Y < 100) and 1 or math.clamp(math.min(vp.X / (w + 40), vp.Y / (h + 80)), 0.45, 1)
        tw(HolderScale, 0.45, { Scale = target }, Enum.EasingStyle.Quint)
        tw(Holder, 0.45, { Position = UDim2.fromScale(0.5, 0.5) }, Enum.EasingStyle.Quint)
    end)

    -- ปุ่มลัดซ่อน/แสดง UI
    bind(UserInputService.InputBegan, function(input, gp)
        if gp or keybindListening then return end
        if self.ToggleKey and input.KeyCode == self.ToggleKey then self:Toggle() end
    end)

    -- Dynamic Island
    local ISL_W, ISL_H = 160, 38
    local Island = mk("TextButton", {
        Name = "DynamicIsland", Size = UDim2.fromOffset(ISL_W, ISL_H), AnchorPoint = Vector2.new(0.5, 0),
        Position = UDim2.new(0.5, 0, 0, 12), BackgroundColor3 = Color3.new(0, 0, 0), BorderSizePixel = 0,
        AutoButtonColor = false, Text = "", ClipsDescendants = true, Visible = false, ZIndex = 20,
    }, GUI)
    corner(Island, ISL_H / 2); stroke(Island, C.Accent, 0.55, 1)
    local islLogo = makeLogo(Island, 24, 7, 14, 21)
    islLogo.Position = UDim2.fromOffset(8, 7)
    label(Island, { Size = UDim2.new(1, -66, 1, 0), Position = UDim2.fromOffset(40, 0), Text = self.Title, Font = FONT_B, TextSize = 12, TextTruncate = Enum.TextTruncate.AtEnd, TextColor3 = C.White, ZIndex = 21 })
    local islDot = mk("Frame", { Size = UDim2.fromOffset(8, 8), AnchorPoint = Vector2.new(1, 0.5), Position = UDim2.new(1, -14, 0.5, 0), BackgroundColor3 = C.Green, BorderSizePixel = 0, ZIndex = 21 }, Island)
    corner(islDot, 4)
    local islScale = press(Island, nil, false)
    hover(Island, function() tw(Island, 0.25, { Size = UDim2.fromOffset(ISL_W + 14, ISL_H) }) end,
                  function() if Island.Visible and self.Minimized then tw(Island, 0.25, { Size = UDim2.fromOffset(ISL_W, ISL_H) }) end end)
    bind(Island.Activated, function() self:Restore() end)
    self.Island, self._islW, self._islH, self._islScale = Island, ISL_W, ISL_H, islScale

    return self
end

-- ============================================================
-- WINDOW METHODS
-- ============================================================
function Window:NewTab(name, icon)
    name = tostring(name or "Tab")
    local order = #self.Tabs + 1
    local btn = mk("TextButton", { Size = UDim2.new(1, 0, 0, 36), BackgroundColor3 = C.White, BackgroundTransparency = 1, BorderSizePixel = 0, AutoButtonColor = false, Text = "", LayoutOrder = order, ZIndex = 2 }, self.NavList)
    corner(btn, 10)
    local grad = mk("UIGradient", { Color = ColorSequence.new(C.Accent, C.Accent2), Transparency = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0), NumberSequenceKeypoint.new(1, 0.7) }) }, btn)
    local bst = stroke(btn, C.AccentText, 1, 1)
    local bar = mk("Frame", { Size = UDim2.fromOffset(3, 18), Position = UDim2.new(0, 2, 0.5, -9), BackgroundColor3 = C.AccentText, BackgroundTransparency = 1, BorderSizePixel = 0, ZIndex = 3 }, btn)
    corner(bar, 2)

    local textX = 14
    local iconImg
    local iconId = fixId(icon)
    if iconId ~= "" then
        iconImg = mk("ImageLabel", { Size = UDim2.fromOffset(18, 18), Position = UDim2.new(0, 14, 0.5, -9), BackgroundTransparency = 1, Image = iconId, ImageColor3 = C.Dim, ScaleType = Enum.ScaleType.Fit, ZIndex = 3 }, btn)
        textX = 40
    end
    local lbl = label(btn, { Size = UDim2.new(1, -(textX + 8), 1, 0), Position = UDim2.fromOffset(textX, 0), Text = name, TextSize = 14, TextColor3 = C.Dim, TextTruncate = Enum.TextTruncate.AtEnd, ZIndex = 3 })
    press(btn, nil, true)

    local page = mk("Frame", { Size = UDim2.fromScale(1, 1), BackgroundTransparency = 1, Visible = false, ZIndex = 2 }, self.PageHolder)
    local sf = mk("ScrollingFrame", { Size = UDim2.fromScale(1, 1), BackgroundTransparency = 1, BorderSizePixel = 0, ScrollBarThickness = 3, ScrollBarImageColor3 = C.ScrollBar, CanvasSize = UDim2.new(), AutomaticCanvasSize = Enum.AutomaticSize.Y, ScrollingDirection = Enum.ScrollingDirection.Y, ZIndex = 2 }, page)
    padding(sf, 16, 16, 14, 14)
    mk("UIListLayout", { Padding = UDim.new(0, 12), SortOrder = Enum.SortOrder.LayoutOrder }, sf)

    local tab = { Name = name, Page = page, Scroll = sf, Button = btn, Stroke = bst, Bar = bar, Label = lbl, Icon = iconImg, Gradient = grad, Window = self, _secCount = 0 }
    setmetatable(tab, Tab)
    table.insert(self.Tabs, tab)

    hover(btn, function()
        if self.CurrentTab ~= tab then tw(btn, 0.2, { BackgroundTransparency = 0.93 }); tw(lbl, 0.2, { TextColor3 = C.Text }) end
    end, function()
        if self.CurrentTab ~= tab then tw(btn, 0.2, { BackgroundTransparency = 1 }); tw(lbl, 0.2, { TextColor3 = C.Dim }) end
    end)
    bind(btn.Activated, function() playSound("click"); self:SelectTab(tab) end)
    if #self.Tabs == 1 then self:SelectTab(tab) end
    return tab
end

function Window:SelectTab(tab)
    if self.CurrentTab == tab then return end
    self.CurrentTab = tab
    for _, t in ipairs(self.Tabs) do
        local on = (t == tab)
        tw(t.Button, 0.25, { BackgroundTransparency = on and 0.72 or 1 })
        tw(t.Stroke, 0.25, { Transparency = on and 0.6 or 1 })
        tw(t.Bar, 0.25, { BackgroundTransparency = on and 0 or 1 })
        tw(t.Label, 0.25, { TextColor3 = on and C.White or C.Dim })
        t.Label.Font = on and FONT_B or FONT
        if t.Icon then tw(t.Icon, 0.25, { ImageColor3 = on and C.White or C.Dim }) end
        if on then
            t.Page.Visible = true
            t.Page.Position = UDim2.fromOffset(0, 14)
            tw(t.Page, 0.35, { Position = UDim2.fromOffset(0, 0) })
        else
            t.Page.Visible = false
        end
    end
    self.Crumb.Text = escapeRich(self.Title) .. '  <font color="#E4101E">›</font>  <font color="#FFFFFF"><b>' .. escapeRich(tab.Name) .. "</b></font>"
end

local STATUS_COLORS = { ok = C.Green, info = C.AccentText, warn = C.Yellow, err = C.Red }
function Window:SetStatus(text, kind)
    if not self._alive then return end
    self.StatusLabel.Text = tostring(text)
    local col = STATUS_COLORS[kind or "ok"] or C.Green
    tw(self.StatusDot, 0.25, { BackgroundColor3 = col })
    self.StatusDotStroke.Color = col
end
function Window:SetCounter(n) if self._alive then self.CounterLabel.Text = "รอบ: " .. tostring(n) end end
function Window:SetToggleKey(key) self.ToggleKey = key end
function Window:Notify(title, text, kind, dur) notify(title, text, kind, dur) end

function Window:Minimize()
    if self.Minimized or not self._alive then return end
    self.Minimized = true
    tw(self.HolderScale, 0.4, { Scale = 0.05 }, Enum.EasingStyle.Back, Enum.EasingDirection.In)
    tw(self.Main, 0.4, { GroupTransparency = 1 }); tw(self.Glow, 0.3, { GroupTransparency = 1 })
    task.delay(0.4, function() if self._alive and self.Minimized then self.Holder.Visible = false end end)

    local Island = self.Island
    Island.Visible = true; Island.Size = UDim2.fromOffset(0, self._islH)
    tw(Island, 0.5, { Size = UDim2.fromOffset(self._islW, self._islH) }, Enum.EasingStyle.Back)
end

function Window:Restore()
    if not self.Minimized or not self._alive then return end
    self.Minimized = false
    local Island = self.Island
    tw(Island, 0.3, { Size = UDim2.fromOffset(0, self._islH) }, Enum.EasingStyle.Quad, Enum.EasingDirection.In)
    task.delay(0.3, function() if self._alive and not self.Minimized then Island.Visible = false end end)

    self.Holder.Visible = true
    tw(self.Main, 0.4, { GroupTransparency = 0 }); tw(self.Glow, 0.5, { GroupTransparency = 0 })
    tw(self.HolderScale, 0.55, { Scale = self._fitScale() }, Enum.EasingStyle.Back)
end

function Window:Toggle()
    if self.Minimized then self:Restore() else self:Minimize() end
end

function Window:Destroy(instant)
    if not self._alive then return end
    self._alive = false
    for _, c in ipairs(self._conns) do pcall(function() c:Disconnect() end) end
    table.clear(self._conns)
    if ToastHolder == self._toastHolder then ToastHolder = nil end
    if Library._window == self then Library._window = nil end
    for k, s in pairs(soundCache) do pcall(function() s:Destroy() end); soundCache[k] = nil end

    local gui = self.GUI
    if not gui then return end
    if instant then gui:Destroy(); return end
    tw(self.HolderScale, 0.3, { Scale = self.HolderScale.Scale * 0.9 }, Enum.EasingStyle.Quad, Enum.EasingDirection.In)
    tw(self.Main, 0.3, { GroupTransparency = 1 }); tw(self.Glow, 0.2, { GroupTransparency = 1 })
    if self.Island.Visible then tw(self.Island, 0.25, { Size = UDim2.fromOffset(0, self._islH) }) end
    task.delay(0.32, function() if gui then gui:Destroy() end end)
end

-- ============================================================
-- TAB METHODS
-- ============================================================
function Tab:NewSection(name)
    self._secCount += 1
    local sec = mk("Frame", { Size = UDim2.new(1, 0, 0, 0), AutomaticSize = Enum.AutomaticSize.Y, BackgroundColor3 = C.Card, BackgroundTransparency = T.Card, BorderSizePixel = 0, LayoutOrder = self._secCount, ClipsDescendants = true, ZIndex = 2 }, self.Scroll)
    corner(sec, 12); stroke(sec, C.White, T.Stroke - 0.02, 1)
    mk("UIListLayout", { SortOrder = Enum.SortOrder.LayoutOrder }, sec)

    -- Header (เดิม label ถูก UIListLayout จับชิดซ้ายจนไม่มีระยะห่าง)
    local header = mk("Frame", { Size = UDim2.new(1, 0, 0, 36), BackgroundTransparency = 1, LayoutOrder = 0, ZIndex = 2 }, sec)
    local accent = mk("Frame", { Size = UDim2.fromOffset(3, 14), Position = UDim2.new(0, 14, 0.5, -7), BackgroundColor3 = C.White, BorderSizePixel = 0, ZIndex = 2 }, header)
    corner(accent, 2); redGradient(accent, 90)
    local title = label(header, { Size = UDim2.new(1, -40, 1, 0), Position = UDim2.fromOffset(25, 0), Text = tostring(name or ""), Font = FONT_B, TextSize = 14, TextTruncate = Enum.TextTruncate.AtEnd, ZIndex = 2 })
    line(header, { Position = UDim2.new(0, 0, 1, -1), ZIndex = 2 })

    local section = { Name = name, Frame = sec, Title = title, Tab = self, _rowCount = 0 }
    setmetatable(section, Section)
    return section
end

function Tab:Select() self.Window:SelectTab(self) end

-- ============================================================
-- SECTION COMPONENTS
-- ============================================================
-- สร้างแถว + ชื่อ + คำอธิบาย  (rightW = พื้นที่ด้านขวาสำหรับปุ่ม/ตัวควบคุม)
function Section:_row(text, info, rightW, minH, topAlign)
    self._rowCount += 1
    local hasInfo = hasText(info)
    local h = math.max(hasInfo and 56 or 44, minH or 0)
    local r = mk("Frame", { Size = UDim2.new(1, 0, 0, h), BackgroundTransparency = 1, LayoutOrder = self._rowCount, ZIndex = 2 }, self.Frame)
    if self._rowCount > 1 then line(r, { Size = UDim2.new(1, -28, 0, 1), Position = UDim2.fromOffset(14, 0), ZIndex = 2 }) end

    local titleY
    if topAlign then titleY = 9 elseif hasInfo then titleY = 9 else titleY = (h - 20) / 2 end
    local title = label(r, { Size = UDim2.new(1, -(rightW + 28), 0, 20), Position = UDim2.fromOffset(14, titleY), Text = tostring(text or ""), Font = FONT_B, TextSize = 14, TextTruncate = Enum.TextTruncate.AtEnd, ZIndex = 2 })
    local desc
    if hasInfo then
        desc = label(r, { Size = UDim2.new(1, -(rightW + 28), 0, 16), Position = UDim2.fromOffset(14, titleY + 20), Text = info, TextSize = 12, TextColor3 = C.Dim, TextTruncate = Enum.TextTruncate.AtEnd, ZIndex = 2 })
    end

    -- ไฮไลต์แถวตอนเอาเมาส์ชี้
    local hl = mk("Frame", { Size = UDim2.new(1, -12, 1, -6), Position = UDim2.fromOffset(6, 3), BackgroundColor3 = C.White, BackgroundTransparency = 1, BorderSizePixel = 0, ZIndex = 1 }, r)
    corner(hl, 8)
    hover(r, function() tw(hl, 0.2, { BackgroundTransparency = 0.97 }) end, function() tw(hl, 0.2, { BackgroundTransparency = 1 }) end)

    return r, title, desc, h
end

function Section:UpdateSection(newName) self.Title.Text = tostring(newName) end

-- ---------------- Label ----------------
function Section:NewLabel(text)
    self._rowCount += 1
    local r = mk("Frame", { Size = UDim2.new(1, 0, 0, 0), AutomaticSize = Enum.AutomaticSize.Y, BackgroundTransparency = 1, LayoutOrder = self._rowCount, ZIndex = 2 }, self.Frame)
    if self._rowCount > 1 then line(r, { Size = UDim2.new(1, -28, 0, 1), Position = UDim2.fromOffset(14, 0), ZIndex = 2 }) end
    local lbl = label(r, { Size = UDim2.new(1, -28, 0, 0), AutomaticSize = Enum.AutomaticSize.Y, Position = UDim2.fromOffset(14, 10), Text = tostring(text or ""), TextSize = 13, TextColor3 = C.Dim, TextWrapped = true, ZIndex = 2 })
    padding(r, 0, 0, 0, 10)
    local obj = {}
    function obj:UpdateLabel(t) lbl.Text = tostring(t) end
    obj.Set = obj.UpdateLabel
    return obj
end

-- ---------------- Button ----------------
function Section:NewButton(text, info, callback)
    if type(info) == "function" then callback = info; info = nil end
    local r, title, _, h = self:_row(text, info, 100)

    local btn = mk("TextButton", { Size = UDim2.fromOffset(84, 28), AnchorPoint = Vector2.new(1, 0.5), Position = UDim2.new(1, -14, 0, h / 2), BackgroundColor3 = C.Accent, BackgroundTransparency = 0.88, BorderSizePixel = 0, AutoButtonColor = false, Text = "", ZIndex = 3 }, r)
    corner(btn, 8)
    local bst = stroke(btn, C.AccentText, 0.5, 1)
    -- พื้นไล่สีแยกเป็น Frame ลูก (UIGradient บนปุ่มตรงๆ จะย้อมสีตัวอักษรไปด้วย)
    local bfill = mk("Frame", { Size = UDim2.fromScale(1, 1), BackgroundColor3 = C.White, BackgroundTransparency = 1, BorderSizePixel = 0, ZIndex = 3 }, btn)
    corner(bfill, 8); redGradient(bfill, 0)
    local btxt = label(btn, { Size = UDim2.fromScale(1, 1), Text = "Execute", TextColor3 = C.AccentText, Font = FONT_B, TextSize = 12, TextXAlignment = Enum.TextXAlignment.Center, ZIndex = 4 })
    press(btn, nil, true)
    hover(btn, function()
        tw(bfill, 0.2, { BackgroundTransparency = 0 }); tw(btxt, 0.2, { TextColor3 = C.White }); tw(bst, 0.2, { Transparency = 0.2 })
    end, function()
        tw(bfill, 0.2, { BackgroundTransparency = 1 }); tw(btxt, 0.2, { TextColor3 = C.AccentText }); tw(bst, 0.2, { Transparency = 0.5 })
    end)

    local busy = false
    local obj = {}
    function obj:UpdateButton(newText) btxt.Text = tostring(newText) end
    function obj:SetTitle(newText) title.Text = tostring(newText) end
    bind(btn.Activated, function()
        if busy then return end   -- กันกดรัวจน callback ซ้อน
        busy = true
        playSound("click")
        safeCall(callback)
        task.delay(0.15, function() busy = false end)
    end)
    return obj
end

-- ---------------- Toggle ----------------
function Section:NewToggle(text, info, initial, callback)
    if type(info) == "function" then callback = info; info = nil; initial = false end
    if type(initial) == "function" then callback = initial; initial = false end
    initial = initial == true
    local r, _, _, h = self:_row(text, info, 60)

    local track = mk("TextButton", { Size = UDim2.fromOffset(44, 24), AnchorPoint = Vector2.new(1, 0.5), Position = UDim2.new(1, -14, 0, h / 2), BackgroundColor3 = C.Off, BackgroundTransparency = initial and 1 or 0.7, BorderSizePixel = 0, AutoButtonColor = false, Text = "", ZIndex = 3 }, r)
    corner(track, 12)
    local tstroke = stroke(track, initial and C.AccentText or C.White, initial and 0.55 or 0.85, 1)
    local fill = mk("Frame", { Size = UDim2.fromScale(1, 1), BackgroundColor3 = C.White, BackgroundTransparency = initial and 0 or 1, BorderSizePixel = 0, ZIndex = 3 }, track)
    corner(fill, 12); redGradient(fill, 20)
    local knob = mk("Frame", { Size = UDim2.fromOffset(20, 20), AnchorPoint = Vector2.new(0, 0.5), Position = initial and UDim2.new(0, 22, 0.5, 0) or UDim2.new(0, 2, 0.5, 0), BackgroundColor3 = initial and C.White or KNOB_OFF, BorderSizePixel = 0, ZIndex = 4 }, track)
    corner(knob, 10)
    press(track, nil, true)

    local value = initial
    local obj = {}
    function obj:Set(v, silent)
        v = v == true
        value = v
        tw(fill, 0.25, { BackgroundTransparency = v and 0 or 1 })
        tw(track, 0.25, { BackgroundTransparency = v and 1 or 0.7 })
        tw(tstroke, 0.25, { Color = v and C.AccentText or C.White, Transparency = v and 0.55 or 0.85 })
        tw(knob, 0.35, { Position = v and UDim2.new(0, 22, 0.5, 0) or UDim2.new(0, 2, 0.5, 0) }, Enum.EasingStyle.Back)
        tw(knob, 0.25, { BackgroundColor3 = v and C.White or KNOB_OFF })
        if not silent then
            playSound(v and "on" or "off")
            safeCall(callback, v)
        end
    end
    function obj:Get() return value end
    obj.UpdateToggle = obj.Set
    bind(track.Activated, function() obj:Set(not value) end)
    return obj
end

-- ---------------- Slider ----------------
function Section:NewSlider(text, info, maxV, minV, callback, default)
    if type(info) == "number" then info, maxV, minV, callback, default = nil, info, maxV, minV, callback end
    maxV, minV = tonumber(maxV) or 100, tonumber(minV) or 0
    if maxV < minV then maxV, minV = minV, maxV end
    local hasInfo = hasText(info)
    local trackY = hasInfo and 52 or 36
    local r = self:_row(text, info, 70, trackY + 20, true)

    local valBox = mk("Frame", { Size = UDim2.fromOffset(52, 20), AnchorPoint = Vector2.new(1, 0), Position = UDim2.new(1, -14, 0, 9), BackgroundColor3 = C.Accent, BackgroundTransparency = 0.82, BorderSizePixel = 0, ZIndex = 3 }, r)
    corner(valBox, 6); stroke(valBox, C.AccentText, 0.7, 1)
    local valLabel = label(valBox, { Size = UDim2.fromScale(1, 1), Text = tostring(minV), TextSize = 12, TextColor3 = C.AccentText, Font = FONT_B, TextXAlignment = Enum.TextXAlignment.Center, ZIndex = 4 })

    local trackBg = mk("Frame", { Size = UDim2.new(1, -28, 0, 6), Position = UDim2.fromOffset(14, trackY), BackgroundColor3 = Color3.fromRGB(50, 44, 46), BackgroundTransparency = 0.4, BorderSizePixel = 0, ZIndex = 3 }, r)
    corner(trackBg, 3)
    local fill = mk("Frame", { Size = UDim2.fromScale(0, 1), BackgroundColor3 = C.White, BorderSizePixel = 0, ZIndex = 3 }, trackBg)
    corner(fill, 3); redGradient(fill, 0)
    local knob = mk("Frame", { Size = UDim2.fromOffset(14, 14), AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0, 0.5), BackgroundColor3 = C.White, BorderSizePixel = 0, ZIndex = 5 }, trackBg)
    corner(knob, 7); stroke(knob, C.Accent, 0.3, 2)
    local knobScale = mk("UIScale", { Scale = 1 }, knob)
    local hitbox = mk("TextButton", { Size = UDim2.new(1, 20, 0, 28), Position = UDim2.new(0, -10, 0.5, -14), BackgroundTransparency = 1, Text = "", ZIndex = 6 }, trackBg)

    local value
    local obj = {}
    function obj:Set(v, silent)
        v = tonumber(v) or minV
        v = math.clamp(math.floor(v + 0.5), minV, maxV)
        local rel = (maxV == minV) and 0 or (v - minV) / (maxV - minV)
        tw(fill, 0.12, { Size = UDim2.fromScale(rel, 1) }, Enum.EasingStyle.Quad)
        tw(knob, 0.12, { Position = UDim2.fromScale(rel, 0.5) }, Enum.EasingStyle.Quad)
        valLabel.Text = tostring(v)
        if v == value then return end   -- ไม่ยิง callback ซ้ำถ้าค่าไม่เปลี่ยน
        value = v
        if not silent then safeCall(callback, v) end
    end
    function obj:Get() return value end
    obj:Set(default or minV, true)

    local dragInput
    local scroll = self.Tab.Scroll
    local function update(x)
        local width = math.max(trackBg.AbsoluteSize.X, 1)
        local rel = math.clamp((x - trackBg.AbsolutePosition.X) / width, 0, 1)
        obj:Set(minV + (maxV - minV) * rel)
    end
    local function stop()
        dragInput = nil
        scroll.ScrollingEnabled = true
        tw(knobScale, 0.2, { Scale = 1 })
    end
    bind(hitbox.InputBegan, function(input)
        if not isPointer(input) then return end
        dragInput = input
        scroll.ScrollingEnabled = false   -- กันหน้าเลื่อนตามตอนลากสไลเดอร์บนมือถือ
        tw(knobScale, 0.2, { Scale = 1.25 }, Enum.EasingStyle.Back)
        update(input.Position.X)
    end)
    bind(UserInputService.InputChanged, function(input)
        if not dragInput or not isMove(input) then return end
        if dragInput.UserInputType == Enum.UserInputType.Touch and input ~= dragInput then return end
        update(input.Position.X)
    end)
    bind(UserInputService.InputEnded, function(input)
        if not dragInput then return end
        if input == dragInput or input.UserInputType == Enum.UserInputType.MouseButton1 then stop() end
    end)
    return obj
end

-- ---------------- Dropdown ----------------
function Section:NewDropdown(text, info, list, callback, default)
    if type(info) == "table" then info, list, callback, default = nil, info, list, callback end
    list = type(list) == "table" and list or {}
    local r, _, _, h = self:_row(text, info, 170)
    r.ClipsDescendants = true
    local CLOSED_H = h
    local OPT_H, OPT_GAP = 28, 4

    local box = mk("TextButton", { Size = UDim2.fromOffset(150, 28), AnchorPoint = Vector2.new(1, 0.5), Position = UDim2.new(1, -14, 0, h / 2), BackgroundColor3 = C.Input, BackgroundTransparency = 0.3, BorderSizePixel = 0, AutoButtonColor = false, Text = "", ZIndex = 3 }, r)
    corner(box, 8)
    local boxStroke = stroke(box, C.White, 0.85, 1)
    local boxText = label(box, { Size = UDim2.new(1, -34, 1, 0), Position = UDim2.fromOffset(10, 0), Text = "เลือก...", TextSize = 12, TextColor3 = C.Dim, TextTruncate = Enum.TextTruncate.AtEnd, ZIndex = 4 })
    local arrow = label(box, { Size = UDim2.fromOffset(20, 28), AnchorPoint = Vector2.new(1, 0), Position = UDim2.new(1, -6, 0, 0), Text = "▾", Font = FONT_B, TextSize = 14, TextColor3 = C.AccentText, TextXAlignment = Enum.TextXAlignment.Center, ZIndex = 4 })
    press(box, nil, false)

    local listFrame = mk("Frame", { Size = UDim2.new(1, -28, 0, 0), Position = UDim2.fromOffset(14, CLOSED_H), AutomaticSize = Enum.AutomaticSize.Y, BackgroundTransparency = 1, ZIndex = 3 }, r)
    mk("UIListLayout", { Padding = UDim.new(0, OPT_GAP), SortOrder = Enum.SortOrder.LayoutOrder }, listFrame)

    local open, selected = false, nil
    local optButtons = {}
    local obj = {}

    local function openHeight()
        local n = #list
        if n == 0 then return CLOSED_H end
        return CLOSED_H + n * OPT_H + (n - 1) * OPT_GAP + 10
    end
    local function setOpen(v)
        open = v
        tw(r, 0.3, { Size = UDim2.new(1, 0, 0, v and openHeight() or CLOSED_H) })
        tw(arrow, 0.3, { Rotation = v and 180 or 0 })
        tw(boxStroke, 0.2, { Color = v and C.AccentText or C.White, Transparency = v and 0.5 or 0.85 })
    end
    local function paint()
        for v, b in pairs(optButtons) do
            local on = (v == selected)
            tw(b, 0.2, { BackgroundTransparency = on and 0.75 or 0.94, TextColor3 = on and C.White or C.Dim })
        end
    end
    local function build()
        for _, b in pairs(optButtons) do b:Destroy() end
        table.clear(optButtons)
        for i, v in ipairs(list) do
            local key = tostring(v)
            local b = mk("TextButton", { Size = UDim2.new(1, 0, 0, OPT_H), BackgroundColor3 = C.Accent, BackgroundTransparency = 0.94, BorderSizePixel = 0, AutoButtonColor = false, Text = key, TextColor3 = C.Dim, Font = FONT, TextSize = 12, TextXAlignment = Enum.TextXAlignment.Left, TextTruncate = Enum.TextTruncate.AtEnd, LayoutOrder = i, ZIndex = 4 }, listFrame)
            corner(b, 7); padding(b, 12, 8, 0, 0)
            hover(b, function() if selected ~= key then tw(b, 0.15, { BackgroundTransparency = 0.86, TextColor3 = C.Text }) end end,
                     function() if selected ~= key then tw(b, 0.15, { BackgroundTransparency = 0.94, TextColor3 = C.Dim }) end end)
            bind(b.Activated, function()
                playSound("click")
                obj:Set(v)
                setOpen(false)
            end)
            optButtons[key] = b
        end
        paint()
    end

    function obj:Set(v, silent)
        selected = v ~= nil and tostring(v) or nil
        boxText.Text = selected or "เลือก..."
        boxText.TextColor3 = selected and C.Text or C.Dim
        paint()
        if not silent and v ~= nil then safeCall(callback, v) end
    end
    function obj:Get() return selected end
    function obj:Refresh(newList, keepSelection)
        list = type(newList) == "table" and newList or {}
        if not keepSelection then obj:Set(nil, true) end
        build()
        if open then setOpen(true) end
    end
    obj.Update = obj.Refresh

    build()
    if default ~= nil then obj:Set(default, true) end
    bind(box.Activated, function() setOpen(not open) end)
    return obj
end

-- ---------------- TextBox ----------------
function Section:NewTextBox(text, info, callback, placeholder)
    if type(info) == "function" then callback, placeholder, info = info, callback, nil end
    local r, _, _, h = self:_row(text, info, 170)
    local holder = mk("Frame", { Size = UDim2.fromOffset(150, 28), AnchorPoint = Vector2.new(1, 0.5), Position = UDim2.new(1, -14, 0, h / 2), BackgroundColor3 = C.Input, BackgroundTransparency = 0.3, BorderSizePixel = 0, ZIndex = 3 }, r)
    corner(holder, 8)
    local st = stroke(holder, C.White, 0.85, 1)
    local box = mk("TextBox", { Size = UDim2.new(1, -20, 1, 0), Position = UDim2.fromOffset(10, 0), BackgroundTransparency = 1, Text = "", PlaceholderText = placeholder or "พิมพ์ที่นี่...", PlaceholderColor3 = C.Faint, TextColor3 = C.Text, Font = FONT, TextSize = 12, TextXAlignment = Enum.TextXAlignment.Left, ClearTextOnFocus = false, TextTruncate = Enum.TextTruncate.AtEnd, ZIndex = 4 }, holder)

    bind(box.Focused, function() tw(st, 0.2, { Color = C.AccentText, Transparency = 0.4 }) end)
    bind(box.FocusLost, function(enter)
        tw(st, 0.2, { Color = C.White, Transparency = 0.85 })
        safeCall(callback, box.Text, enter)
    end)
    local obj = {}
    function obj:Set(t) box.Text = tostring(t or "") end
    function obj:Get() return box.Text end
    return obj
end

-- ---------------- Keybind ----------------
function Section:NewKeybind(text, info, key, callback)
    if typeof(info) == "EnumItem" then info, key, callback = nil, info, key end
    if type(key) == "string" then key = Enum.KeyCode[key] end
    key = key or Enum.KeyCode.Unknown
    local r, _, _, h = self:_row(text, info, 110)
    local btn = mk("TextButton", { Size = UDim2.fromOffset(0, 26), AutomaticSize = Enum.AutomaticSize.X, AnchorPoint = Vector2.new(1, 0.5), Position = UDim2.new(1, -14, 0, h / 2), BackgroundColor3 = C.Input, BackgroundTransparency = 0.3, BorderSizePixel = 0, AutoButtonColor = false, Text = "", TextColor3 = C.AccentText, Font = FONT_B, TextSize = 12, ZIndex = 3 }, r)
    corner(btn, 7); padding(btn, 12, 12, 0, 0)
    mk("UISizeConstraint", { MinSize = Vector2.new(56, 26) }, btn)
    local st = stroke(btn, C.AccentText, 0.6, 1)
    press(btn, nil, false)

    local listening = false
    local function render() btn.Text = listening and "..." or (key == Enum.KeyCode.Unknown and "None" or key.Name) end
    render()

    local obj = {}
    function obj:Set(k) if type(k) == "string" then k = Enum.KeyCode[k] end; key = k or Enum.KeyCode.Unknown; render() end
    function obj:Get() return key end

    bind(btn.Activated, function()
        listening = true; keybindListening = true; render()
        tw(st, 0.2, { Transparency = 0.1 })
    end)
    bind(UserInputService.InputBegan, function(input, gp)
        if listening then
            if input.UserInputType ~= Enum.UserInputType.Keyboard then return end
            if input.KeyCode == Enum.KeyCode.Escape then key = Enum.KeyCode.Unknown
            elseif input.KeyCode ~= Enum.KeyCode.Backspace then key = input.KeyCode end
            listening = false
            task.defer(function() keybindListening = false end)
            tw(st, 0.2, { Transparency = 0.6 })
            render()
            return
        end
        if gp or key == Enum.KeyCode.Unknown then return end
        if input.KeyCode == key then safeCall(callback, key) end
    end)
    return obj
end

-- shortcut
function Library:Notify(title, text, kind, dur) notify(title, text, kind, dur) end

return Library
