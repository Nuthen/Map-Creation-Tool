-- drag and drop line, make a shape

local game = {}

function game:getPolygons(points, lines)
    for k, point in pairs(self.points) do
        point.visited = false
    end

    for k, line in pairs(self.lines) do
        -- for each side it can start from
        line.visited = {false, false}
    end

    local unvisitedPoints = {}
    for i = 1, #self.points do
        table.insert(unvisitedPoints, i)
    end
    print("Unvisited Count: "..#unvisitedPoints)

    local polygons = {}

    -- assuming the graph is connected
    local currentPointIndex = 1
    local currentPoint = self.points[currentPointIndex]
    local incomingAngle = 0
    local incomingLineIndex
    local journeyBeginPointIndex = currentPointIndex
    local currentShapePointIndices = {}
    -- ensure it doesn't stop mid journey
    while #unvisitedPoints > 0 or #currentShapePointIndices > 0 do
        print("\tUnvisited: "..#unvisitedPoints..' '..Inspect(unvisitedPoints))
        table.insert(currentShapePointIndices, currentPointIndex)
        print("\tCurrent poly "..Inspect(currentShapePointIndices))

        --if currentPoint.visited then
        --    error("RIIPERS")
        --else
        if currentPoint.visited then
            print("Point #:"..currentPointIndex.." is ALREADY visited")
        else
            print("Point #:"..currentPointIndex.." is not yet visited")
        end
            currentPoint.visited = true
            local place = Lume.find(unvisitedPoints, currentPointIndex)
            if place then
                table.remove(unvisitedPoints, place)
            end

            -- pick min angle edge that's not visited from this side
            local minAngle = math.huge
            local chosenLine
            local chosenLineIndex
            local chosenWhichPoint
            local outgoingAngle
            for i = 1, #currentPoint.lines do
                local line = self.lines[currentPoint.lines[i]]
                print("\t\tchecking line:{"..line.points[1]..', '..line.points[2].."}")
                print("\t\tsearching for the closest line. incoming angle: "..math.deg(incomingAngle))
                local whichPoint --= ???
                if line.points[1] == currentPointIndex then
                    whichPoint = 1
                elseif line.points[2] == currentPointIndex then
                    whichPoint = 2
                else
                    error("what no point found :C")
                end


                -- don't allow the line that you just came from
                if not line.visited[whichPoint] and currentPoint.lines[i] ~= incomingLineIndex then
                    local angle = line.angles[whichPoint]
                    angle = angle - (incomingAngle + math.pi)
                    if angle < -math.pi then
                        print("\t\t\tthe mod is "..math.deg(angle).."%180=".. math.deg(math.abs(angle))%180)
                        print("\t\t\tok angle is at.."..math.deg(math.abs(angle)).." and is moving back by ".. math.deg(math.abs(angle))%180)
                        angle = math.rad(180 - math.deg(math.abs(angle)) % 180)
                        print("\t\t\tso now the angle is at "..math.deg(angle))
                    end
                    print("\t\tPossible min angle?: ".. math.deg(angle).. " originally: ".. math.deg(line.angles[whichPoint]))
                    if angle < minAngle then
                        minAngle = angle
                        chosenLine = line
                        chosenLineIndex = currentPoint.lines[i]
                        chosenWhichPoint = whichPoint
                        outgoingAngle = line.angles[whichPoint]
                    end
                end
            end


            if chosenLine then
                print("\tminAngle.."..math.deg(minAngle).." Chosen Line:"..Inspect(chosenLine))

                -- note other point is the one you came from???
                local otherPoint = 1
                if chosenWhichPoint == 1 then
                    otherPoint = 2
                end

                incomingAngle = chosenLine.angles[otherPoint]
                incomingLineIndex = chosenLineIndex
                print("\t\tYea set that incoming angle to "..math.deg(incomingAngle).."aka:"..incomingAngle.." see the thing is: "..Inspect(chosenLine.angles))

                if chosenLine.visited[chosenWhichPoint] == nil then
                    error(chosenWhichPoint..Inspect(chosenLine)..' '..tostring(chosenLine.visited[1]))
                end
                chosenLine.visited[chosenWhichPoint] = true
                -- add that line to the list of polygons
                if not chosenLine.points[otherPoint] then error(otherPoint..' '..Inspect(chosenLine.points)) end
                currentPointIndex = chosenLine.points[otherPoint]
                currentPoint = self.points[currentPointIndex]
                print("Ye next line found.. heading to point"..currentPointIndex)

                if currentPoint.visited and currentPointIndex == journeyBeginPointIndex then
                    currentPoint.visited = true
                    print("Point #:"..currentPointIndex.." is already visited on this journey, make a polygon!")
                    -- cycle ended, shape enclosed
                    --add currentShapePointIndeces as a new polygon
                    local newPolygon = {}
                    for i = 1, #currentShapePointIndices do
                        print("This polygon includes point: "..currentShapePointIndices[i])
                        table.insert(newPolygon, self.points[currentShapePointIndices[i]].pos[1])
                        table.insert(newPolygon, self.points[currentShapePointIndices[i]].pos[2])
                    end
                    incomingAngle = 0
                    currentShapePointIndices = {}
                    table.insert(polygons, newPolygon)
                    currentPointIndex = unvisitedPoints[1]
                    currentPoint = self.points[currentPointIndex]
                    journeyBeginPointIndex = currentPointIndex
                end
            elseif #unvisitedPoints > 0 then
                -- move on to the next unvisited point
                currentPointIndex = unvisitedPoints[1]
                currentPoint = self.points[currentPointIndex]
                print("No next line found.. heading to point"..currentPointIndex)
                error("RIP")
                -- rip
            end
        --end
    end

    print("Unvisited: "..#unvisitedPoints)

    return polygons
end

function game:getPolygonsWedge()
    local polygons = {}
    self.polygonColors = {} -- TODO: unite

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

    print("Sorted wedges: "..Inspect(wedges))

    local currentWedge
    local currentRegionList = {}
    local wedgeIndex = 1

    while true do
        currentWedge = nil
        --print("Ok new iteration time")
        -- step 3. find the first unused wedge
        for i = 1, #wedges do
            if not wedges[i].used then
                print("Choosing wedge #"..i)
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

                nextWedge.used = true

                -- step 5. see if the wedge is contiguous to the starting edge of the region
                if nextWedge.vj == currentRegionList[1] and
                   nextWedge.vk == currentRegionList[2] then
                     -- extract region and return to step 3
                     local newPolygon = {}
                     print("Making a polygon!")

                     for i = 1, #currentRegionList-1 do
                         print("\tThis polygon includes point: "..currentRegionList[i])
                         table.insert(newPolygon, self.points[currentRegionList[i]].pos[1])
                         table.insert(newPolygon, self.points[currentRegionList[i]].pos[2])
                    end

                    -- not sure if this belongs
                    -- seems to make no difference
                    --nextWedge.used = true

                    love.math.triangulate(newPolygon)

                     currentRegionList = {}
                     table.insert(polygons, newPolygon)
                     self.polygonColors[#polygons] = {
                         love.math.random(0, 255),
                         love.math.random(0, 255),
                         love.math.random(0, 255),
                     }

                     returningToStep4 = false
                else
                    -- increment i and return to step 4
                    currentWedge = nextWedge

                    returningToStep4 = true
                end
            end
        else
            print("Sorry found none")
            -- done finding polygons
            return polygons
        end
    end

    error("wat don't happen here")
end

function game:getVertexWedges(edges, startI, endI)
    print("Let's find new wedges: ["..startI..","..endI.."]")
    local wedges = {}
    for i = startI, endI-1 do
        print("Add wedge: ("..edges[i].vj ..","..edges[i].vi ..","..edges[i+1].vj ..")")
        table.insert(wedges, {vi=edges[i].vj, vj=edges[i].vi, vk=edges[i+1].vj})
    end
    print("Add wedge: ("..edges[endI].vj ..","..edges[endI].vi ..","..edges[startI].vj ..")")
    table.insert(wedges, {vi=edges[endI].vj, vj=edges[endI].vi, vk=edges[startI].vj})

    return wedges
end

function game:init()
    self.minConnectDist = 10


    self.points = {}
    self.lines = {} -- defined by 2 points
    self.polygons = {}

    self.recentPointIndex = nil
    self.drawing = false

    self.showAngleValues = true
end

function game:enter()

end

function game:update(dt)

end

function game:trimExcessPolygons()
    -- get triangles for each polygon
    -- determine 1 point from each polygon
    -- when a polygon contains point from another polygon,
    --   remove the one that contains points from more polygons
    --   if even then choose arbitrarily

    -- dumb way: remove the poly with most points
    local maxPoints = 0
    local maxPoly
    for i = 1, #self.polygons do
        if #self.polygons[i] > maxPoints then
            maxPoints = #self.polygons[i]
            maxPoly = i
        end
    end

    table.remove(self.polygons, maxPoly)

    print(Inspect(self.polygons))

    --local triangles = love.math.triangulate(polygon)
end

function game:keypressed(key, code)
    if key == "space" then
        local startTime = love.timer.getTime()
        self.polygons = self:getPolygonsWedge()
        self:trimExcessPolygons()

        print("Compute Time: " .. love.timer.getTime() - startTime)
    end

    if key == "a" then
        self.showAngleValues = not self.showAngleValues
    end
end

function game:getNearPoint(x, y)
    local nearestIndex = nil
    local nearestDist = math.huge
    for i, point in ipairs(self.points) do
        local dist = math.sqrt((x-point.pos[1])^2 + (y-point.pos[2])^2)
        if dist <= self.minConnectDist and (not nearestIndex or dist < nearestDist) then
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
        self.drawing = true
        self.recentPointIndex = self:requestNearPoint(x, y)
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
end

function game:drawLine(point1, point2)
    love.graphics.line(point1[1], point1[2], point2[1], point2[2])
end

function game:draw()
    love.graphics.setColor(0, 0, 255, 255)
    for k, polygon in pairs(self.polygons) do
        love.graphics.setColor(self.polygonColors[k])
        -- polygon must not intersect itself
        local triangles = love.math.triangulate(polygon)
        for k, triangle in pairs(triangles) do
            love.graphics.polygon('fill', triangle)
        end
        --love.graphics.polygon('fill', polygon)
    end

    love.graphics.setColor(255, 255, 255)

    for k, line in pairs(self.lines) do
        self:drawLine(self.points[line.points[1]].pos, self.points[line.points[2]].pos)
    end

    for k, point in pairs(self.points) do
        love.graphics.circle('fill', point.pos[1], point.pos[2], self.minConnectDist * 0.5)
    end

    love.graphics.setColor(255, 0, 0)
    for k, point in pairs(self.points) do
        love.graphics.print(k, point.pos[1], point.pos[2])
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

    local mx, my = love.mouse:getPosition()

    if self.drawing then
        self:drawLine(self.points[self.recentPointIndex].pos, {mx, my})
    end

    local nearestIndex, nearestDist = self:getNearPoint(mx, my)
    if nearestIndex then
        local point = self.points[nearestIndex]
        love.graphics.circle('fill', point.pos[1], point.pos[2], self.minConnectDist)
    end
end

return game
