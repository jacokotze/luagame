PlayerModel = require("Models.Player")

local Player = Game.Object:extend()
Player._class = "Player";

function Player:new(peer)
    self.peer = peer or false;
    self.keystates = {}
    self.dirty = false;
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
        print("updating self...")
        self.keystates = data;
    else
        return false
    end
end

function Player:makeDirty()
    print(self._class,self.uuid,"MARKED DIRTY")
    self.dirty = true;
end

function Player:keypressed( key )
    if Game.isClient and self.me then
        self.keystates[key] = true;
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

function Player:Serialize()
    data = {}
    data.keystates = self.keystates
    
    return data;
end

function Player:keyreleased( message )


end

function Player:RPC(method,...)
    assert(Game.isClient, 'Only Clients can perform a RPC');
    message = {}
    message['event']    = "RPC";
    message['uuid']     = self.uuid;
    message['_class']   = self._class;
    message['method']   = method;
    message['args']     = {...}
    Game.Client:send(message);
end

return Player;