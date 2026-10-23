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

local special_items = {
    ["AirHorn"] = colors.yellow,
    ["Bandage"] = colors.yellow,
    ["HealthKit"] = colors.red,
    ["Tape"] = colors.darkBlue,
    ["ResearchCapsule"] = colors.darkBlue,
    ["Pumpkin"] = colors.orange,
    ["PopBottle"] = colors.blue1
}

return special_items,colors
