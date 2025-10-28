
mon = peripheral.find("monitor")
local monX, monY = mon.getSize()

local inventories = { peripheral.find("inventory") }
local summary = {}

function drawBox(xMin, xMax, yMin, yMax, title, bcolor, tcolor)
    mon.setBackgroundColor(bcolor)
    for xPos = xMin, xMax, 1 do
        mon.setCursorPos(xPos, yMin)
        mon.write(" ")
    end
    for yPos = yMin, yMax, 1 do
        mon.setCursorPos(xMin, yPos)
        mon.write(" ")
        mon.setCursorPos(xMax, yPos)
        mon.write(" ")

    end
    for xPos = xMin, xMax, 1 do
        mon.setCursorPos(xPos, yMax)
        mon.write(" ")
    end
    mon.setCursorPos(xMin+2, yMin)
    mon.setBackgroundColor(colors.black)
    mon.setTextColor(tcolor)
    mon.write(" ")
    mon.write(title)
    mon.write(" ")
    mon.setTextColor(colors.white)
end


function formatItemName(name)
    -- 1 Alles vor dem ":" entfernen
    name = string.gsub(name, ".*:", "")
    
    -- 2 Alles klein schreiben (optional, f�r saubere Basis)
    name = string.lower(name)
    
    -- 3 Jeden Unterstrich durch Leerzeichen ersetzen
    name = string.gsub(name, "_", " ")
    
    -- 4 Jeden Wortanfang gro� schreiben
    name = string.gsub(name, "(%a)([%w_']*)", function(first, rest)
        return string.upper(first) .. string.lower(rest)
    end)

    return name
end

function monPrint(mon, text)
    local x, y = mon.getCursorPos()
    mon.write(text)
    mon.setCursorPos(4, y + 1)
end

while true do
    summary = {} -- ✅ Tabelle leeren, bevor neu gezählt wird

    for _, inv in ipairs(inventories) do
        for slot, item in pairs(inv.list()) do
            summary[item.name] = (summary[item.name] or 0) + item.count
        end
    end
    
    mon.clear()
    drawBox(2, monX - 1, 3, monY - 1, "Items", colors.gray, colors.lightGray)
    mon.setCursorPos(4, 5)
    
    for name, count in pairs(summary) do
        monPrint(mon, formatItemName(name) .. " x" .. count)
    end

    sleep(3)
end
