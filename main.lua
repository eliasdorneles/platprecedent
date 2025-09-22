require("utils")
local vector = require("vendor/hump/vector")
local Timer = require("vendor/hump/timer")
local anim8 = require 'vendor/anim8'
local colors = require("colors")
local sprite = require("sprite")
local Rect = require("rect")

-- uncomment the lines below to allow hot-reloading
-- local lick = require("vendor/lick")
-- lick.reset = true

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
    }, self)
end

function Player:init(image)
    self.image = image
    self.rect = Rect.fromImage(image)
    self:resetInitialPos()
    self.hitbox_rect = self.rect:inflated(-10, -25)
    self:update_hitbox()
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
    end
    if love.keyboard.isDown("right") then
        self.direction.x = 1
    end
    self.direction:normalizeInplace()
end

function Player:move(dt)
    self.rect.pos = self.rect.pos + self.direction * self.speed * dt
    self:update_hitbox()
end

function Player:update(dt)
    self:input()
    self:move(dt)
end

function Player:draw()
    love.graphics.draw(self.image, self.rect.pos.x, self.rect.pos.y)
end

local allSprites = sprite.Group:new()
local player = Player:new()
local Images = {}
local gameOver = false
local score = 0


function love.load()
    print('starting space shooter...')
    math.randomseed(os.time())

    love.window.setTitle("👾 space shooter")
    WIN_WIDTH, WIN_HEIGHT = love.graphics.getDimensions()

    Images.big_font = love.graphics.newFont("images/04B_11.ttf", 60)
    Images.medium_font = love.graphics.newFont("images/04B_11.ttf", 20)

    Images.player = love.graphics.newImage("images/player/playerRed_stand.png")

    player:init(Images.player)
    allSprites:add(player)
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
end

function love.draw()
    withColor("darkgreen", function()
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

    allSprites:draw()

    love.graphics.printf(string.format("Score: %d", score), -10, 10, WIN_WIDTH, "right")
end
