--[[
    GD50
    Breakout Remake

    -- PlayState Class --

    Author: Colton Ogden
    cogden@cs50.harvard.edu

    Represents the state of the game in which we are actively playing;
    player should control the paddle, with the ball actively bouncing between
    the bricks, walls, and the paddle. If the ball goes below the paddle, then
    the player should lose one point of health and be taken either to the Game
    Over screen if at 0 health or the Serve screen otherwise.
]]

PlayState = Class{__includes = BaseState}


--[[
    We initialize what's in our PlayState via a state table that we pass between
    states as we go from playing to serving.
]]
function PlayState:enter(params)
    self.paddle = params.paddle
    self.bricks = params.bricks
    self.health = params.health
    self.score = params.score
    self.highScores = params.highScores
    self.ball = params.ball
    self.level = params.level

    self.recoverPoints = 5000

    -- give ball random starting velocity
    self:setRandomBallVelocity(self.ball)

    self.balls = {}

    table.insert(self.balls, self.ball)

    --initialize a table of locked bricks
    --will use this to determine if the key powerup should spawn
    --will also be used when all the locked bricks will be unlocked later
    self.lockedBricks = {}

    for k, brick in pairs(self.bricks) do
        if brick.isLockedBrick and not brick.unlocked then
            table.insert(self.lockedBricks, brick)
        end
    end

    if #self.lockedBricks > 0 then
        self.spawnKey = true
    end

    self.powerUpTimer = 0
    self.powerup = Powerup()

    --if the key powerup needs to be spawned, then spawn key, otherwise spawn multiball
    --if I want to add more powerups in the future, might be good idea to make a table to randomly pick from instead
    --since KEY is in the last index, I can find a way to exclude it if the key needs to be spawned
    self:generateNewPowerup()

end

function PlayState:update(dt)
    if self.paused then
        if love.keyboard.wasPressed('space') then
            self.paused = false
            gSounds['pause']:play()
        else
            return
        end
    elseif love.keyboard.wasPressed('space') then
        self.paused = true
        gSounds['pause']:play()
        return
    end

    -- update positions based on velocity
    self.paddle:update(dt)

    --balls are in a table, so they should all be checked
    for k, ball in pairs(self.balls) do
        ball:update(dt)
    
        if ball:collides(self.paddle) then
            -- raise ball above paddle in case it goes below it, then reverse dy
            ball.y = self.paddle.y - 8
            ball.dy = -ball.dy

            --
            -- tweak angle of bounce based on where it hits the paddle
            --

            -- if we hit the paddle on its left side while moving left...
            if ball.x < self.paddle.x + (self.paddle.width / 2) and self.paddle.dx < 0 then
                ball.dx = -50 + -(8 * (self.paddle.x + self.paddle.width / 2 - ball.x))
            
            -- else if we hit the paddle on its right side while moving right...
            elseif ball.x > self.paddle.x + (self.paddle.width / 2) and self.paddle.dx > 0 then
                ball.dx = 50 + (8 * math.abs(self.paddle.x + self.paddle.width / 2 - ball.x))
            end

            gSounds['paddle-hit']:play()
        end
    end

    -- detect collision across all bricks with the ball
    for k, brick in pairs(self.bricks) do

        --balls are now in a table so all balls should check collisions with all bricks
        for k, ball in pairs(self.balls) do
            -- only check collision if we're in play
            if brick.inPlay and ball:collides(brick) then

                if brick.isLockedBrick and not brick.unlocked then
                    gSounds['no-select']:stop()
                    gSounds['no-select']:play()
                end

                if not brick.isLockedBrick or brick.unlocked then
                    -- add to score
                    if brick.isLockedBrick then
                        self.score = self.score + 1000
                    else
                        self.score = self.score + (brick.tier * 200 + brick.color * 25)
                    end

                    -- trigger the brick's hit function, which removes it from play
                    brick:hit()

                    -- if we have enough points, recover a point of health
                    -- also for now we'll use this as a condition to grow the size of the paddle
                    if self.score > self.recoverPoints then
                        -- can't go above 3 health
                        self.health = math.min(3, self.health + 1)

                        -- multiply recover points by 2
                        self.recoverPoints = math.min(100000, self.recoverPoints * 2)

                        --grow the size of the paddle
                        --can't grow above size 4
                        self.paddle.size = math.min(4, self.paddle.size + 1)
                        self.paddle.width = math.min(128, self.paddle.width + 32)

                        -- play recover sound effect
                        gSounds['recover']:play()
                    end
                end

                -- go to our victory screen if there are no more bricks left
                if self:checkVictory() then
                    gSounds['victory']:play()

                    gStateMachine:change('victory', {
                        level = self.level,
                        paddle = self.paddle,
                        health = self.health,
                        score = self.score,
                        ball = self.ball,
                        highScores = self.highScores,
                        recoverPoints = self.recoverPoints
                    })
                end

                --
                -- collision code for bricks
                --
                -- we check to see if the opposite side of our velocity is outside of the brick;
                -- if it is, we trigger a collision on that side. else we're within the X + width of
                -- the brick and should check to see if the top or bottom edge is outside of the brick,
                -- colliding on the top or bottom accordingly 
                --

                -- left edge; only check if we're moving right, and offset the check by a couple of pixels
                -- so that flush corner hits register as Y flips, not X flips
                if ball.x + 2 < brick.x and ball.dx > 0 then
                    
                    -- flip x velocity and reset position outside of brick
                    ball.dx = -ball.dx
                    ball.x = brick.x - 8
                
                -- right edge; only check if we're moving left, , and offset the check by a couple of pixels
                -- so that flush corner hits register as Y flips, not X flips
                elseif ball.x + 6 > brick.x + brick.width and ball.dx < 0 then
                    
                    -- flip x velocity and reset position outside of brick
                    ball.dx = -ball.dx
                    ball.x = brick.x + 32
                
                -- top edge if no X collisions, always check
                elseif ball.y < brick.y then
                    
                    -- flip y velocity and reset position outside of brick
                    ball.dy = -ball.dy
                    ball.y = brick.y - 8
                
                -- bottom edge if no X collisions or top collision, last possibility
                else
                    
                    -- flip y velocity and reset position outside of brick
                    ball.dy = -ball.dy
                    ball.y = brick.y + 16
                end

                -- slightly scale the y velocity to speed up the game, capping at +- 150
                if math.abs(ball.dy) < 150 then
                    ball.dy = ball.dy * 1.02
                end

                -- only allow colliding with one brick, for corners
                break
            end
        end
    end

    -- if ball goes below bounds, revert to serve state and decrease health
   
    for k, ball in pairs(self.balls) do
        if ball.y >= VIRTUAL_HEIGHT then
            self.health = self.health - 1
            gSounds['hurt']:play()

            if self.health == 0 then
                gStateMachine:change('game-over', {
                    score = self.score,
                    highScores = self.highScores
                })
            else
                --change the size of the paddle for the serve state
                self.paddle.size = math.max(1, self.paddle.size - 1)
                self.paddle.width = math.max(32, self.paddle.width - 32)

                gStateMachine:change('serve', {
                    paddle = self.paddle,
                    bricks = self.bricks,
                    health = self.health,
                    score = self.score,
                    highScores = self.highScores,
                    level = self.level,
                    recoverPoints = self.recoverPoints
                })
            end
        end
    end

    -- for rendering particle systems
    for k, brick in pairs(self.bricks) do
        brick:update(dt)
    end

    self.powerUpTimer = self.powerUpTimer + dt

    if self.powerUpTimer > SPAWNTIMER then
        self.powerup.inPlay = true
        self.powerUpTimer = 0
    end

    --powerup logic
    if self.powerup.inPlay then
        self.powerup:update(dt)
    end

    if self.powerup:collides(self.paddle) then
        if self.powerup.type == MULTIBALL then
            self:activateMultiballPowerup()
        elseif self.powerup.type == KEY then
            self:unlockBricks()
        end
        --reset to either key or multiball powerup
        self:generateNewPowerup()
    end

    if self.powerup.y > VIRTUAL_HEIGHT then
        self:generateNewPowerup()
    end


    if love.keyboard.wasPressed('escape') then
        love.event.quit()
    end
end

function PlayState:render()
    -- render bricks
    for k, brick in pairs(self.bricks) do
        brick:render()
    end

    -- render all particle systems
    for k, brick in pairs(self.bricks) do
        brick:renderParticles()
    end

    self.paddle:render()

    for k, ball in pairs(self.balls) do
        ball:render()
    end

    self.powerup:render()

    renderScore(self.score)
    renderHealth(self.health)

    -- pause text, if paused
    if self.paused then
        love.graphics.setFont(gFonts['large'])
        love.graphics.printf("PAUSED", 0, VIRTUAL_HEIGHT / 2 - 16, VIRTUAL_WIDTH, 'center')
    end
end

function PlayState:checkVictory()
    for k, brick in pairs(self.bricks) do
        if brick.inPlay then
            return false
        end 
    end

    return true
end

function PlayState:activateMultiballPowerup()
    --create 2 balls and add them to the ball table
    for i = 0, 1 do
        b = Ball(math.random(7))
        b.x = self.balls[1].x
        b.y = self.balls[1].y
        self:setRandomBallVelocity(b)

        table.insert(self.balls, b)
    end
end

function PlayState:unlockBricks()
    --unlock all bricks in the locked bricks table and remove them from the table
    for k, lockedbrick in pairs(self.lockedBricks) do
        lockedbrick.unlocked = true
        lockedbrick:emitParticles(64)
    end

    self.lockedbricks = {}
    --make the game stop spawning the key powerup, since it will be useless once this function is called
    self.spawnKey = false
end

function PlayState:setRandomBallVelocity(ball)
    ball.dx = math.random(-200, 200)
    ball.dy = math.random(-50, -60)
end

function PlayState:generateNewPowerup()
    if self.spawnKey then
        self.powerup:reset(math.random(2) == 1 and MULTIBALL or KEY)
    else
        self.powerup:reset(MULTIBALL)
    end
end