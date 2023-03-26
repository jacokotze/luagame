PlayerModel = require("Models.Player")

local Player = Game.Object:extend()
Player._class = "Player";

function Player:new(peer)
    self.peer = peer or false;
    self.keystates = {}
    self.dirty = false;
    self.position = {0,0,0}
    self.direction = 0;
    self.pitch = 0;
    -- self.threedee = Game.Blueprints.ThreeDee();
    if Game.isClient or Game.isServer then
        self.pitch = 0;
        self.direction = 0;
        self._pitchAccumulator = 0;
        self._directionAccumulator = 0;

        self.camA = Game.g3d.camera.current();
        self.camB = Game.g3d.camera.newCamera();
        self.camB.position = {0,0,0}
        self.camera = "camA";
        --load the player blender model :
        local blend_obj = Game.g3d.loadObj('GFX/Models/human3.obj',true,true);
        local cube = Game.g3d.newModel(blend_obj, "GFX/Textures/ClothedLightSkin.png", {0,0,0})
        self.model = cube;
        self.model:setScale(0.5,0.5,0.5)
    end
end


function Player:isPressed(key)
    return self.keystates[key] or false;
end

function Player:draw()
    self.model:draw();
end

function Player:update(dt)
    -- local dt = 0.005
    local forwards = self.model:getDirection({1,0,0});
    local tx = self.model.translation[1]
    local ty = self.model.translation[2]
    local tz = self.model.translation[3]

    -- local rx,ry,rz,rw = self.model:getRotation():unpack()

    local rx = self.model.rotation[1]
    local ry = self.model.rotation[2]
    local rz = self.model.rotation[3]
    local rw = nil

    local fx,fy,fz = forwards:scale(dt):unpack()

    if(self:isPressed('w')) then
        self.model:setTranslation( tx+fx , ty+fy, tz+fz );
    end

    if(self:isPressed('s')) then
        self.model:setTranslation( tx-fx , ty-fy, tz-fz );
    end

    -- if(self:isPressed('q')) then
    --     self.model:setRotation(rx,ry,rz-dt,rw)
    -- end
    -- if(self:isPressed('e')) then
    --     self.model:setRotation(rx,ry,rz+dt,rw)
    -- end

    if(Game.isClient and self.me) then
        local hx = 0
        local hy = 0
        local hz = 0.52

        self.camB:lookInDirection(
            self.model.translation[1]+hx,
            self.model.translation[2]+hy,
            self.model.translation[3]+hz, 
            rz,
            self.pitch+rx
        )
        
        -- self.camB:lookAt(
        --     self.model.translation[1]+hx,self.model.translation[2]+hy,self.model.translation[3]+hz,
        --     self.model.translation[1]+hx+fx,self.model.translation[2]+hy+fy,self.model.translation[3]+hz+fz
        -- )
    end
end

function Player:NetworkSpawn(data)
    print("spawned player!!!! [" .. data.uuid .. "]")
    self.uuid = data.uuid;
    
    if(Game.isClient and Game.Client.uuid == data.uuid) then
        print("was me!")
        Game.Client.Player = self;
        self.me = true
    else
        
        self.me = false
    end
end

function Player:NetworkUpdate(data)
    --server does not get a network update
    if(Game.isClient) then
        self.keystates = data.keystates;
        -- self.model:setTransform(data.translation,data.rotation, self.model.scale);
        self.model:setTranslation(data.translation[1],data.translation[2],data.translation[3])
        self.model:setRotation(data.rotation[1],data.rotation[2],data.rotation[3],data.rotation[4])
        self.direction = data.direction;
        self.pitch = data.pitch;
    end
end

function Player:makeDirty()
    print(self._class,self.uuid,"MARKED DIRTY")
    self.dirty = true;
end

function Player:mousemoved(x,y,dx,dy)
    if type(x) == "table" then x,y,dx,dy = unpack(x) end
    local sensitivity = 1/300
    self.direction = self.direction - dx*sensitivity
    self.pitch = math.max(math.min(self.pitch - dy*sensitivity, math.pi*0.5), math.pi*-0.5)

    local rx = self.model.rotation[1]
    local ry = self.model.rotation[2]
    local rz = self.model.rotation[3]
    local rw = nil
    self.model:setRotation(rx,ry,self.direction,rw)


    if Game.isClient and self.me then
        self:RPC('mousemoved',{x,y,dx,dy});
    end
    if(Game.isServer) then
        --track accumulated pitch and direction.
        --when reaching a threshold, push back the accumulator and mark as dirty.
        --should thus cause an mark dirty based on the significance of mouse movement?
        self._pitchAccumulator = math.abs(dy)+self._pitchAccumulator
        self._directionAccumulator = math.abs(dx)+self._directionAccumulator
        local significant = false;
        local limit = 90;
        if(self._pitchAccumulator > limit*2) then
            self._pitchAccumulator = self._pitchAccumulator-(limit*2);
            significant = true;
        end
        if(self._directionAccumulator > limit) then
            self._directionAccumulator = self._directionAccumulator-limit;
            significant = true;
        end
        if(significant) then
            self:makeDirty()
        end
    end
end

function Player:keypressed( key )
    if Game.isClient and self.me then
        self.keystates[key] = true;

        if(key == 't') then
            if self.camera == 'camA' then self.camera = 'camB' else self.camera = 'camA' end
            Game.g3d.camera.setCurrent(self[self.camera]);
        end

        if(key == 'lgui') then
            self.captureMouse = self.captureMouse or false;
            self.captureMouse = not self.captureMouse
            love.mouse.setRelativeMode(self.captureMouse)
        end

        self:RPC('keypressed',key); -- send to server method call
        --[[
            spawn some object. perform some actions on it?
            spawning objects are buffered on the client in the current frame.
                they are given a temprary uuid until the server assigns a static one.
                locally any RPC calls will be buffered with the creation of the object on the server side.
                once the server assigns a uuid it will update client(s) with a "RENAME" flag.
                    an object is unsynced until it is renamed. clients can check if uuid starts with "_" for temporary state confirmation.
                SPAWN/CREATE is processed first. RPC following are updated with the new uuid and called in order of RPC call in the frame.
                this will thus respect method call order in a frame. (ie. create bullet. do stuff do stuff rpc something else -> then rpc bullet)
        ]]
    end
    if Game.isServer then
        print("server setting key state on player!",key,true)
        self.keystates[key] = true;
        self:makeDirty();
    end
end

function Player:keyreleased( key )
    if Game.isClient and self.me then
        self.keystates[key] = false;
        self:RPC('keyreleased',key); -- send to server method call
    end
    if Game.isServer then
        print("server setting key state on player!",key,true)
        self.keystates[key] = false;
        self:makeDirty();
    end
end

function Player:Serialize()
    data = {}
    data.keystates = self.keystates
    data.translation = self.model:getTranslation();
    -- data.rotation = {self.model:getRotation():unpack()};
    data.rotation = self.model.rotation;
    -- data.position = self.threedee.position
    data.direction = self.direction
    data.pitch = self.pitch
    return data;
end

function Player:RPC(method,...)
    assert(Game.isClient, 'Only Clients can perform a RPC');
    local message = {}
    message['event']    = "RPC";
    message['uuid']     = self.uuid;
    message['_class']   = self._class;
    message['method']   = method;
    message['args']     = {...}
    Game.Client:send(message);
end

return Player;