local game = {}

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

   self.triangles = love.math.triangulate(self.quickPoints)

   self.randomPoint = self:getRandomPoint()

    self.color = {
        love.math.random(0, 255),
        love.math.random(0, 255),
        love.math.random(0, 255),
    }

    self.namePos = self:getAveragePosition()
    self.nameOffset = Vector(0, 0)
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

function Polygon:moveNameOffset(delta)
    self.nameOffset = self.nameOffset + delta
end

function Polygon:draw(mx, my)
    -- polygon must not intersect itself
    love.graphics.setColor(self.color)
    if self.parent:isPointInPolygon(self, {mx,my}) then
        love.graphics.setColor(self.color[1]*2,
                               self.color[2]*2,
                               self.color[3]*2)
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

function game:getPolygonsWedge()
    local polygons = {}

    -- duplicate edges to exist in each direction
    local directionalEdges = {}
    for k, line in ipairs(self.lines) do
        table.insert(directionalEdges, {vi=line.points[1], vj=line.points[2], angle = line.angles[1]})
        table.insert(directionalEdges, {vi=line.points[2], vj=line.points[1], angle = line.angles[2]})
    end

    -- sort these edges into ascending order based on vi followed by angle
    directionalEdges = Lume.sort(directionalEdges, function(a, b)
        return a.vi < b.vi
            or a.vi == b.vi
           and a.angle < b.angle
    end)

    -- scan each of these edges.
    -- within each group vi, combine the nearest into wedges
    -- also combine the first and last entries
    --print("Edges: "..Inspect(directionalEdges))
    local wedges = {}
    local vertStart = 1
    local vertStartIndex = 1
    for i = 1, #directionalEdges do
        local edge = directionalEdges[i]
        if edge.vi > vertStart then
            local vertexWedges = self:getVertexWedges(directionalEdges, vertStartIndex, i-1)
            for i = 1, #vertexWedges do
                table.insert(wedges, vertexWedges[i])
            end
            vertStartIndex = i
            vertStart = edge.vi
            --print("Ok next start is: "..edge.vi .." and this is line: "..i)
        end
    end
    local vertexWedges = self:getVertexWedges(directionalEdges, vertStartIndex, #directionalEdges)
    for i = 1, #vertexWedges do
        table.insert(wedges, vertexWedges[i])
    end

    -- sort wedges into ascending order based on vi followed by vj
    wedges = Lume.sort(wedges, function(a, b)
        return a.vi < b.vi
            or a.vi == b.vi
           and a.vj < b.vj
    end)
    for i = 1, #wedges do
        wedges[i].used = false
    end

    --print("Sorted wedges: "..Inspect(wedges))

    local currentWedge
    local currentRegionList = {}

    while true do
        currentWedge = nil
        --print("Ok new iteration time")
        -- step 3. find the first unused wedge
        for i = 1, #wedges do
            if not wedges[i].used then
                --print("Choosing wedge #"..i)
                currentWedge = wedges[i]
                break
            end
        end

        if currentWedge then
            --print("Ye found one!")
            currentWedge.used = true
            table.insert(currentRegionList, currentWedge.vj)

            -- step 4. find the next wedge
            local returningToStep4 = true
            while returningToStep4 do
                local nextWedge
                for i = 1, #wedges do
                    local wedge = wedges[i]
                    if wedge.vi == currentWedge.vj and wedge.vj == currentWedge.vk then
                        nextWedge = wedge
                        break
                    end
                end

                table.insert(currentRegionList, nextWedge.vj)

                -- I think this is ok here?
                nextWedge.used = true

                -- step 5. see if the wedge is contiguous to the starting edge of the region
                if nextWedge.vj == currentRegionList[1] and
                   nextWedge.vk == currentRegionList[2] then
                     -- extract region and return to step 3
                     local newPolygon = {points={}, quickPoints={}, triangles={}, randomPoint={}, name=""}
                     print("Making a polygon!")

                     local newPolygon = Polygon:new(self, currentRegionList)
                     table.insert(polygons, newPolygon)

                     currentRegionList = {}
                     returningToStep4 = false
                else
                    -- set to the next wedge and return to step 4
                    currentWedge = nextWedge
                    returningToStep4 = true
                end
            end
        else
            print("No more wedge found")
            -- done finding polygons
            local polygons = self:trimExcessPolygons(polygons)
            return polygons
        end
    end

    error("This should not happen.")
end

function game:getVertexWedges(edges, startI, endI)
    --print("Let's find new wedges: ["..startI..","..endI.."]")
    local wedges = {}
    for i = startI, endI-1 do
        -- add a wedge
        --print("Add wedge: ("..edges[i].vj ..","..edges[i].vi ..","..edges[i+1].vj ..")")
        table.insert(wedges, {vi=edges[i].vj, vj=edges[i].vi, vk=edges[i+1].vj})
    end
    -- add wedge from end to start
    --print("Add wedge: ("..edges[endI].vj ..","..edges[endI].vi ..","..edges[startI].vj ..")")
    table.insert(wedges, {vi=edges[endI].vj, vj=edges[endI].vi, vk=edges[startI].vj})

    return wedges
end

function game:trimExcessPolygons(polygons)
    --print("BEFORE: "..Inspect(self.polygons))

    -- get triangles for each polygon
    -- determine 1 point from each polygon

    -- for each polygon, see how many of the random points it contains
    -- if 2 polygons contain the same point, remove the one that contains more points
    -- if the 2 polygons contain 1 each, then remove either one
    local foundList = {}
    for i = 1, #polygons do
        local mainPolygon = polygons[i]
        local founds = {} -- contains index of the poly
        for j = 1, #polygons do
            local secondaryPolygon = polygons[j]
            if i ~= j and self:isPointInPolygon(mainPolygon, secondaryPolygon.randomPoint) then
                table.insert(founds, j)
            end
        end

        foundList[i] = founds
    end

    -- when a polygon contains point from another polygon,
    --   remove the one that contains points from more polygons
    --   if even then choose arbitrarily

    -- if a polygon has a count == 1 and that point's source has count == 1, remove one arbitrarily
    -- if any have a count >= 2, remove that polygonlocal skipList = {}
    local skipList = {}
    local removeList = {}
    for i = #foundList, 1, -1 do
        local found = foundList[i]
        if not skipList[i] and #found == 1 and #foundList[found[1]] == 1 then
            -- remove this guy and skip the other guy
            table.insert(removeList, i)
            skipList[#foundList[found[1]]] = true
        elseif #found >= 2 then
            table.insert(removeList, i)
        end
    end

    for i = #removeList, 1, -1 do
        table.remove(polygons, removeList[i])
    end

    --print("AFTER: "..Inspect(self.polygons))

    return polygons
end

function game:init()
    self.maxConnectDist = 10


    self.points = {}
    self.lines = {} -- defined by 2 points
    self.polygons = {}

    self.recentPointIndex = nil
    self.drawing = false

    self.showAngleValues = false
    self.drawPoints = true
    self.drawLines  = true

    self.clickedRegion = nil
    self.referenceImage = nil
end

function game:enter()

end

function game:update(dt)
    if self.clickedRegion then
        local delta = Vector(0, 0)
        if love.keyboard.isDown('w', 'up') then
            delta.y = -1
        end
        if love.keyboard.isDown('s', 'down') then
            delta.y = 1
        end
        if love.keyboard.isDown('a', 'left') then
            delta.x = -1
        end
        if love.keyboard.isDown('d', 'right') then
            delta.x = 1
        end

        delta:normalizeInplace()
        self.clickedRegion:moveNameOffset(delta)
    end
end

function game:keypressed(key, code)
    if self.clickedRegion then
        if key == "backspace" then
            self.clickedRegion.name = self.clickedRegion.name:sub(1, -2)
        end
    else
        if key == "space" then
            self.polygons = {}
            local startTime = love.timer.getTime()
            self.polygons = self:getPolygonsWedge()
            print("Compute Time: " .. love.timer.getTime() - startTime)
        end

        if key == "a" then
            self.showAngleValues = not self.showAngleValues
        end

        if key == "p" then
            self.drawPoints = not self.drawPoints
        end

        if key == "l" then
            self.drawLines = not self.drawLines
        end
    end
end

function game:textinput(text)
    if self.clickedRegion then
        self.clickedRegion.name = self.clickedRegion.name .. text
    end
end


-- if there is a point within maxDist of (x,y),
-- returns it and the distance
-- otherwise returns nil
function game:getNearPoint(x, y)
    local nearestIndex = nil
    local nearestDist = math.huge
    local maxDist = self.maxConnectDist
    for i, point in ipairs(self.points) do
        local dist = math.sqrt((x-point.pos[1])^2 + (y-point.pos[2])^2)
        if dist <= maxDist and (not nearestIndex or dist < nearestDist) then
            nearestIndex = i
            nearestDist = dist
        end
    end

    return nearestIndex, nearestDist
end

function game:requestNearPoint(x, y)
    -- check if there is a nearby point
    -- otherwise make a new one
    -- return its index

    local nearestIndex, nearestDist = self:getNearPoint(x, y)

    if nearestIndex then
        return nearestIndex
    else
        table.insert(self.points, {pos={x, y}, lines={}, visited=false})
        return #self.points
    end
end

function game:mousepressed(x, y, mbutton)
    if mbutton == 1 then
        local clickedOnRegion = false
        for k, polygon in ipairs(self.polygons) do
            if self:isPointInPolygon(polygon, {x,y}) then
                clickedOnRegion = true
                self.clickedRegion = polygon
                break
            end
        end

        if clickedOnRegion then

        else
            if not self.clickedRegion then
                self.drawing = true
                self.recentPointIndex = self:requestNearPoint(x, y)
            end

            self.clickedRegion = nil
        end
    elseif mbutton == 2 then
        local grabbedPointIndex = self:getNearPoint(x, y)
        if grabbedPointIndex then
            self.grabbedPoint = self.points[grabbedPointIndex]
        end
    end
end

function game:mousereleased(x, y, mbutton)
    if self.drawing and mbutton == 1 then
        self.drawing = false
        local endPointIndex = self:requestNearPoint(x, y)
        local line = {
            points = {self.recentPointIndex, endPointIndex},
        }
        local point1, point2 = self.points[line.points[1]].pos, self.points[line.points[2]].pos
        line.angles = {
            math.atan2(point1[2]-point2[2], point2[1]-point1[1]),
            math.atan2(point2[2]-point1[2], point1[1]-point2[1])
        }

        local lineIndex = #self.lines+1
        self.lines[lineIndex] = line

        table.insert(self.points[self.recentPointIndex].lines, lineIndex)
        table.insert(self.points[endPointIndex].lines, lineIndex)
    end

    if mbutton == 2 then
        self.grabbedPoint = nil
    end
end

function game:mousemoved(x, y, dx, dy, istouch)
    if self.grabbedPoint then
        self.grabbedPoint.pos[1] = self.grabbedPoint.pos[1] + dx
        self.grabbedPoint.pos[2] = self.grabbedPoint.pos[2] + dy

        for k, polygon in pairs(self.polygons) do
            polygon:refresh()
        end
    end
end

function game:filedropped(file)
    -- hope it is an image
    self.referenceImage = love.graphics.newImage(file)
end

function game:drawLine(point1, point2)
    love.graphics.line(point1[1], point1[2], point2[1], point2[2])
end

function game:isPointInPolygon(polygon, point)
    for k, triangle in ipairs(polygon.triangles) do
        if self:isPointInTriangle(triangle, point) then
            return true
        end
    end

    return false
end

-- where triangle is a list {x1,y1, x2,y2, x3,y3}
-- and   point    is a list {x, y}
function game:isPointInTriangle(triangle, point)
    local p0x,p0y, p1x,p1y, p2x,p2y = unpack(triangle)
    local px,py = unpack(point)

    local area = 0.5 *(-p1y*p2x + p0y*(-p1x + p2x) + p0x*(p1y - p2y) + p1x*p2y)

    local s = 1/(2*area)*(p0y*p2x - p0x*p2y + (p2y - p0y)*px + (p0x - p2x)*py)
    local t = 1/(2*area)*(p0x*p1y - p0y*p1x + (p0y - p1y)*px + (p1x - p0x)*py)

    return s > 0 and t > 0 and 1-s-t > 0
end

function game:draw()
    love.graphics.setBackgroundColor(0, 156, 255)
    love.graphics.setFont(Fonts.bold[22])

    local mx, my = love.mouse:getPosition()

    -- draw polygons
    love.graphics.setColor(0, 0, 255, 255)
    for k, polygon in pairs(self.polygons) do
        polygon:draw(mx, my)
    end

    love.graphics.setColor(255, 255, 255)

    -- draw lines
    if self.drawLines then
        for k, line in pairs(self.lines) do
            self:drawLine(self.points[line.points[1]].pos, self.points[line.points[2]].pos)
        end
    end

    -- draw points
    if self.drawPoints then
        for k, point in pairs(self.points) do
            love.graphics.circle('fill', point.pos[1], point.pos[2], self.maxConnectDist * 0.5)
        end
    end

    love.graphics.setColor(255, 0, 0)
    -- draw random points
    --for k, polygon in pairs(self.polygons) do
    --    love.graphics.circle('line', polygon.randomPoint[1], polygon.randomPoint[2], 3)
    --end

    -- print point numbers
    --for k, point in pairs(self.points) do
    --    love.graphics.print(k, point.pos[1], point.pos[2])
    --end

    -- print region names
    for k, polygon in pairs(self.polygons) do
        polygon:drawName()
    end

    if self.showAngleValues then
        for k, line in pairs(self.lines) do
            local pos1 = Vector(unpack(self.points[line.points[1]].pos))
            local pos2 = Vector(unpack(self.points[line.points[2]].pos))
            local normal = (pos1 - pos2):perpendicular():normalizeInplace()
            local vec1 = (pos2 - pos1):normalizeInplace()
            local vec2 = (pos1 - pos2):normalizeInplace()

            local amount = 70
            local angle1 = string.format("%.4f", math.deg(line.angles[1]))
            local drawPos1 = pos1 + vec1 * amount + normal * -5
            local drawPos2 = pos2 + vec2 * amount + normal * -5

            local angle2 = string.format("%.4f", math.deg(line.angles[2]))
            love.graphics.print(angle1, drawPos1.x, drawPos1.y)
            love.graphics.print(angle2, drawPos2.x, drawPos2.y)
        end
    end
    love.graphics.setColor(255, 255, 255)

    if self.drawing then
        self:drawLine(self.points[self.recentPointIndex].pos, {mx, my})
    end

    local nearestIndex, nearestDist = self:getNearPoint(mx, my)
    if nearestIndex then
        local point = self.points[nearestIndex]
        love.graphics.circle('fill', point.pos[1], point.pos[2], self.maxConnectDist)
    end

    love.graphics.setColor(255, 255, 255, 150)
    if self.referenceImage then
        --love.graphics.draw( drawable, x, y, r, sx, sy, ox, oy, kx, ky )
        local w, h = self.referenceImage:getDimensions()
        love.graphics.draw(self.referenceImage, love.graphics.getWidth()/2, love.graphics.getHeight()/2, math.pi/2, .75, .75, w/2, h/2)
    end
end

return game
