require("utils")
local vector = require("vendor/hump/vector")
local Timer = require("vendor/hump/timer")
local Camera = require("vendor/hump/camera")
local sti = require("vendor/sti")
local colors = require("colors")
local sprite = require("sprite")
local Rect = require("rect")

-- uncomment the lines below to allow hot-reloading
local lick = require("vendor/lick")
lick.reset = true

local function withColor(color, func, ...)
    local old_r, old_g, old_b, old_a = love.graphics.getColor()
    love.graphics.setColor(love.math.colorFromBytes(colors.color(color)))
    func(...)
    love.graphics.setColor(old_r, old_g, old_b, old_a)
end

Player = {}

function Player:new()
    self.__index = self
    return setmetatable({
        speed = 300,
        direction = vector(),
        animation_speed = 10,
    }, self)
end

function Player:init(images, world, initialPos)
    self.images = images
    self.state = "idle"
    self.facing = "right"
    self.image = self.images["walk1"]
    self.rect = Rect.fromImage(self.image)
    self.initialPosition = vector(WIN_WIDTH / 2 - self.image:getWidth() / 2, WIN_HEIGHT - 200)
    self.frame_index = 1
    self.body = love.physics.newBody(world, self.initialPosition.x, self.initialPosition.y, "dynamic")
    local hitbox_width, hitbox_height = self.rect.width * 0.8, self.rect.height * 0.8
    self.shape = love.physics.newRectangleShape(hitbox_width, hitbox_height)
    self.fixture = love.physics.newFixture(self.body, self.shape)
    self.body:setFixedRotation(true)
    self.fixture:setUserData(self)
    self.direction = vector()
    self:resetInitialPos()
end

function Player:resetInitialPos()
    self.body:setPosition(self.initialPosition.x, self.initialPosition.y)
    self.rect:setCenter(vector(self.body:getPosition()))
end

function Player:isOnFloor()
    -- TODO: how to check player is on floor reliably?
    local _, dy = self.body:getLinearVelocity()
    return dy == 0
end

function Player:input()
    self.direction = vector()
    if love.keyboard.isDown("up") and self:isOnFloor() then
        self.direction.y = -1.5
    end
    if love.keyboard.isDown("left") then
        self.direction.x = -1
        self.facing = "left"
    end
    if love.keyboard.isDown("right") then
        self.direction.x = 1
        self.facing = "right"
    end
end

function Player:move()
    local _, dy = self.body:getLinearVelocity()
    local dx = 0
    local delta = vector(dx, dy) + self.direction * self.speed
    self.body:setLinearVelocity(delta.x, delta.y)
    self.rect:setCenter(vector(self.body:getPosition()))
end

function Player:animate(dt)
    local animation_state = "walk1"
    if self.direction.x ~= 0 or self.direction.y ~= 0 then
        self.state = "walking"
    else
        self.state = "idle"
        animation_state = "walk1"
    end
    if self.state == "walking" then
        local frames = 2
        self.frame_index = (self.frame_index + self.animation_speed * dt) % frames
        animation_state = string.format("walk%d", math.floor(self.frame_index) + 1)
    end
    self.image = self.images[animation_state]
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

local allSprites = sprite.Registry:new()
local player = Player:new()
local Images = {}
local gameOver = false
local score = 0
local camera
local gameMap
local gameMapRect
local world
local walls = {}
local debugMode = false
local levelTimer = Timer:new()
local timebomb

local function startLevelTimer(timeout)
    timebomb = timeout
    levelTimer:clear()
    levelTimer:after(timebomb, function()
        gameOver = true
    end)
    levelTimer:every(1, function()
        timebomb = timebomb - 1
    end)
end

function love.load()
    print('starting platformer...')
    math.randomseed(os.time())

    love.window.setTitle("Plat Précedent")
    WIN_WIDTH, WIN_HEIGHT = love.graphics.getDimensions()

    local gravity = 9.81 * 100
    world = love.physics.newWorld(0, gravity)

    Images.big_font = love.graphics.newFont("images/04B_11.ttf", 60)
    Images.medium_font = love.graphics.newFont("images/04B_11.ttf", 20)

    gameMap = sti('maps/map.lua')
    gameMapRect = Rect:new(0, 0, gameMap.width * gameMap.tilewidth, gameMap.height * gameMap.tileheight)

    local playerStates = {
        "dead",
        "duck",
        "fall",
        "hit",
        "roll",
        "stand",
        "swim1",
        "swim2",
        "switch1",
        "switch2",
        "up1",
        "up2",
        "up3",
        "walk1",
        "walk2",
        "walk3",
        "walk4",
        "walk5",
    }
    Images.playerImages = {}
    for _, state in ipairs(playerStates) do
        local imgPath = "images/player/playerRed_" .. state .. ".png"
        Images.playerImages[state] = love.graphics.newImage(imgPath)
    end

    for _, obj in ipairs(gameMap.layers["Collisions"].objects) do
        local wall = {}
        wall.body = love.physics.newBody(world, obj.x, obj.y, "static")
        wall.shape = love.physics.newRectangleShape(obj.width / 2, obj.height / 2, obj.width, obj.height)
        wall.fixture = love.physics.newFixture(wall.body, wall.shape)
        table.insert(walls, wall)
    end

    local playerInitialPos = vector(0, 0)
    for _, obj in ipairs(gameMap.layers["Entities"].objects) do
        if obj.name == "Player" then
            playerInitialPos.x, playerInitialPos.y = obj.x, obj.y
        end
    end

    player:init(Images.playerImages, world, playerInitialPos)
    allSprites:add("player", player)
    camera = Camera()
    startLevelTimer(300)
end

function love.keyreleased(key)
    if key == "f8" then
        debugMode = not debugMode
    end
end

local function handleGameOverEvents()
    if love.keyboard.isDown("return") and gameOver then
        score = 0

        allSprites:cleanup()

        player:resetInitialPos()
        gameOver = false
        startLevelTimer(300)
    end
end

local function cameraFollowPlayer()
    -- here we make the camera follow the player, except at the borders of the map rectangle
    camera:lookAt(player.rect:getCenterX(), player.rect:getCenterY())
    camera.x = max { WIN_WIDTH / 2, camera.x }
    camera.y = max { WIN_HEIGHT / 2, camera.y }
    camera.x = min { gameMapRect.width - WIN_WIDTH / 2, camera.x }
    camera.y = min { gameMapRect.height - WIN_HEIGHT / 2, camera.y }
end

local function handleGlobalEvents()
    if player.rect:getTop() > gameMapRect:getBottom() then
        gameOver = true
    end
end

function love.update(dt)
    if gameOver then
        handleGameOverEvents()
        return
    end
    world:update(dt)
    Timer.update(dt)
    levelTimer:update(dt)

    handleGlobalEvents()

    allSprites:update(dt)
    cameraFollowPlayer()
end

local function debugDraw(fixture)
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

function love.draw()
    withColor("darkslategrey", function()
        love.graphics.rectangle("fill", 0, 0, WIN_WIDTH, WIN_HEIGHT)
    end)

    if gameOver then
        withColor("antiquewhite", function()
            love.graphics.printf(
                "GAME OVER", Images.big_font, 0, WIN_HEIGHT / 2 - 100, WIN_WIDTH, "center")
            love.graphics.printf(
                string.format("Your score: %d", score), Images.medium_font, 0, WIN_HEIGHT / 2, WIN_WIDTH, "center")
            love.graphics.printf(
                "Press ENTER to play again", Images.medium_font, 0, WIN_HEIGHT / 2 + 50, WIN_WIDTH, "center")
        end)
        return
    end

    camera:attach()

    gameMap:drawLayer(gameMap.layers["Platforms"])
    gameMap:drawLayer(gameMap.layers["Decoration"])

    allSprites:draw()

    if debugMode then
        withColor("white", function()
            debugDraw(player.fixture)
            for _, wall in ipairs(walls) do
                debugDraw(wall.fixture)
            end
        end)
    end
    camera:detach()

    -- love.graphics.printf(string.format("Score: %d", score), -10, 10, WIN_WIDTH, "right")
    love.graphics.printf(string.format("Time left: %d", timebomb), -10, 10, WIN_WIDTH, "right")
end
