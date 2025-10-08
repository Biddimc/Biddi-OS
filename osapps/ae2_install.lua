-- Universelle Computercraft App mit 4 roten Buttons
-- Funktioniert auf Monitoren oder Computerbildschirm
-- Buttons werden automatisch zentriert

-- Prüfen, ob ein Monitor existiert
local termObj = nil
local monitorSide = nil
for _, side in ipairs(peripheral.getNames()) do
    if peripheral.getType(side) == "monitor" then
        termObj = peripheral.wrap(side)
        monitorSide = side
        break
    end
end

-- Falls kein Monitor, benutzen wir den PC-Bildschirm
if not termObj then
    termObj = term
end

-- Bildschirm vorbereiten
--termObj.clear()
termObj.setBackgroundColor(colors.black)
termObj.setTextColor(colors.white)

-- Größe ermitteln
local w, h = termObj.getSize()

-- Button-Definitionen
local buttons = {
    {text = "CPU Usage", x = 2, y = 2, command = "installer install mecpus"},
    {text = "Crafting and Storage", x = 2, y = 5, command = "installer install storagerequester"},
    {text = "ME Drives", x = 2, y = 8, command = "installer install medrives"},
}

-- Buttons zentrieren
local spacing = math.floor(h / (#buttons + 1))
for i, button in ipairs(buttons) do
    button.y = spacing * i
    button.x = math.floor((w - #button.text - 2) / 2) + 1
end

-- Funktion zum Zeichnen der Buttons
local function drawButton(button)
    termObj.setBackgroundColor(colors.gray)
    termObj.setTextColor(colors.black)
    termObj.setCursorPos(button.x, button.y)
    termObj.write(" " .. button.text .. " ")
end

-- Alle Buttons zeichnen
for i, button in ipairs(buttons) do
    drawButton(button)
end

-- Prüfen, ob Klick auf Button fällt
local function checkButton(x, y)
    for _, button in ipairs(buttons) do
        local bx, by = button.x, button.y
        local bw = #button.text + 2
        if x >= bx and x <= bx + bw - 1 and y == by then
            return button
        end
    end
    return nil
end

-- Haupt-Event-Schleife
while true do
    local event, side, x, y
    if monitorSide then
        event, side, x, y = os.pullEvent("monitor_touch")
        if side ~= monitorSide then
            event = nil -- ignorieren, falls anderer Monitor
        end
    else
        event, side, x, y = os.pullEvent("mouse_click")
    end

    if event then
        local button = checkButton(x, y)
        if button then
            termObj.setBackgroundColor(colors.black)
            termObj.setCursorPos(1, h)
            termObj.clearLine()
            termObj.write("Führe aus: " .. button.command)
            shell.run(button.command)
            for _, btn in ipairs(buttons) do
                drawButton(btn)
            end
        end
    end
end
