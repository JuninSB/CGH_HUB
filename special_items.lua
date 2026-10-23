-- // THIS IS THE DEFAULT SPECIAL ITEMS DATABASE, YOU CAN MODIFY THE SOURCE AND MAKE YOUR OWN DATABASE IF YOU WANT! // --

--[[ Default Colors Table ]]
local colors = {
    red = Color3.fromRGB(255,0,0),
    green = Color3.fromRGB(0,255,0),
    blue = Color3.fromRGB(0,0,255),
    yellow = Color3.fromRGB(255,255,0),
    white = Color3.fromRGB(255,255,255),
    darkBlue = Color3.fromRGB(0, 0, 96),
    orange = Color3.fromRGB(255, 153, 28),
    blue1 = Color3.fromRGB(73, 195, 214),
}
--[[ Special items tables with their names and properties (default color and if they notify by default) ]]
local special_items = {
    ["AirHorn"] = {colors.yellow, false},
    ["Bandage"] = {colors.yellow, true},
    ["HealthKit"] = {colors.red, true},
    ["Tape"] = {colors.darkBlue, false},
    ["ResearchCapsule"] = {colors.darkBlue, false},
    ["Pumpkin"] = {colors.orange, false},
    ["PopBottle"] = {colors.blue1, false},
}
return special_items,colors
