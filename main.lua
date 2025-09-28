require("utils")
local vector = require("vendor/hump/vector")
local Timer = require("vendor/hump/timer")
local Camera = require("vendor/hump/camera")
local sti = require("vendor/sti")
local Sprite = require("sprite")
local Rect = require("rect")
require("entities")
require("drawing")

-- uncomment the lines below to allow hot-reloading
local lick = require("vendor/lick")
lick.updateAllFiles = true
lick.reset = true


local allSprites = Sprite.Registry:new()
local player = Player:new()
local Images = {}
local gameOver = false
local gameWon = false
local score = 0
local camera
local gameMap
local gameMapRect
local world
local collisionWalls = {}
local debugMode = false
local levelTimer = Timer:new()
local timebomb
local bgcolor = "darkslategrey" -- default bg color, if not defined in map

local function beginContact(a, b, contact)
    local obj1, obj2 = a:getUserData(), b:getUserData()

    local function getTaggedCollision(tag1, tag2)
        if obj1 and obj2 and obj1.tag and obj2.tag then
            if obj1.tag == tag1 and obj2.tag == tag2 then
                local ret = {}
                ret[obj1.tag] = obj1
                ret[obj2.tag] = obj2
                return ret
            end
            if obj1.tag == tag2 and obj2.tag == tag1 then
                local ret = {}
                ret[obj1.tag] = obj1
                ret[obj2.tag] = obj2
                return ret
            end
        end
        return nil
    end

    -- player collect a diamond:
    local collision = getTaggedCollision("player", "diamond")
    if collision then
        collision.diamond:kill()
        allSprites:add("blast", Blast:new(collision.diamond.rect:getCenter(), 150))
        score = score + 5
    end

    -- player reached level goal:
    if getTaggedCollision("player", "goal") then
        score = score + 100
        gameWon = true
    end
end

local function endContact(a, b, contact) end

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

local function loadImagesAndFonts()
    Images.big_font = love.graphics.newFont("images/04B_11.ttf", 60)
    Images.medium_font = love.graphics.newFont("images/04B_11.ttf", 20)

    Images.tilesheet = love.graphics.newImage("images/tilesheet_complete.png")

    Images.diamonds = {}
    Images.diamonds["empty"] = love.graphics.newQuad(64 * 12, 64, 64, 64, Images.tilesheet)
    Images.diamonds["blue"] = love.graphics.newQuad(64 * 13, 64, 64, 64, Images.tilesheet)
    Images.diamonds["yellow"] = love.graphics.newQuad(64 * 14, 64, 64, 64, Images.tilesheet)
    Images.diamonds["red"] = love.graphics.newQuad(64 * 15, 64, 64, 64, Images.tilesheet)
    Images.diamonds["green"] = love.graphics.newQuad(64 * 16, 64, 64, 64, Images.tilesheet)

    Images.flags = {}
    Images.flags["red"] = love.graphics.newQuad(64 * 14, 64 * 8, 64, 64, Images.tilesheet)

    local playerFrameStates = {
        "dead", "duck", "fall", "hit", "roll", "stand", "swim1", "swim2", "switch1", "switch2",
        "up1", "up2", "up3", "walk1", "walk2", "walk3", "walk4", "walk5"
    }
    Images.playerImages = {}
    for _, state in ipairs(playerFrameStates) do
        local imgPath = "images/player/playerRed_" .. state .. ".png"
        Images.playerImages[state] = love.graphics.newImage(imgPath)
    end
end

function love.load()
    print('starting platformer...')
    math.randomseed(os.time())

    love.window.setTitle("Plat Précedent")
    WIN_WIDTH, WIN_HEIGHT = love.graphics.getDimensions()

    local gravity = 9.81 * 100
    world = love.physics.newWorld(0, gravity)

    world:setCallbacks(beginContact, endContact)


    gameMap = sti('maps/map.lua')
    gameMapRect = Rect:new(0, 0, gameMap.width * gameMap.tilewidth, gameMap.height * gameMap.tileheight)

    bgcolor = gameMap.layers["Platforms"].properties.bgcolor or bgcolor

    loadImagesAndFonts()

    for _, obj in ipairs(gameMap.layers["Collisions"].objects) do
        local wall = {}
        wall.body = love.physics.newBody(world, obj.x, obj.y, "static")
        wall.shape = love.physics.newRectangleShape(obj.width / 2, obj.height / 2, obj.width, obj.height)
        wall.fixture = love.physics.newFixture(wall.body, wall.shape)
        table.insert(collisionWalls, wall)
    end

    local playerInitialPos = vector(0, 0)
    for _, obj in ipairs(gameMap.layers["Entities"].objects) do
        local objPos = vector(obj.x, obj.y)
        if obj.name == "Player" then
            playerInitialPos = objPos
        elseif obj.name == "Diamond" then
            local diam = Diamond:new(Images.tilesheet, Images.diamonds[obj.type], objPos, obj.type, world)
            allSprites:add("diamonds", diam)
        elseif obj.name == "Flag" then
            local sprite = LevelFlag:new(Images.tilesheet, Images.flags[obj.type], objPos, obj.type)
            allSprites:add("flags", sprite)
        elseif obj.name == "Goal" then
            local pos = objPos + vector(obj.width / 2, obj.height / 2)
            local sprite = InvisibleStaticCollider:new(pos, obj.width, obj.height, world, "goal")
            allSprites:add("goal", sprite)
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
    if love.keyboard.isDown("return") and (gameOver or gameWon) then
        score = 0

        for diam in allSprites:groupiter("diamonds") do
            diam:kill() -- XXX: should I standardize the kill() method?
        end
        allSprites:cleanup()

        -- TODO: consider creating a Game/Level class, refactor this load level stuff into it
        for _, obj in ipairs(gameMap.layers["Entities"].objects) do
            local objPos = vector(obj.x, obj.y)
            if obj.name == "Diamond" then
                local diam = Diamond:new(Images.tilesheet, Images.diamonds[obj.type], objPos, obj.type, world)
                allSprites:add("diamonds", diam)
            end
        end

        player:resetInitialPos()
        gameOver = false
        gameWon = false
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
    if gameWon then
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

local function displayGameOverScreen()
    WithColor("antiquewhite", function()
        love.graphics.printf(
            "GAME OVER", Images.big_font, 0, WIN_HEIGHT / 2 - 100, WIN_WIDTH, "center")
        love.graphics.printf(
            string.format("Your score: %d", score), Images.medium_font, 0, WIN_HEIGHT / 2, WIN_WIDTH, "center")
        love.graphics.printf(
            "Press ENTER to play again", Images.medium_font, 0, WIN_HEIGHT / 2 + 50, WIN_WIDTH, "center")
    end)
end

local function displayGameWonScreen()
    WithColor("antiquewhite", function()
        love.graphics.printf(
            "YOU WON!", Images.big_font, 0, WIN_HEIGHT / 2 - 100, WIN_WIDTH, "center")
        love.graphics.printf(
            string.format("Your score: %d", score), Images.medium_font, 0, WIN_HEIGHT / 2, WIN_WIDTH, "center")
        love.graphics.printf(
            "Press ENTER to continue", Images.medium_font, 0, WIN_HEIGHT / 2 + 50, WIN_WIDTH, "center")
    end)
end

function love.draw()
    local background = bgcolor
    if gameOver then
        background = "darkred"
    end
    WithColor(background, function()
        love.graphics.rectangle("fill", 0, 0, WIN_WIDTH, WIN_HEIGHT)
    end)

    if gameOver then
        displayGameOverScreen()
        return
    end

    if gameWon then
        displayGameWonScreen()
        return
    end

    camera:attach()

    gameMap:drawLayer(gameMap.layers["Platforms"])
    gameMap:drawLayer(gameMap.layers["Decoration"])

    allSprites:draw()

    if debugMode then
        WithColor("white", function()
            for _, sprite in allSprites:iteritems() do
                if sprite.fixture then
                    DebugDraw(sprite.fixture)
                end
            end
            for _, wall in ipairs(collisionWalls) do
                DebugDraw(wall.fixture)
            end
        end)
    end
    camera:detach()

    love.graphics.printf(string.format("Score: %d", score), -10, 30, WIN_WIDTH, "right")
    love.graphics.printf(string.format("Time left: %d", timebomb), -10, 10, WIN_WIDTH, "right")
end
