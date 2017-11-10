-- Rotate point (px, py) about (cx, cy) by rotation (radians)
local function rotatePoint(rot, px, py, cx, cy)
    local x = math.cos(rot) * (px - cx) - math.sin(rot) * (py - cy) + cx
    local y = math.sin(rot) * (px - cx) + math.cos(rot) * (py - cy) + cy

    return x, y
end

local Sprite = Class("Sprite")

Sprite.static.DEFAULT_CORNER_MODE = "topleft"

function Sprite:initialize(image, params)
    if type(image) == "string" then
        self.image = love.graphics.newImage(image)

        if DEBUG and Sentinel then
            Sentinel:watch(image, function(image)
                self.image = love.graphics.newImage(image)
            end)
        end
    else
        self.image = image
    end

    self.position = Vector(0, 0)
    self.color = {255, 255, 255, 255}
    self.opacity = 1
    self.visible = true
    self.rotation = 0
    self.scale = Vector(1, 1)
    self.offset = Vector(0, 0)
    self.originOffset = Vector(0, 0)

    -- Unsupported by most functions
    self.shear = Vector(0, 0)

    self.cornerMode = Sprite.DEFAULT_CORNER_MODE

    local params = params or {}
    for k, v in pairs(params) do
        self[k] = v
    end

    self.width, self.height = self:calculateSize()
    self:moveOriginToCorner(self.cornerMode)
end

function Sprite:update()
    self.width, self.height = self:calculateSize()
end

function Sprite:draw()
    self:update()

    if self.cornerMode then
        self:moveOriginToCorner(self.cornerMode)
    end

    local x, y = self.position:unpack()

    x = x + self.offset.x
    y = y + self.offset.y

    x = math.floor(x + 0.5)
    y = math.floor(y + 0.5)

    if self.visible then
        local r, g, b, a = self.color[1], self.color[2], self.color[3], self.color[4]
        a = a or 255
        a = a * self.opacity
        love.graphics.setColor(r, g, b, a)
        love.graphics.draw(self.image, x, y, self.rotation, self.scale.x, self.scale.y, self.originOffset.x, self.originOffset.y, self.shear.x, self.shear.y)
    end
end

function Sprite:calculateSize()
    local width = self.image:getWidth() * math.abs(self.scale.x)
    local height = self.image:getHeight() * math.abs(self.scale.y)

    return width, height
end

-- Corner mode relates to how the sprite is positioned relative to the origin
-- For example, sprites can be drawn relative to the bottom-right of an image rather
-- than the top-left
function Sprite:moveOriginToCorner(cornerMode)
    self.cornerMode = cornerMode

    if cornerMode == "topleft" then
        self.originOffset.x = 0
        self.originOffset.y = 0

    elseif cornerMode == "topright" then
        self.originOffset.x = self.width
        self.originOffset.y = 0

    elseif cornerMode == "bottomleft" then
        self.originOffset.x = 0
        self.originOffset.y = self.height

    elseif cornerMode == "bottomright" then
        self.originOffset.x = self.width
        self.originOffset.y = self.height

    elseif cornerMode == "center" then
        self.originOffset.x = self.width/2
        self.originOffset.y = self.height/2

    elseif cornerMode == "centerleft" then
        self.originOffset.x = 0
        self.originOffset.y = self.height/2

    elseif cornerMode == "centerright" then
        self.originOffset.x = self.width
        self.originOffset.y = self.height/2

    elseif cornerMode == "topcenter" then
        self.originOffset.x = self.width/2
        self.originOffset.y = 0

    elseif cornerMode == "bottomcenter" then
        self.originOffset.x = self.width/2
        self.originOffset.y = self.height

    end

    -- Account for changes in scale
    self.originOffset.x = self.originOffset.x / self.scale.x
    self.originOffset.y = self.originOffset.y / self.scale.y
end

function Sprite:getRelativePosition(x, y, prescaled)
    if not prescaled then
        x = x * self.scale.x
        y = y * self.scale.y
    end

    x = x + self.position.x + self.offset.x
    y = y + self.position.y + self.offset.y

    x, y = rotatePoint(self.rotation, x, y, self.position.x + self.offset.x, self.position.y + self.offset.y)

    x = math.floor(x + 0.5)
    y = math.floor(y + 0.5)
    
    return x, y
end

-- Returns the true top left position, no matter the origin offset
function Sprite:getTopLeftPosition()
    return self:getRelativePosition(-self.originOffset.x, -self.originOffset.y)
end

function Sprite:getRectangle()
    local points = {
        0, 0,
        self.width, 0,
        self.width, self.height,
        0, self.height,
        0, 0
    }

    for i=1, #points, 2 do
        local x = points[i]
        local y = points[i+1]

        x = x - self.originOffset.x * self.scale.x
        y = y - self.originOffset.y * self.scale.y

        points[i], points[i+1] = self:getRelativePosition(x, y, true)
    end

    return points
end

return Sprite
