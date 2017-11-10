local Sprite = require 'entities.sprite'

local splash = {}

function splash:init()
    self.componentList = {
        {
            parent = self,
            image = Sprite:new('assets/images/NezumiSplash.png'),
            initialAlpha = 0,
            finalAlpha = 255,
            fadeInTime = 1,
            stillTime = 1.5,
            fadeOutTime = 0.5,
            init = function(self)
                self.image.position = Vector(love.graphics.getWidth()/2, love.graphics.getHeight()/2)
                self.image.scale = Vector(2, 2)
                self.image:moveOriginToCorner('center')

                self.alpha = self.initialAlpha
                Timer.tween(self.fadeInTime, self, {alpha=self.finalAlpha}, 'linear', function()
                    Timer.tween(self.stillTime, self, {}, 'linear', function()
                        Timer.tween(self.fadeOutTime, self, {alpha=self.initialAlpha}, 'linear', function()
                            self.parent:incrementActive()
                        end)
                    end)
                end)
            end,
            draw = function(self)
                self.image.position = Vector(love.graphics.getWidth()/2, love.graphics.getHeight()/2)
                self.image.scale = Vector(2, 2)
                self.image:moveOriginToCorner('center')

                self.image.color[4] = self.alpha
                self.image:draw()
            end,
        },
    }

    for k, component in pairs(self.componentList) do
        component:init()
    end

    self.active = 1

    self.isStillActive = true
end

function splash:enter()

end

function splash:incrementActive()
    self.active = self.active + 1
    if self.active > #self.componentList and self.isStillActive then
        State.switch(States.game)
    end
end

function splash:update(dt)

end

function splash:keyreleased(key, code)
    if key ~= 'f11' then
        self.isStillActive = false
        State.switch(States.game)
    end
end

function splash:touchreleased(id, x, y, dx, dy, pressure)
    self.isStillActive = false
    State.switch(States.game)
end

function splash:mousepressed(x, y, mbutton)
    self.isStillActive = false
    State.switch(States.game)
end

function splash:draw()
    love.graphics.clear(255, 245, 248)

    local activeComponent = self.componentList[self.active]
    activeComponent:draw()
end

return splash
