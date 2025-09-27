--============================================================--
-- MiniOS v0.9 – Multi-Monitor-Multitasking + Taskbar im Terminal
--============================================================--

local term, fs, shell, os, window, colors, peripheral, keys, parallel =
      term, fs, shell, os, window, colors, peripheral, keys, parallel

---------------------------------------------------------------
-- Monitor-Erkennung
-- Findet alle angeschlossenen Monitore und speichert sie
-- als { side, mon } in einer Liste für den gezielten Zugriff.
---------------------------------------------------------------
local monitors = {}
for _, side in ipairs({"left","right","top","bottom","front","back"}) do
    if peripheral.getType(side) == "monitor" then
        table.insert(monitors, {side=side, mon=peripheral.wrap(side)})
    end
end

---------------------------------------------------------------
-- Terminal als Hauptanzeige für Taskbar
---------------------------------------------------------------
local terminal = term.current()
local tw, th = terminal.getSize()
local BAR_WIDTH = 10

---------------------------------------------------------------
-- App-Verzeichnis anlegen
---------------------------------------------------------------
local APP_DIR = "osapps"
if not fs.exists(APP_DIR) then fs.makeDir(APP_DIR) end

---------------------------------------------------------------
-- Buttons für die Taskbar
-- target = "terminal" oder "monitor1", "monitor2", ...
---------------------------------------------------------------
local buttons = {
    { name="SCADA", label="SCADA", target="monitor1",
      action=function(t) launchApp("scada_setup", t) end },
    { name="music", label="Music", target="monitor2",
      action=function(t) launchApp("music", t) end },
    { name="shell", label="Shell", target="terminal",
      action=function(t) launchApp("shell", t) end },
    { name="reboot",label="Reboot",target="terminal",
      action=function() os.reboot() end },
    { name="off",   label="Off",   target="terminal",
      action=function() os.shutdown() end },
}

---------------------------------------------------------------
-- Laufende Apps
-- Struktur: running[<target>] = { win = Fenster, coro = Coroutine }
-- Jede Zielanzeige (Monitor oder Terminal) kann ihre eigene App haben.
---------------------------------------------------------------
local running = {}

---------------------------------------------------------------
-- Fenster erstellen
-- Nutzt entweder Terminal oder den angegebenen Monitor.
-- Gibt das Ziel-Terminal und ein Fensterobjekt zurück.
---------------------------------------------------------------
local function createAppWindow(target)
    local scr = terminal
    if target:match("monitor") then
        local num = tonumber(target:match("%d+"))
        if monitors[num] then
            scr = monitors[num].mon
        else
            -- Fallback, wenn Monitor fehlt
            terminal.setCursorPos(1, th)
            terminal.setTextColor(colors.red)
            terminal.write("Monitor "..num.." nicht gefunden -> Terminal genutzt. ")
            terminal.setTextColor(colors.white)
        end
    end
    local w2, h2 = scr.getSize()
    return scr, window.create(scr, BAR_WIDTH + 1, 1,
                               math.max(1, w2 - BAR_WIDTH), h2, true)
end

---------------------------------------------------------------
-- Zentrierter Text in ein Fenster
---------------------------------------------------------------
local function centerWrite(win, y, text)
    local aw = ({ win.getSize() })[1]
    local x = math.max(1, math.floor((aw - #text) / 2) + 1)
    win.setCursorPos(x, y)
    win.write(text)
end

---------------------------------------------------------------
-- Taskbar im Terminal zeichnen
---------------------------------------------------------------
local function drawTaskbar()
    local w2,h2 = terminal.getSize()
    terminal.setBackgroundColor(colors.lightGray)
    terminal.setTextColor(colors.white)
    for y = 1, h2 do
        terminal.setCursorPos(1, y)
        terminal.write(string.rep(" ", BAR_WIDTH))
    end
    local yPos = 2
    for _, b in ipairs(buttons) do
        if yPos <= h2 then
            terminal.setCursorPos(2, yPos)
            local lbl = #b.label > BAR_WIDTH-2 and b.label:sub(1, BAR_WIDTH-2) or b.label
            terminal.write(lbl .. string.rep(" ", BAR_WIDTH-2-#lbl))
        end
        yPos = yPos + 2
    end
    terminal.setBackgroundColor(colors.black)
    terminal.setTextColor(colors.white)
end

---------------------------------------------------------------
-- Prüft, ob ein Klick auf die Taskbar erfolgt ist
---------------------------------------------------------------
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
-- App starten
-- Mehrere Apps können parallel laufen (eine pro target).
---------------------------------------------------------------
function launchApp(name, target)
    -- Prüfen ob App schon auf diesem Ziel läuft
    if running[target] then
        -- App beenden (erneutes Klicken beendet sie)
        running[target].kill = true
        return
    end

    local scr, win = createAppWindow(target)
    drawTaskbar()
    win.setBackgroundColor(colors.black)
    win.clear()
    win.setCursorPos(1,1)

    local path = fs.combine(APP_DIR, name .. ".lua")
    if not fs.exists(path) then
        win.write("App nicht gefunden: "..name)
        return
    end

    -- Coroutine für die App
    local co = coroutine.create(function()
        local ok, err = pcall(function()
            term.redirect(win)
            if name == "shell" then
                shell.run("shell")
            else
                shell.run(path)
            end
        end)
        term.redirect(scr)
        if not ok then
            win.setTextColor(colors.white)
            win.setCursorPos(1,1)
            win.write("Fehler:\n"..err)
        end
    end)

    running[target] = { win = win, coro = co, kill = false }
end

---------------------------------------------------------------
-- Hintergrundprozess für alle laufenden Apps
-- Führt die Coroutinen weiter, solange sie nicht beendet sind.
---------------------------------------------------------------
local function multitasker()
    while true do
        for tgt, app in pairs(running) do
            if app.kill then
                running[tgt] = nil
            elseif coroutine.status(app.coro) ~= "dead" then
                local ok, err = coroutine.resume(app.coro)
                if not ok then
                    app.win.setTextColor(colors.red)
                    app.win.setCursorPos(1,1)
                    app.win.write("Crash:\n"..err)
                    running[tgt] = nil
                end
            else
                running[tgt] = nil
            end
        end
        os.sleep(0.05) -- kleine Pause, damit CPU nicht voll ausgelastet wird
    end
end

---------------------------------------------------------------
-- Bootscreen
---------------------------------------------------------------
local function bootScreen()
    drawTaskbar()
    local win = window.create(terminal, BAR_WIDTH+1,1,tw-BAR_WIDTH,th,true)
    centerWrite(win, math.floor(th/2), "Biddi OS v0.9 startet...")
    os.sleep(1.5)
end

---------------------------------------------------------------
-- Hauptschleife: Eingaben für Taskbar verarbeiten
---------------------------------------------------------------
local function main()
    bootScreen()
    drawTaskbar()
    local idleWin = window.create(terminal, BAR_WIDTH+1,1,tw-BAR_WIDTH,th,true)
    centerWrite(idleWin, math.floor(th/2), "Nichts offen...")

    while true do
        local ev = { os.pullEvent() }

        if ev[1] == "mouse_click" then
            local mx, my = ev[3], ev[4]
            local btn = detectButton(mx, my)
            if btn then btn.action(btn.target) end

        elseif ev[1] == "term_resize" then
            drawTaskbar()

        elseif ev[1] == "key" then
            local k = keys.getName(ev[2])
            if k == "escape" then os.shutdown() end
        end
    end
end

---------------------------------------------------------------
-- Start
-- Nutzt parallel.waitForAny, um Multitasking und Eingaben
-- gleichzeitig zu ermöglichen.
---------------------------------------------------------------
local ok, err = pcall(function()
    parallel.waitForAny(main, multitasker)
end)
if not ok then
    term.redirect(terminal)
    term.clear()
    term.setCursorPos(1,1)
    print("Biddi OS-Fehler:\n"..err)
    print("Taste für Shell drücken.")
    os.pullEvent("key")
    shell.run("shell")
end
