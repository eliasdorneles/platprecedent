local colors = require("colors")

function WithColor(color, func, ...)
    local old_r, old_g, old_b, old_a = love.graphics.getColor()
    if type(color) == "string" then
        color = colors.color(color)
    end
    love.graphics.setColor(love.math.colorFromBytes(color))
    func(...)
    love.graphics.setColor(old_r, old_g, old_b, old_a)
end

function DebugDraw(fixture)
    local shape = fixture:getShape()
    local body = fixture:getBody()
    local points = { shape:getPoints() }
    local transformedPoints = {}
    for i = 1, #points, 2 do
        table.insert(transformedPoints, points[i] + body:getX())
        table.insert(transformedPoints, points[i + 1] + body:getY())
    end
    love.graphics.polygon("line", transformedPoints)
end
