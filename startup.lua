--============================================================--
-- MiniOS v0.6 – Taskbar klickbar, auch wenn App läuft
--============================================================--

local term, fs, shell, os, window, colors =
      term, fs, shell, os, window, colors

------------------------ Monitor ------------------------------
-- ✨NEU: Terminal immer aktiv halten & Monitor ständig prüfen
local realTerm = term.current()       -- echtes Terminal sichern
local mon = peripheral.find("monitor")
local screen = realTerm               -- immer Terminal als Basis
local w, h = screen.getSize()

-- Funktion: Text/Funktionen gleichzeitig auf Terminal & Monitor ausführen
local function dualWrite(fn)
    fn(realTerm)
    if mon then fn(mon) end
end

-- ✨NEU: prüft regelmäßig ob ein Monitor verfügbar ist
local function checkMonitor()
    local newMon = peripheral.find("monitor")
    if newMon ~= mon then
        mon = newMon
        if mon then
            mon.setTextScale(1)
            mon.clear()
            mon.setCursorPos(1,1)
        end
    end
end
---------------------------------------------------------------
-- Konfiguration
---------------------------------------------------------------
local APP_DIR = "osapps"
if not fs.exists(APP_DIR) then fs.makeDir(APP_DIR) end
local BAR_WIDTH = 10

-- Buttons in der Taskbar
local buttons = {
    { name="SCADA",   label="SCADA",  action=function() runApp("scada_setup") end },
    { name="music",   label="Music",  action=function() runApp("music") end },
    { name="shell",   label="Shell",  action=function() shellWindow() end },
    { name="reboot",  label="Reboot", action=function() os.reboot() end },
    { name="off",     label="Off",    action=function() os.shutdown() end },
}

---------------------------------------------------------------
-- App-Fenster
---------------------------------------------------------------
local function createAppWindow()
    w, h = screen.getSize()
    return window.create(screen,
        BAR_WIDTH + 1, 1,
        math.max(1, w - BAR_WIDTH), h, true)
end

local appWin = createAppWindow()
appWin.setBackgroundColor(colors.white)
appWin.setTextColor(colors.black)
appWin.clear()

---------------------------------------------------------------
-- Hilfsfunktionen
---------------------------------------------------------------
local function appCenterWrite(y, text)
    local aw = ({ appWin.getSize() })[1]
    local x = math.max(1, math.floor((aw - #text) / 2) + 1)
    appWin.setCursorPos(x, y)
    appWin.write(text)
end

-- ✨NEU: Taskbar wird auf Terminal UND Monitor gezeichnet
local function drawTaskbar()
    w, h = screen.getSize()
    dualWrite(function(t)
        t.setBackgroundColor(colors.lightGray)
        t.setTextColor(colors.white)
        for y = 1, h do
            t.setCursorPos(1, y)
            t.write(string.rep(" ", BAR_WIDTH))
        end
        local yPos = 2
        for _, b in ipairs(buttons) do
            if yPos <= h then
                t.setCursorPos(2, yPos)
                local lbl = #b.label > BAR_WIDTH-2 and b.label:sub(1, BAR_WIDTH-2) or b.label
                t.write(lbl .. string.rep(" ", BAR_WIDTH-2-#lbl))
            end
            yPos = yPos + 2
        end
        t.setBackgroundColor(colors.white)
        t.setTextColor(colors.black)
    end)
end

local function detectButton(mx, my)
    if mx <= BAR_WIDTH then
        local yPos = 2
        for _, b in ipairs(buttons) do
            if my == yPos then return b end
            yPos = yPos + 2
        end
    end
    return nil
end

---------------------------------------------------------------
-- App-Management
---------------------------------------------------------------
function runScript(name)
    appWin.setBackgroundColor(colors.black)
    shell.run("osapps\\ccmsi install rtu main")
    sleep(2)
    shell.run("y")
end

function runApp(name)
    local path = fs.combine(APP_DIR, name .. ".lua")
    appWin = createAppWindow()
    appWin.setBackgroundColor(colors.black)
    appWin.clear()
    appWin.setCursorPos(1,1)

    if not fs.exists(path) then
        appWin.write("App nicht gefunden: "..name)
        appWin.setBackgroundColor(colors.black)
        shell.run("wget https://raw.githubusercontent.com/Biddimc/BiddiOS/refs/heads/main/osapps/scada_setup.lua osapps/scada_setup.lua")
        sleep(0.25)
        shell.run("wget https://raw.githubusercontent.com/Biddimc/BiddiOS/refs/heads/main/osapps/ccmsi.lua osapps/ccmsi.lua")
        sleep(0.25)
        shell.run("wget https://raw.githubusercontent.com/Biddimc/BiddiOS/refs/heads/main/osapps/music.lua osapps/music.lua")
        sleep(0.25)
        os.reboot()
        return
    end

    local function appRoutine()
        local ok, err = pcall(function()
            term.redirect(appWin)
            shell.run(path)
        end)
        term.redirect(screen)
        if not ok then
            appWin.setTextColor(colors.white)
            appWin.setCursorPos(1,1)
            appWin.write("Fehler:\n"..err)
        end
    end

    local function barRoutine()
        while true do
            local ev = { os.pullEvent() }
            if ev[1] == "mouse_click" or ev[1] == "monitor_touch" then
                local mx, my = ev[#ev-1], ev[#ev]
                local btn = detectButton(mx, my)
                if btn then return btn end
            elseif ev[1] == "monitor_resize" then
                drawTaskbar()
                appWin = createAppWindow()
            end
        end
    end

    drawTaskbar()
    parallel.waitForAny(appRoutine, barRoutine)
    drawTaskbar()
end

function shellWindow()
    appWin = createAppWindow()
    appWin.clear()
    appWin.setCursorPos(1,1)
    term.redirect(appWin)
    shell.run("shell")
    term.redirect(screen)
end

---------------------------------------------------------------
-- Boot & Hauptschleife
---------------------------------------------------------------
local function bootScreen()
    drawTaskbar()
    appCenterWrite(math.floor(h/2), "Biddi OS v0.6 startet...")
    os.sleep(1.5)
end

local function main()
    bootScreen()
    drawTaskbar()
    appWin.clear()
    appCenterWrite(math.floor(h/2), "Nichts offen...")

    while true do
        checkMonitor()  -- ✨NEU: Monitor-Check bei jedem Schleifendurchlauf
        local ev = { os.pullEvent() }

        if ev[1] == "mouse_click" or ev[1] == "monitor_touch" then
            local mx, my = ev[#ev-1], ev[#ev]
            local btn = detectButton(mx, my)
            if btn then btn.action() end

        elseif ev[1] == "monitor_resize" then
            drawTaskbar()
            appWin = createAppWindow()
            appWin.clear()
            appCenterWrite(math.floor(h/2), "Monitor angepasst")

        elseif ev[1] == "key" then
            local k = keys.getName(ev[2])
            if k == "escape" then os.shutdown() end
        end
    end
end

---------------------------------------------------------------
-- Start
---------------------------------------------------------------
local ok, err = pcall(main)
if not ok then
    term.redirect(screen)
    term.clear()
    term.setCursorPos(1,1)
    print("Biddi OS-Fehler:")
    print(err)
    print("Taste für Shell drücken.")
    os.pullEvent("key")
    shell.run("shell")
end

