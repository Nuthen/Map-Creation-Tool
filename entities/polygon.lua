local Polygon = Class("Polygon")

function Polygon:initialize(parent, pointIndices)
    self.parent = parent

    self.points = {}
    self.quickPoints = {}
    self.triangles = {}

    self.name = ""

    for i = 1, #pointIndices-1 do
        local pointIndex = pointIndices[i]
        print("\tThis polygon includes point: "..pointIndex)
        table.insert(self.points, pointIndex)
        table.insert(self.quickPoints, self.parent.points[pointIndex].pos[1])
        table.insert(self.quickPoints, self.parent.points[pointIndex].pos[2])
   end

   local status, result = pcall(function()
       return love.math.triangulate(self.quickPoints)
   end)
   print("Status: "..tostring(status)..Inspect(result))
   if status then
       self.triangles = result

       self.randomPoint = self:getRandomPoint()

        self.color = {
            love.math.random(0, 255),
            love.math.random(0, 255),
            love.math.random(0, 255),
        }

        self.namePos = self:getAveragePosition()
        self.nameOffset = Vector(0, 0)

        self.destroy = false
   else
       print("Could not triangulate. Marking for removal.")
       self.destroy = true
   end
end

function Polygon:refresh()
    self.quickPoints = {}

    for i = 1, #self.points do
        local pointIndex = self.points[i]
        table.insert(self.quickPoints, self.parent.points[pointIndex].pos[1])
        table.insert(self.quickPoints, self.parent.points[pointIndex].pos[2])
   end

   self.triangles = love.math.triangulate(self.quickPoints)
end

function Polygon:getRandomPoint()
    local triangle = self.triangles[1]
    local p1       = Vector(triangle[1], triangle[2])
    local p2vector = Vector(triangle[3], triangle[4]) - p1
    local p3vector = Vector(triangle[5], triangle[6]) - p1

    local a1 = love.math.random() -- TODO: ensure this isn't 0 or 1
    local a2 = love.math.random() -- TODO: ensure this isn't 0 or 1

    return {(p1 + (p2vector * a1 + p3vector * a2 * (1-a1))):unpack()}
end

function Polygon:getAveragePosition()
    local x, y = self.quickPoints[1], self.quickPoints[2]
    for i = 3, #self.quickPoints, 2 do
        x = x + self.quickPoints[i]
        y = y + self.quickPoints[i+1]
    end
    local pointCount = #self.quickPoints/2
    x, y = x/pointCount, y/pointCount

    return Vector(x, y)
end

function Polygon:containsPoint(point)
    for k, triangle in ipairs(self.triangles) do
        if isPointInTriangle(triangle, point) then
            return true
        end
    end

    return false
end

function Polygon:moveNameOffset(delta)
    self.nameOffset = self.nameOffset + delta
end

function Polygon:draw(mx, my)
    -- polygon must not intersect itself
    love.graphics.setColor(self.color[1],
                           self.color[2],
                           self.color[3],
                           150)
    if self:containsPoint({mx,my}) then
        love.graphics.setColor(self.color[1]*2,
                               self.color[2]*2,
                               self.color[3]*2,
                               150)
    end

    for k2, triangle in pairs(self.triangles) do
        love.graphics.polygon('fill', triangle)
    end
end

function Polygon:drawName()
    love.graphics.setColor(255, 255, 255)

    local font = love.graphics.getFont()
    local textWidth, textHeight = font:getWidth(self.name), font:getHeight()

    local pos = self.namePos + self.nameOffset - 0.5*Vector(textWidth, textHeight)
    love.graphics.print(self.name, pos.x, pos.y)
end

return Polygon
