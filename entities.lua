local vector = require("vendor/hump/vector")
local colors = require("colors")
local Rect = require("rect")
require("drawing")

LevelFlag = {}

function LevelFlag:new(image, quad, pos, color)
    self.__index = self
    local rect = Rect.build { topleft = pos, width = 64, height = 64 }

    local this = setmetatable({
        image = image,
        quad = quad,
        rect = rect,
        color = color,
        tag = "flag",
    }, self)

    return this
end

function LevelFlag:update(dt) end

function LevelFlag:draw()
    love.graphics.draw(self.image, self.quad, self.rect.pos.x, self.rect.pos.y)
end

Blast = {}

function Blast:new(pos, radius, duration)
    self.__index = self
    radius = radius or 200
    duration = duration or 0.3
    return setmetatable({
        pos = pos,
        target_radius = radius,
        color = colors.color("white"),
        current_radius = radius * 0.05,
        duration = duration,
        current_time = 0,
        is_dead = false,
    }, self)
end

function Blast:update(dt)
    self.current_time = self.current_time + dt
    self.color[4] = self.color[4] - 255 / self.duration * dt
    self.current_radius = self.current_radius + self.target_radius / self.duration * dt
    if self.current_time >= self.duration then
        self.is_dead = true
    end
end

function Blast:draw()
    WithColor(self.color, function()
        love.graphics.circle("fill", self.pos.x, self.pos.y, self.current_radius)
    end)
end

Diamond = {}

function Diamond:new(image, quad, pos, color, world)
    self.__index = self
    local rect = Rect.build { center = pos, width = 64, height = 64 }
    local hitbox_width, hitbox_height = rect.width * 0.3, rect.height * 0.3

    local this = setmetatable({
        image = image,
        quad = quad,
        rect = rect,
        color = color,
        body = love.physics.newBody(world, pos.x, pos.y, "static"),
        shape = love.physics.newRectangleShape(hitbox_width, hitbox_height),
        tag = "diamond",
    }, self)

    this.fixture = love.physics.newFixture(this.body, this.shape)
    this.fixture:setUserData(this)
    this.fixture:setSensor(true)

    return this
end

function Diamond:update(dt) end

function Diamond:draw()
    love.graphics.draw(self.image, self.quad, self.rect.pos.x, self.rect.pos.y)
end

function Diamond:kill()
    self.is_dead = true
    self.fixture:destroy()
end

InvisibleStaticCollider = {}

function InvisibleStaticCollider:new(pos, width, height, world, tag)
    self.__index = self

    local this = setmetatable({
        body = love.physics.newBody(world, pos.x, pos.y, "static"),
        shape = love.physics.newRectangleShape(width, height),
        tag = tag,
    }, self)

    this.fixture = love.physics.newFixture(this.body, this.shape)
    this.fixture:setUserData(this)
    this.fixture:setSensor(true)

    return this
end

function InvisibleStaticCollider:update(dt) end

function InvisibleStaticCollider:draw() end

Player = {}

function Player:new()
    self.__index = self
    return setmetatable({
        direction = vector(),
        tag = "player",
    }, self)
end

function Player:init(images, world, initialPos)
    self.images = images
    self.state = "idle"
    self.facing = "right"
    self.image = self.images["walk1"]
    self.rect = Rect.fromImage(self.image)
    self.initialPosition = initialPos
    self.frame_index = 1
    self.body = love.physics.newBody(world, self.initialPosition.x, self.initialPosition.y, "dynamic")
    local hitbox_width, hitbox_height = self.rect.width * 0.8, self.rect.height * 0.8
    self.shape = love.physics.newRectangleShape(hitbox_width, hitbox_height)
    self.fixture = love.physics.newFixture(self.body, self.shape)
    self.fixture:setUserData(self)
    self.body:setFixedRotation(true)
    self.fixture:setUserData(self)
    self.direction = vector()
    self.singleTouch = false
    self.swipeDirection = nil
    self.grounded = false
    self.speed_x = 300
    self:resetInitialPos()
end

function Player:resetInitialPos()
    self.body:setPosition(self.initialPosition.x, self.initialPosition.y)
    self.rect:setCenter(vector(self.body:getPosition()))
end

function Player:registerSingleTouch(touched)
    self.singleTouch = touched
end

function Player:input()
    self.direction = vector()

    local playerUp = love.keyboard.isDown("up") or self.singleTouch
    if self.singleTouch then
        -- we reset the variable just after using it to ensure we only process a touch once
        self.singleTouch = false
    end
    local playerLeft = love.keyboard.isDown("left") or self.swipeDirection == "left"
    local playerRight = love.keyboard.isDown("right") or self.swipeDirection == "right"

    if playerUp and self.grounded then
        self.direction.y = -1
        self.grounded = false
    end
    if playerLeft then
        self.direction.x = -1
        self.facing = "left"
    end
    if playerRight then
        self.direction.x = 1
        self.facing = "right"
    end
    self.direction:normalizeInplace()
end

function Player:move()
    local _, dy = self.body:getLinearVelocity()
    local dx = self.direction.x * self.speed_x
    dy = dy + self.direction.y * 600
    self.body:setLinearVelocity(dx, dy)
    self.rect:setCenter(vector(self.body:getPosition()))
end

function Player:getAnimationState()
    local dx, dy = self.body:getLinearVelocity()
    local is_moving_vertically = math.abs(dy) >= 0.01
    if dx ~= 0 and not is_moving_vertically then
        return "walking"
    elseif is_moving_vertically then
        return "jumping"
    end
    return "idle"
end

function Player:beginContact(a, b, contact)
    if self.grounded then return end
    if contact == nil then return end
    local nx, ny = contact:getNormal()
    -- ny -1 if a is on top of b, or 1 if b is on top of a
    if a == self.fixture then
        if ny > 0 then
            self.grounded = true
        end
    else
        if ny < 0 then
            self.grounded = true
        end
    end
end

function Player:animate(dt)
    self.state = self:getAnimationState()
    local animation_speed = 10
    local frame_state = "walk1"
    if self.state == "walking" then
        local frames = 2
        self.frame_index = (self.frame_index + animation_speed * dt) % frames
        frame_state = string.format("walk%d", math.floor(self.frame_index) + 1)
    elseif self.state == "jumping" then
        frame_state = "swim2"
    end
    self.image = self.images[frame_state]
end

function Player:update(dt)
    self:input()
    self:move()
    self:animate(dt)
end

function Player:draw()
    local r, sx, sy, ox, oy, kx, ky = 0, 1, 1, 0, 0, 0, 0
    if self.facing == "left" then
        sx = sx * -1
        ox = self.rect.width - ox
        kx = kx * -1
        ky = ky * -1
    end
    love.graphics.draw(self.image, self.rect.pos.x, self.rect.pos.y, r, sx, sy, ox, oy, kx, ky)
end
