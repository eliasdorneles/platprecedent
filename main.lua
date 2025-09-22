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
        speed = 200,
        direction = vector(),
        animation_speed = 10,
    }, self)
end

function Player:init(images)
    self.images = images
    self.state = "idle"
    self.facing = "right"
    self.image = self.images["walk1"]
    self.rect = Rect.fromImage(self.image)
    self:resetInitialPos()
    self.hitbox_rect = self.rect:inflated(-10, -25)
    self:update_hitbox()
    self.frame_index = 1
end

function Player:resetInitialPos()
    self.rect.pos = vector(WIN_WIDTH / 2 - self.image:getWidth() / 2, WIN_HEIGHT - 200)
end

function Player:update_hitbox()
    self.hitbox_rect:setCenter(self.rect:getCenter())
    self.hitbox_rect.pos.y = self.hitbox_rect.pos.y + 15
end

function Player:input()
    self.direction = vector()
    if love.keyboard.isDown("down") then
        self.direction.y = 1
    end
    if love.keyboard.isDown("up") then
        self.direction.y = -1
    end
    if love.keyboard.isDown("left") then
        self.direction.x = -1
        self.facing = "left"
    end
    if love.keyboard.isDown("right") then
        self.direction.x = 1
        self.facing = "right"
    end
    self.direction:normalizeInplace()
end

function Player:move(dt)
    self.rect.pos = self.rect.pos + self.direction * self.speed * dt
    self:update_hitbox()
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
    self:move(dt)
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


function love.load()
    print('starting platformer...')
    math.randomseed(os.time())

    love.window.setTitle("Plat Précedent")
    WIN_WIDTH, WIN_HEIGHT = love.graphics.getDimensions()

    Images.big_font = love.graphics.newFont("images/04B_11.ttf", 60)
    Images.medium_font = love.graphics.newFont("images/04B_11.ttf", 20)

    gameMap = sti('maps/map.lua')

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

    player:init(Images.playerImages)
    allSprites:add("player", player)
    camera = Camera()
end

local function handleGlobalEvents()
end

local function handleGameOverEvents()
    if love.keyboard.isDown("return") and gameOver then
        score = 0

        allSprites:cleanup()

        player:resetInitialPos()
        gameOver = false
    end
end

local function handleCollisions()
end

function love.update(dt)
    if gameOver then
        handleGameOverEvents()
        return
    end
    Timer.update(dt)

    handleGlobalEvents()

    allSprites:update(dt)

    handleCollisions()

    camera:lookAt(player.rect:getCenterX(), player.rect:getCenterY())
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
    gameMap:drawLayer(gameMap.layers["Tiles"])
    gameMap:drawLayer(gameMap.layers["Decoration"])
    gameMap:drawLayer(gameMap.layers["Objects"])

    allSprites:draw()
    camera:detach()

    love.graphics.printf(string.format("Score: %d", score), -10, 10, WIN_WIDTH, "right")
end
