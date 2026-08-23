--[[
    Nexzan Hub Key-Protected Loader
    --------------------------------
    Fungsi:
    - Menambahkan UI Key System dengan 2 tab: Keys dan Get Keys
    - Get Keys mengambil key berdasarkan HWID perangkat langsung dari backend
    - Keys tab untuk input + verifikasi key
    - Jika key masih terikat ke perangkat lain, tombol Reset HWID akan menyalin link portal reset
    - Setelah verifikasi berhasil, script utama / UI utama akan dimuat

    Cara pakai:
    local WindUI = loadstring(game:HttpGet("https://github.com/Footagesus/WindUI/releases/latest/download/main.lua"))()
    loadstring(game:HttpGet("URL_KE_FILE_INI"))()(WindUI)

    Penting:
    - Ganti CONFIG.API_BASE dengan domain Netlify Anda
    - Ganti CONFIG.ORIGINAL_SCRIPT_URL jika script utama Anda bukan URL default di bawah
]]

local CONFIG = {
    API_BASE = "https://nexzanhubresethwid.netlify.app/",
    ORIGINAL_SCRIPT_URL = "https://raw.githubusercontent.com/NexzanHub/Nexzan-Hub/refs/heads/main/AllScript.lua",
    RESET_PORTAL_URL = nil, -- kalau nil, otomatis pakai API_BASE .. "/?tab=reset"
    SCRIPT_NAME = "Nexzan Hub",
    HWID_LEASE_HOURS = 24,
}

local HttpService = game:GetService("HttpService")
local Players = game:GetService("Players")
local StarterGui = game:GetService("StarterGui")
local TweenService = game:GetService("TweenService")
local CoreGui = game:GetService("CoreGui")
local LocalPlayer = Players.LocalPlayer

local function getGuiParent()
    local ok, gui = pcall(function()
        return gethui and gethui() or CoreGui
    end)
    return ok and gui or CoreGui
end

local function notify(title, text, duration)
    pcall(function()
        StarterGui:SetCore("SendNotification", {
            Title = title,
            Text = text,
            Duration = duration or 5,
        })
    end)
end

local function copyToClipboard(text)
    local fn = setclipboard or toclipboard or (syn and syn.write_clipboard)
    if type(fn) == "function" then
        pcall(fn, tostring(text))
        return true
    end
    return false
end

local globalEnv = (getgenv and getgenv()) or _G
local globalRequest = rawget(globalEnv, "request")

local function performRequest(payload)
    local candidates = {
        rawget(globalEnv, "http_request"),
        globalRequest,
        (syn and syn.request),
        (http and http.request),
        (fluxus and fluxus.request),
    }

    for _, fn in ipairs(candidates) do
        if type(fn) == "function" then
            local ok, response = pcall(fn, payload)
            if ok and response then
                return response
            end
        end
    end

    error("Executor Anda tidak mendukung HTTP request function.")
end

local function decodeBody(raw)
    if type(raw) ~= "string" or raw == "" then
        return nil
    end

    local ok, data = pcall(function()
        return HttpService:JSONDecode(raw)
    end)
    return ok and data or nil
end

local function apiGet(path, params)
    local query = {}
    for key, value in pairs(params or {}) do
        table.insert(query, HttpService:UrlEncode(key) .. "=" .. HttpService:UrlEncode(tostring(value)))
    end

    local url = CONFIG.API_BASE .. path
    if #query > 0 then
        url = url .. "?" .. table.concat(query, "&")
    end

    local response = performRequest({
        Url = url,
        Method = "GET",
        Headers = {
            ["Accept"] = "application/json",
        },
    })

    local body = response.Body or response.body or ""
    local statusCode = response.StatusCode or response.Status or response.status or 0
    return statusCode, decodeBody(body), body
end

local function getHWID()
    local getters = {
        gethwid,
        get_hwid,
        hwid,
        (syn and syn.get_hwid),
    }

    for _, fn in ipairs(getters) do
        if type(fn) == "function" then
            local ok, value = pcall(fn)
            if ok and value and tostring(value) ~= "" then
                return tostring(value)
            end
        end
    end

    local okClient, clientId = pcall(function()
        return game:GetService("RbxAnalyticsService"):GetClientId()
    end)
    if okClient and clientId and clientId ~= "" then
        return tostring(clientId)
    end

    local userId = LocalPlayer and LocalPlayer.UserId or 0
    return ("FALLBACK-%s-%s"):format(userId, game.PlaceId)
end

local function mask(value)
    value = tostring(value or "")
    if #value <= 16 then
        return value
    end
    return value:sub(1, 8) .. "..." .. value:sub(-6)
end

local function createCorner(parent, radius)
    local c = Instance.new("UICorner")
    c.CornerRadius = UDim.new(0, radius)
    c.Parent = parent
    return c
end

local function createStroke(parent, color, transparency)
    local s = Instance.new("UIStroke")
    s.Color = color
    s.Transparency = transparency or 0
    s.Thickness = 1
    s.Parent = parent
    return s
end

local function createLabel(parent, props)
    local label = Instance.new("TextLabel")
    label.BackgroundTransparency = 1
    label.BorderSizePixel = 0
    label.Font = props.Font or Enum.Font.Gotham
    label.Text = props.Text or ""
    label.TextColor3 = props.TextColor3 or Color3.fromRGB(245, 240, 255)
    label.TextSize = props.TextSize or 14
    label.TextWrapped = props.TextWrapped ~= false
    label.TextXAlignment = props.TextXAlignment or Enum.TextXAlignment.Left
    label.TextYAlignment = props.TextYAlignment or Enum.TextYAlignment.Top
    label.Size = props.Size or UDim2.new(1, 0, 0, 20)
    label.Position = props.Position or UDim2.new(0, 0, 0, 0)
    label.Parent = parent
    return label
end

local function createButton(parent, text, pos, size)
    local btn = Instance.new("TextButton")
    btn.AutoButtonColor = false
    btn.Text = text
    btn.Font = Enum.Font.GothamBold
    btn.TextSize = 14
    btn.TextColor3 = Color3.fromRGB(255, 255, 255)
    btn.BackgroundColor3 = Color3.fromRGB(120, 73, 255)
    btn.Position = pos
    btn.Size = size
    btn.Parent = parent
    createCorner(btn, 12)
    createStroke(btn, Color3.fromRGB(168, 133, 255), 0.42)

    btn.MouseEnter:Connect(function()
        TweenService:Create(btn, TweenInfo.new(0.15), {
            BackgroundColor3 = Color3.fromRGB(141, 93, 255),
        }):Play()
    end)

    btn.MouseLeave:Connect(function()
        TweenService:Create(btn, TweenInfo.new(0.15), {
            BackgroundColor3 = Color3.fromRGB(120, 73, 255),
        }):Play()
    end)

    return btn
end

local function createSecondaryButton(parent, text, pos, size)
    local btn = Instance.new("TextButton")
    btn.AutoButtonColor = false
    btn.Text = text
    btn.Font = Enum.Font.GothamBold
    btn.TextSize = 14
    btn.TextColor3 = Color3.fromRGB(234, 228, 255)
    btn.BackgroundColor3 = Color3.fromRGB(33, 25, 53)
    btn.Position = pos
    btn.Size = size
    btn.Parent = parent
    createCorner(btn, 12)
    createStroke(btn, Color3.fromRGB(142, 124, 196), 0.55)

    btn.MouseEnter:Connect(function()
        TweenService:Create(btn, TweenInfo.new(0.15), {
            BackgroundColor3 = Color3.fromRGB(44, 34, 71),
        }):Play()
    end)

    btn.MouseLeave:Connect(function()
        TweenService:Create(btn, TweenInfo.new(0.15), {
            BackgroundColor3 = Color3.fromRGB(33, 25, 53),
        }):Play()
    end)

    return btn
end

local function createInput(parent, placeholder, pos, size)
    local box = Instance.new("TextBox")
    box.ClearTextOnFocus = false
    box.PlaceholderText = placeholder
    box.Text = ""
    box.Font = Enum.Font.Gotham
    box.TextSize = 14
    box.TextColor3 = Color3.fromRGB(245, 240, 255)
    box.PlaceholderColor3 = Color3.fromRGB(160, 149, 192)
    box.BackgroundColor3 = Color3.fromRGB(18, 13, 31)
    box.Position = pos
    box.Size = size
    box.TextXAlignment = Enum.TextXAlignment.Left
    box.Parent = parent
    createCorner(box, 12)
    createStroke(box, Color3.fromRGB(120, 100, 176), 0.45)

    local padding = Instance.new("UIPadding")
    padding.PaddingLeft = UDim.new(0, 12)
    padding.PaddingRight = UDim.new(0, 12)
    padding.Parent = box

    return box
end

local function makeDraggable(frame, dragTarget)
    dragTarget = dragTarget or frame
    local dragging = false
    local dragStart, startPos

    dragTarget.InputBegan:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.MouseButton1 then
            dragging = true
            dragStart = input.Position
            startPos = frame.Position

            input.Changed:Connect(function()
                if input.UserInputState == Enum.UserInputState.End then
                    dragging = false
                end
            end)
        end
    end)

    dragTarget.InputChanged:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.MouseMovement and dragging then
            local delta = input.Position - dragStart
            frame.Position = UDim2.new(
                startPos.X.Scale,
                startPos.X.Offset + delta.X,
                startPos.Y.Scale,
                startPos.Y.Offset + delta.Y
            )
        end
    end)
end

local function buildKeyGate()
    local state = {
        verified = false,
        cancelled = false,
        key = "",
        hwid = getHWID(),
        resetUrl = CONFIG.RESET_PORTAL_URL or (CONFIG.API_BASE .. "/?tab=reset"),
    }

    local screenGui = Instance.new("ScreenGui")
    screenGui.Name = "NexzanHubKeySystem"
    screenGui.IgnoreGuiInset = true
    screenGui.ResetOnSpawn = false
    screenGui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
    screenGui.Parent = getGuiParent()

    local overlay = Instance.new("Frame")
    overlay.BackgroundColor3 = Color3.fromRGB(7, 6, 13)
    overlay.BackgroundTransparency = 0.22
    overlay.Size = UDim2.fromScale(1, 1)
    overlay.Parent = screenGui

    local shadow = Instance.new("ImageLabel")
    shadow.BackgroundTransparency = 1
    shadow.Image = "rbxassetid://1316045217"
    shadow.ImageColor3 = Color3.fromRGB(35, 19, 68)
    shadow.ImageTransparency = 0.45
    shadow.ScaleType = Enum.ScaleType.Slice
    shadow.SliceCenter = Rect.new(10, 10, 118, 118)
    shadow.Size = UDim2.new(0, 640, 0, 430)
    shadow.AnchorPoint = Vector2.new(0.5, 0.5)
    shadow.Position = UDim2.fromScale(0.5, 0.5)
    shadow.Parent = overlay

    local main = Instance.new("Frame")
    main.Size = UDim2.new(0, 610, 0, 390)
    main.AnchorPoint = Vector2.new(0.5, 0.5)
    main.Position = UDim2.fromScale(0.5, 0.5)
    main.BackgroundColor3 = Color3.fromRGB(12, 10, 20)
    main.Parent = overlay
    createCorner(main, 18)
    createStroke(main, Color3.fromRGB(149, 124, 222), 0.4)

    local gradient = Instance.new("UIGradient")
    gradient.Color = ColorSequence.new({
        ColorSequenceKeypoint.new(0, Color3.fromRGB(20, 14, 34)),
        ColorSequenceKeypoint.new(1, Color3.fromRGB(11, 9, 19)),
    })
    gradient.Rotation = 90
    gradient.Parent = main

    local topBar = Instance.new("Frame")
    topBar.BackgroundTransparency = 1
    topBar.Size = UDim2.new(1, 0, 0, 64)
    topBar.Parent = main

    createLabel(topBar, {
        Position = UDim2.new(0, 22, 0, 14),
        Size = UDim2.new(1, -44, 0, 24),
        Text = CONFIG.SCRIPT_NAME .. " • Key System",
        TextSize = 22,
        Font = Enum.Font.GothamBold,
    })

    createLabel(topBar, {
        Position = UDim2.new(0, 22, 0, 38),
        Size = UDim2.new(1, -44, 0, 18),
        Text = "2 tab: Keys & Get Keys • HWID binding 24 jam • Reset portal support",
        TextSize = 12,
        TextColor3 = Color3.fromRGB(184, 173, 215),
    })

    local closeBtn = createSecondaryButton(topBar, "✕", UDim2.new(1, -50, 0, 14), UDim2.new(0, 30, 0, 30))
    closeBtn.MouseButton1Click:Connect(function()
        state.cancelled = true
        notify(CONFIG.SCRIPT_NAME, "Key system ditutup. Script utama belum dibuka.", 5)
        screenGui:Destroy()
    end)

    local tabHolder = Instance.new("Frame")
    tabHolder.BackgroundTransparency = 1
    tabHolder.Position = UDim2.new(0, 20, 0, 74)
    tabHolder.Size = UDim2.new(0, 220, 0, 44)
    tabHolder.Parent = main

    local tabKeys = createButton(tabHolder, "Keys", UDim2.new(0, 0, 0, 0), UDim2.new(0, 104, 0, 40))
    local tabGetKeys = createSecondaryButton(tabHolder, "Get Keys", UDim2.new(0, 116, 0, 0), UDim2.new(0, 104, 0, 40))

    local body = Instance.new("Frame")
    body.BackgroundTransparency = 1
    body.Position = UDim2.new(0, 20, 0, 126)
    body.Size = UDim2.new(1, -40, 1, -146)
    body.Parent = main

    local keysPage = Instance.new("Frame")
    keysPage.BackgroundTransparency = 1
    keysPage.Size = UDim2.fromScale(1, 1)
    keysPage.Parent = body

    local getKeysPage = Instance.new("Frame")
    getKeysPage.BackgroundTransparency = 1
    getKeysPage.Size = UDim2.fromScale(1, 1)
    getKeysPage.Visible = false
    getKeysPage.Parent = body

    createLabel(keysPage, {
        Position = UDim2.new(0, 0, 0, 0),
        Size = UDim2.new(1, 0, 0, 20),
        Text = "Masukkan key lalu verifikasi. Setelah berhasil, UI utama/script utama akan dibuka.",
        TextColor3 = Color3.fromRGB(195, 185, 225),
        TextSize = 13,
    })

    local keyBox = createInput(keysPage, "Masukkan key Anda di sini", UDim2.new(0, 0, 0, 32), UDim2.new(1, 0, 0, 42))

    local statusText = createLabel(keysPage, {
        Position = UDim2.new(0, 0, 0, 82),
        Size = UDim2.new(1, 0, 0, 48),
        Text = "Status: menunggu input key.",
        TextWrapped = true,
        TextColor3 = Color3.fromRGB(184, 173, 215),
        TextSize = 13,
    })

    local verifyBtn = createButton(keysPage, "Verify Key", UDim2.new(0, 0, 0, 140), UDim2.new(0, 170, 0, 42))
    local resetBtn = createSecondaryButton(keysPage, "Copy Reset HWID Link", UDim2.new(0, 182, 0, 140), UDim2.new(0, 190, 0, 42))

    createLabel(keysPage, {
        Position = UDim2.new(0, 0, 0, 198),
        Size = UDim2.new(1, 0, 0, 56),
        Text = "Kalau key masih terikat ke perangkat lain, backend akan mengirim notifikasi reset. Tombol di atas akan menyalin link website reset HWID ke clipboard.",
        TextWrapped = true,
        TextColor3 = Color3.fromRGB(163, 152, 195),
        TextSize = 12,
    })

    createLabel(getKeysPage, {
        Position = UDim2.new(0, 0, 0, 0),
        Size = UDim2.new(1, 0, 0, 44),
        Text = "Ambil key langsung dari UI berdasarkan HWID perangkat ini. Setiap perangkat punya key berbeda.",
        TextWrapped = true,
        TextColor3 = Color3.fromRGB(195, 185, 225),
        TextSize = 13,
    })

    local hwidBox = Instance.new("TextLabel")
    hwidBox.BackgroundColor3 = Color3.fromRGB(18, 13, 31)
    hwidBox.Position = UDim2.new(0, 0, 0, 54)
    hwidBox.Size = UDim2.new(1, 0, 0, 44)
    hwidBox.Text = "HWID: " .. mask(state.hwid)
    hwidBox.TextXAlignment = Enum.TextXAlignment.Left
    hwidBox.Font = Enum.Font.Gotham
    hwidBox.TextSize = 13
    hwidBox.TextColor3 = Color3.fromRGB(245, 240, 255)
    hwidBox.Parent = getKeysPage
    createCorner(hwidBox, 12)
    createStroke(hwidBox, Color3.fromRGB(120, 100, 176), 0.45)
    local hwidPadding = Instance.new("UIPadding")
    hwidPadding.PaddingLeft = UDim.new(0, 12)
    hwidPadding.Parent = hwidBox

    local keyDisplay = Instance.new("TextLabel")
    keyDisplay.BackgroundColor3 = Color3.fromRGB(18, 13, 31)
    keyDisplay.Position = UDim2.new(0, 0, 0, 112)
    keyDisplay.Size = UDim2.new(1, 0, 0, 60)
    keyDisplay.Text = "Key perangkat akan muncul di sini"
    keyDisplay.TextXAlignment = Enum.TextXAlignment.Left
    keyDisplay.TextYAlignment = Enum.TextYAlignment.Top
    keyDisplay.Font = Enum.Font.Gotham
    keyDisplay.TextWrapped = true
    keyDisplay.TextSize = 13
    keyDisplay.TextColor3 = Color3.fromRGB(245, 240, 255)
    keyDisplay.Parent = getKeysPage
    createCorner(keyDisplay, 12)
    createStroke(keyDisplay, Color3.fromRGB(120, 100, 176), 0.45)
    local displayPadding = Instance.new("UIPadding")
    displayPadding.PaddingLeft = UDim.new(0, 12)
    displayPadding.PaddingTop = UDim.new(0, 10)
    displayPadding.Parent = keyDisplay

    local getKeyBtn = createButton(getKeysPage, "Get / Refresh Key", UDim2.new(0, 0, 0, 184), UDim2.new(0, 170, 0, 42))
    local copyKeyBtn = createSecondaryButton(getKeysPage, "Copy Key", UDim2.new(0, 182, 0, 184), UDim2.new(0, 110, 0, 42))
    local copyPortalBtn = createSecondaryButton(getKeysPage, "Copy Reset Portal", UDim2.new(0, 304, 0, 184), UDim2.new(0, 150, 0, 42))

    local getKeyStatus = createLabel(getKeysPage, {
        Position = UDim2.new(0, 0, 0, 238),
        Size = UDim2.new(1, 0, 0, 60),
        Text = "Status: belum mengambil key.",
        TextWrapped = true,
        TextColor3 = Color3.fromRGB(184, 173, 215),
        TextSize = 12,
    })

    local function setStatus(label, text, color)
        label.Text = text
        if color then
            label.TextColor3 = color
        end
    end

    local function switchTab(tabName)
        local keysActive = tabName == "keys"
        keysPage.Visible = keysActive
        getKeysPage.Visible = not keysActive
        tabKeys.BackgroundColor3 = keysActive and Color3.fromRGB(120, 73, 255) or Color3.fromRGB(33, 25, 53)
        tabGetKeys.BackgroundColor3 = keysActive and Color3.fromRGB(33, 25, 53) or Color3.fromRGB(120, 73, 255)
    end

    tabKeys.MouseButton1Click:Connect(function()
        switchTab("keys")
    end)

    tabGetKeys.MouseButton1Click:Connect(function()
        switchTab("get")
    end)

    resetBtn.MouseButton1Click:Connect(function()
        local key = keyBox.Text ~= "" and keyBox.Text or state.key
        local url = state.resetUrl
        if key ~= "" and not string.find(url, "key=", 1, true) then
            url = url .. (string.find(url, "?", 1, true) and "&" or "?") .. "key=" .. HttpService:UrlEncode(key)
        end

        if copyToClipboard(url) then
            notify(CONFIG.SCRIPT_NAME, "Link Reset HWID berhasil disalin ke clipboard.", 5)
            setStatus(statusText, "Status: link reset HWID berhasil disalin. Buka website lalu lakukan reset.", Color3.fromRGB(255, 194, 87))
        else
            setStatus(statusText, "Status: clipboard tidak tersedia. Link reset: " .. url, Color3.fromRGB(255, 194, 87))
        end
    end)

    local function fetchKey()
        setStatus(getKeyStatus, "Status: mengambil key dari backend...", Color3.fromRGB(184, 173, 215))
        local ok, statusCode, data = pcall(function()
            local code, body = apiGet("/api/get-key", {
                hwid = state.hwid,
            })
            return code, body
        end)

        if not ok then
            setStatus(getKeyStatus, "Status: gagal mengambil key. Pastikan API_BASE sudah benar dan backend aktif.", Color3.fromRGB(255, 126, 150))
            return
        end

        statusCode, data = statusCode, data
        if statusCode >= 200 and statusCode < 300 and data and data.success then
            state.key = data.key or ""
            state.resetUrl = data.resetUrl or state.resetUrl
            keyBox.Text = state.key
            keyDisplay.Text = ("Key: %s\nExpires: %s\nReset: %s"):format(
                tostring(data.key or "-"),
                tostring(data.expiresAt or "-"),
                tostring(data.resetUrl or state.resetUrl)
            )
            setStatus(getKeyStatus, data.message or "Key berhasil diambil.", Color3.fromRGB(82, 218, 152))
            notify(CONFIG.SCRIPT_NAME, "Key perangkat berhasil didapatkan.", 4)
        else
            local message = (data and data.message) or "Backend menolak request get-key."
            setStatus(getKeyStatus, "Status: " .. message, Color3.fromRGB(255, 126, 150))
        end
    end

    getKeyBtn.MouseButton1Click:Connect(fetchKey)

    copyKeyBtn.MouseButton1Click:Connect(function()
        local key = state.key ~= "" and state.key or keyBox.Text
        if key == "" then
            setStatus(getKeyStatus, "Status: belum ada key untuk disalin.", Color3.fromRGB(255, 194, 87))
            return
        end

        if copyToClipboard(key) then
            notify(CONFIG.SCRIPT_NAME, "Key berhasil disalin.", 4)
            setStatus(getKeyStatus, "Status: key berhasil disalin ke clipboard.", Color3.fromRGB(82, 218, 152))
        else
            setStatus(getKeyStatus, "Status: clipboard tidak tersedia di executor ini.", Color3.fromRGB(255, 194, 87))
        end
    end)

    copyPortalBtn.MouseButton1Click:Connect(function()
        if copyToClipboard(state.resetUrl) then
            notify(CONFIG.SCRIPT_NAME, "Link portal reset berhasil disalin.", 4)
            setStatus(getKeyStatus, "Status: link portal reset berhasil disalin.", Color3.fromRGB(82, 218, 152))
        else
            setStatus(getKeyStatus, "Status: clipboard tidak tersedia. Link: " .. state.resetUrl, Color3.fromRGB(255, 194, 87))
        end
    end)

    local function verifyCurrentKey()
        local key = keyBox.Text:gsub("^%s+", ""):gsub("%s+$", "")
        if key == "" then
            setStatus(statusText, "Status: masukkan key terlebih dahulu.", Color3.fromRGB(255, 194, 87))
            return
        end

        setStatus(statusText, "Status: memverifikasi key ke backend...", Color3.fromRGB(184, 173, 215))

        local ok, statusCode, data = pcall(function()
            local code, body = apiGet("/api/verify-key", {
                key = key,
                hwid = state.hwid,
            })
            return code, body
        end)

        if not ok then
            setStatus(statusText, "Status: verifikasi gagal. Pastikan API_BASE dan functions Netlify aktif.", Color3.fromRGB(255, 126, 150))
            return
        end

        statusCode, data = statusCode, data
        if statusCode >= 200 and statusCode < 300 and data and data.success then
            state.key = key
            state.resetUrl = data.resetUrl or state.resetUrl
            setStatus(statusText, "Status: verifikasi berhasil. UI utama sedang dibuka...", Color3.fromRGB(82, 218, 152))
            notify(CONFIG.SCRIPT_NAME, "Key verified. Membuka UI utama...", 4)
            state.verified = true
            task.delay(0.35, function()
                if screenGui.Parent then
                    screenGui:Destroy()
                end
            end)
            return
        end

        local message = (data and data.message) or "Verifikasi ditolak oleh backend."
        setStatus(statusText, "Status: " .. message, Color3.fromRGB(255, 126, 150))

        if data and data.resetRequired then
            notify(CONFIG.SCRIPT_NAME, "Key ini perlu reset HWID terlebih dahulu.", 6)
            local resetCopyUrl = data.resetUrl or state.resetUrl
            if copyToClipboard(resetCopyUrl) then
                setStatus(statusText, "Status: key masih terikat ke perangkat lain. Link reset sudah disalin ke clipboard.", Color3.fromRGB(255, 194, 87))
            end
        end
    end

    verifyBtn.MouseButton1Click:Connect(verifyCurrentKey)
    keyBox.FocusLost:Connect(function(enterPressed)
        if enterPressed then
            verifyCurrentKey()
        end
    end)

    makeDraggable(main, topBar)
    switchTab("keys")

    notify(CONFIG.SCRIPT_NAME, "Key system siap. Gunakan tab Get Keys atau langsung verify key Anda.", 5)

    return state
end

return function(windui, options)
    local state = buildKeyGate()

    repeat
        task.wait(0.1)
    until state.verified == true or state.cancelled == true

    if state.cancelled then
        error("Key system ditutup sebelum verifikasi selesai.")
    end

    local ok, remoteScript = pcall(function()
        return game:HttpGet(CONFIG.ORIGINAL_SCRIPT_URL)
    end)

    if not ok or not remoteScript then
        error("Gagal mengambil script utama dari ORIGINAL_SCRIPT_URL.")
    end

    local compiled, compileError = loadstring(remoteScript)
    if not compiled then
        error("Script utama gagal di-compile: " .. tostring(compileError))
    end

    local loaded = compiled()

    if type(loaded) == "function" then
        return loaded(windui, options)
    end

    local meta = getmetatable(loaded)
    if type(loaded) == "table" and meta and type(meta.__call) == "function" then
        return loaded(windui, options)
    end

    return loaded
end
