local newMatrix = require(Game.g3d.path .. ".matrices")
local g3d = Game.g3d 

Object = require "classic/classic"
local ThreeDee = Object:extend()
ThreeDee._class = "ThreeDee";

function ThreeDee:new()
    self.position = {0,0,0}
    self.target = {1,0,0}
    self.up = {0,0,1}
    self.direction = 0
    self.pitch = 0
    self.speed = 1

    self.viewMatrix = newMatrix()
    self.projectionMatrix = newMatrix()
end

function ThreeDee:getLookVector()
    local vx = self.target[1] - self.position[1]
    local vy = self.target[2] - self.position[2]
    local vz = self.target[3] - self.position[3]
    local length = math.sqrt(vx^2 + vy^2 + vz^2)

    -- make sure not to divide by 0
    if length > 0 then
        return vx/length, vy/length, vz/length
    end
    return vx,vy,vz
end

-- give the camera a point to look from and a point to look towards
function ThreeDee:lookAt(x,y,z, xAt,yAt,zAt)
    self.position[1] = x
    self.position[2] = y
    self.position[3] = z
    self.target[1] = xAt
    self.target[2] = yAt
    self.target[3] = zAt

    -- update the direction and pitch based on lookAt
    local dx,dy,dz = self:getLookVector()
    self.direction = math.pi/2 - math.atan2(dz, dx)
    self.pitch = math.atan2(dy, math.sqrt(dx^2 + dz^2))

    -- update the self in the shader
    self:updateViewMatrix()
end

-- move and rotate the camera, given a point and a direction and a pitch (vertical direction)
function ThreeDee:lookInDirection(x_t,y,z, directionTowards,pitchTowards)
    local x = x_t;
    if(type(x_t) == "table") then
        x = x_t[1] or nil;
        y = x_t[2] or nil;
        z = x_t[3] or nil;
    end
    
    self.position[1] = x or self.position[1]
    self.position[2] = y or self.position[2]
    self.position[3] = z or self.position[3]

    self.direction = directionTowards or self.direction
    self.pitch = pitchTowards or self.pitch

    -- turn the cos of the pitch into a sign value, either 1, -1, or 0
    local sign = math.cos(self.pitch)
    sign = (sign > 0 and 1) or (sign < 0 and -1) or 0

    -- don't let cosPitch ever hit 0, because weird camera glitches will happen
    local cosPitch = sign*math.max(math.abs(math.cos(self.pitch)), 0.00001)

    -- convert the direction and pitch into a target point
    print(self.target[1],self.position[1], self.direction);
    self.target[1] = self.position[1]+math.cos(self.direction)*cosPitch
    self.target[2] = self.position[2]+math.sin(self.direction)*cosPitch
    self.target[3] = self.position[3]+math.sin(self.pitch)

    -- update the camera in the shader
    self:updateViewMatrix()
end

-----------------------

-- recreate the camera's view matrix from its current values
function ThreeDee:updateViewMatrix()
    self.viewMatrix:setViewMatrix(self.position, self.target, self.up)
end

-- recreate the camera's projection matrix from its current values
function ThreeDee:updateProjectionMatrix()
    self.projectionMatrix:setProjectionMatrix(self.fov, self.nearClip, self.farClip, self.aspectRatio)
end

-- recreate the camera's orthographic projection matrix from its current values
function ThreeDee:updateOrthographicMatrix(size)
    self.projectionMatrix:setOrthographicMatrix(self.fov, size or 5, self.nearClip, self.farClip, self.aspectRatio)
end

-- simple first person camera movement with WASD
-- put this local function in your love.update to use, passing in dt
    --need to 
function ThreeDee:firstPersonMovement(dt, inputs)
    -- collect inputs
    local moveX, moveY = 0, 0
    local selfMoved = false
    local speed = self.speed or 1
    if inputs["w"] then moveX = moveX + 1 end
    if inputs["a"] then moveY = moveY + 1 end
    if inputs["s"] then moveX = moveX - 1 end
    if inputs["d"] then moveY = moveY - 1 end
    if inputs["space"] then
        self.position[3] = self.position[3] + speed*dt
        selfMoved = true
    end
    if inputs["lshift"] then
        self.position[3] = self.position[3] - speed*dt
        selfMoved = true
    end

    -- do some trigonometry on the inputs to make movement relative to self's direction
    -- also to make the player not move faster in diagonal directions
    if moveX ~= 0 or moveY ~= 0 then
        local angle = math.atan2(moveY, moveX)
        self.position[1] = self.position[1] + math.cos(self.direction + angle) * speed * dt
        self.position[2] = self.position[2] + math.sin(self.direction + angle) * speed * dt
        selfMoved = true
    end

    -- update the self's in the shader
    -- only if the self moved, for a slight performance benefit
    if selfMoved then
        self:lookInDirection()
    end
    return selfMoved;
end

-- use this in your love.mousemoved function, passing in the movements
function ThreeDee:firstPersonLook(dx,dy)
    -- capture the mouse
    -- love.mouse.setRelativeMode(true)

    local sensitivity = 1/300
    self.direction = self.direction - dx*sensitivity
    self.pitch = math.max(math.min(self.pitch - dy*sensitivity, math.pi*0.5), math.pi*-0.5)

    self:lookInDirection(self.position[1],self.position[2],self.position[3], self.direction,self.pitch)
end

return ThreeDee;