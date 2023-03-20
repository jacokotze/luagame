Object = require "classic/classic"
local Voxel = Object:extend()
Voxel._class = "Voxel";

function Voxel:new(x,y)
    self.x = x or 0;
    self.y = y or 0;
    self.uuid = uuid(tostring(self));
    if(Game.isServer) then self:makeDirty() end --force send to clients
end

function Voxel:__tostring()
    return "Voxel(" .. tostring(self.x) .. ","..tostring(self.y)..",0)";
end

function Voxel:draw()
    if(Game.isClient) then
        self.model:draw();
    end
end

function Voxel:update(dt)
    
end

function Voxel:NetworkSpawn(data)
    print("spawned voxel!!!! [" .. data.uuid .. "]")
    self.uuid = data.uuid;
    -- if(Game.isClient) then
        --spawning for client:
        self.x = data.x
        self.y = data.y
        local cube = Game.g3d.newModel("GFX/Models/cube.obj", "GFX/Textures/dirt/dirt_01.png", {self.x,self.y,0})
        self.model = cube;
        self.type = "dirt";
    -- end
end

function Voxel:NetworkUpdate(data)
    --server does not get a network update
    if(Game.isClient) then
        print("updating self...")
        self.x = data.x;
        self.y = data.y;
    end
end

function Voxel:makeDirty()
    print(self._class,self.uuid,"MARKED DIRTY")
    self.dirty = true;
end

function Voxel:Serialize()
    data = {}
    data.x = self.x
    data.y = self.y
    return data;
end

function Voxel:RPC(method,...)
    assert(Game.isClient, 'Only Clients can perform a RPC');
    message = {}
    message['event']    = "RPC";
    message['uuid']     = self.uuid;
    message['_class']   = self._class;
    message['method']   = method;
    message['args']     = {...}
    Game.Client:send(message);
end

return Voxel;