--Powerup class
--MULTIBALL = 2 more balls will be spawned

Powerup = Class{}

--to make things simpler, type will also be used to determine what quad to use
--MULTIBALL = 3
--KEY = 9


--*Idea, instead of making multiple powerup items, should i just use the same one, since it's on a timer?
--*once it's collected, wait until the timer is up, and reset it to the top
--*This might work since there should be only one powerup on the screen at a time

function Powerup:init()
	self.width = 16
	self.height = 16 --I should probably change these, but later
end

function Powerup:reset(powerupType)
	self.type = powerupType

	--falls from above, at random point
	self.x = math.random(32, VIRTUAL_WIDTH - 32)
	self.y = -16

	--the speed that the powerup falls, randomly chosed
	self.fallSpeed = math.random(100, 200)

	self.inPlay = false
end

function Powerup:update(dt)
	--powerup just falls from above at the same rate
	self.y = self.y + self.fallSpeed * dt
end

function Powerup:render(dt)
	love.graphics.draw(gTextures['main'], gFrames['powerups'][self.type], self.x, self.y)
end

function Powerup:collides(target)
	-- first, check to see if the left edge of either is farther to the right
    -- than the right edge of the other
    if self.x > target.x + target.width or target.x > self.x + self.width then
        return false
    end

    -- then check to see if the bottom edge of either is higher than the top
    -- edge of the other
    if self.y > target.y + target.height or target.y > self.y + self.height then
        return false
    end 

    -- if the above aren't true, they're overlapping
    return true	
end
