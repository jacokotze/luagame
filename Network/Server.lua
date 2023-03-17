Object = require "classic/classic"
socket = require("socket")
require("Lib.json")
ServerPlayer = require("Objects.ServerPlayer");

local function ucwords(words)
    final = ""
    for word in words:gmatch("([^_]*)") do
        final = final .. word:sub(1,1):upper() .. word:sub(2);
    end
    return final
end

local Server = Object:extend()
Server.JSON_START = "__{START}__"
Server.JSON_END = "__{END}__"

function Server:encodeMessage(message)
    return Server.JSON_START..json.encode(message)..Server.JSON_END;
end

function Server:start(as)
    self.Game = Game; --quick ref.
    self.peers = {
        unknown = {},
        inactive = {},
        active = {},
    }

    self.buffer = "";

    self.socket, err = socket.bind(as or '*',1337)
    if(err) then error(err) end
    if(not self.socket) then error("failed to make server socket?") end
    --place holder for now. just return true to indicate server has "Started"
    print("server bound")
    return true;
end

function Server:HandleRPC( message , from ) 
--[[
    call the method locally on the object in question.
    --the object should mark dirty if needed. its Serialize method should manage preparing it etc...
]]
    if(message._class and Game.Blueprints[message._class]) then
        --does obj exist already in the game?
        --  again there could be a grouping system here. perhps storing objects in Things by qualified name.
        --  this will make lookups by type faster, though strict UID lookup on a global table is justifiably fast enough? maybe.
        if( Game.findThing(message.uuid) ) then
            local thing = Game.findThing(message.uuid);
            if( thing[message.method] ) then
                print("RPC on object [" .. message._class .. "]:" .. message.method .. "()");
                thing[message.method](thing,unpack(message.args));
            else
                print("no such method [" .. message._class .. "]:" .. message.method .. "()");
            end
        else
            print("no such method [" .. message.uuid .. "]")
        end
    else
        print("no such object type [" .. message._class .. "]");
    end
end

function Server:newUuid(prefix)
    return uuid((prefix or '')..tostring(os.clock()))
end

function Server:handle( message , from )
    --[[
        TODO:
        know that if something is CREATED/SPAWNED bt client, it might have RPC calls.
        keep that object in a CREATED_THIS_FRAME buffer.
        
        detect a RPC on objects recently created this frame and update the UUID.

        should propose a Game.GetThing()

        should take a uuid - attempt to find the thing by uuid.
        BUT first check if the uuid was renamed by a recent create/spawn. returning the swapped uuid
        then continue to retrieve.

        Game.resolveUUID() can helper as a check against swaps and return the true uuid.
    ]]
    if( message.handshake and message.handshake == "1234") then
        print("peer successfully handshaked",from)
        print('from is peer 1?')
        index = false
        for k,v in pairs(self.peers.unknown) do
            if(v.socket == from.socket) then index = k end
        end
        peer = table.remove(self.peers.unknown,index)
        peer.uuid = message.identity;
        self.peers.active[peer.uuid] = peer;
        new_player = Game.Blueprints.Player(peer);
        new_player.uuid = peer.uuid;
        Game.Things[peer.uuid] = new_player;
        print("peer moved to active list")
        peer.Player = new_player;
        self:seedPlayerContext(peer);
        return;
    end

    if( message.event == "RPC" ) then
        self:HandleRPC(message, from)
        return;
    end

    if( message.event == "CREATE" ) then
        --Create the object. swap the UUID and issue a "SWAP" immediately to the client.
        if(message._class and Game.Blueprints[message._class]) then
            local new_uuid = self:newUuid();
            Game.addSwap(message.uuid,obj.uuid); -- from here on any reference to incoming uuid is redirected to new uuid;

            Game.Things[new_uuid] = Game.Blueprints[message._class]();
            obj.uuid = new_uuid; 

            if Game.Things[new_uuid].NetworkSpawn then Game.Things[new_uuid]:NetworkSpawn() end
            local create_message = {
                event = "CREATED",
                from = message.uuid,
                uuid = new_uuid
            }
            self:broadcast(create_message);
        end
    end

    if( message.event == "BUFFERED" ) then
        for k,queued_message in pairs(message.payload) do self:handle(queued_message,from) end
        return;
    end

    --check for client doing some activity?
    
    print("unknown message")
    for k,v in pairs(message) do
        print(k,v)
    end
    error("unknown message")
end

function Server:seedPlayerContext(peer)
    print("seeding to spawning player")
    message = {
        event = "NetworkUpdate",
        data = {};
    }
    --[[
        in future this should use the relavancy check - is each object relevant to this player?
        Only relevant objects are seeded. this is to cut down on uneeded transmissions.
    ]]
    --seed players, items etc important to the players current location?
    for uuid,peer in pairs(self.peers.active) do
        --again, in future the Object should handle the encoding and message that is send here
        --for now we will simply send the existance of the object?
        local obj = Game.findThing(uuid);
        local player = {
            _class = obj._class or error("Object must declare class")
        }
        message.data[obj.uuid]=player;
        --[[
            disabled the beneath as preferably would want the player to keep its ClientPlayer
            inside the same scope as other objects.
            Simply the reference TO the ClientPlayer is copied. 
        ]]
        -- if obj ~= peer then table.insert(message.data.Players,player) end
    end
    message = self:encodeMessage(message);
    peer.socket:send(message);
end

function Server:getSocketsFrom(from)
    local peers = {}
    for k,v in pairs(from) do table.insert(peers,v.socket) end
    return peers;
end

function Server:socketToPeer(socket,peers)
    for k,v in pairs(peers) do
        if v.socket == socket then return v end
    end
    return false;
end

function Server:receive(from)
    -- print("receiving...")
    local input,output = socket.select(self:getSocketsFrom(from),nil, 0)
    for k,v in ipairs(input) do
        peer = self:socketToPeer(v,from);
        if peer then 
            local _buffer_not_empty = false;
            while true do
                print("receive next chunk")
                v:settimeout(0.05);
                local data, err, partial = v:receive()
                print("data,err,partial",data,err,partial);
                if (data) then  self.buffer = self.buffer .. data;  _buffer_not_empty=true;  end
                if (partial) then  self.buffer = self.buffer .. partial;  _buffer_not_empty=true;  end
                if (not data) then break; end
                if(err and err == 'timeout') then print("no more data in incoming; timeout"); break end
                if (err) then error(err); end
            end
            
            while _buffer_not_empty do
                print("process buffer")
                local start = string.find(self.buffer,Server.JSON_START)
                local finish = string.find(self.buffer,Server.JSON_END)
                if (start and finish) then -- found a message!
                    print('start and finish')
                    local message = string.sub(self.buffer, start+11, finish-1)
                    self.buffer = string.sub(self.buffer, 1, start-1)  ..   string.sub(self.buffer, finish + 9 ) -- cutting our message from buffer
                    local data = json.decode(message)
                    self:handle(  data, peer  )
                else
                    print("no more messages in buffer")
                    break
                end
            end
        else
            print("unable to determine peer");
        end

    end
end

function Server:accept()
    self.socket:settimeout(0.001);
    peer,err = self.socket:accept();
    if(not peer and err) then
        if err == "timeout" then
            return;
        end
        error(err)
    end
    
    readable,writable,err = socket.select(nil,{ peer },0)
    if not err then
        print("peer connected. will await handshake!");
        table.insert(self.peers.unknown,{socket=peer})
    else
        if(err == "timeout") then
            peer:shutdown()
            print("client failed to connect to me!")
            return
        end
    end
end

function Server:send(message, socket)
    local send_result, message, num_bytes = socket:send(Server.JSON_START..json.encode(message)..Server.JSON_END)
    if (send_result == nil) then
        print("transmit error: "..message..'  sent '..num_bytes..' bytes');
        if (message == 'closed') then  error("failed to send to closed connection") end
        return false;
    end
    return true
end

function Server:broadcast(payload, excluded)
    for uuid,peer in pairs(self.peers.active) do
        self:send(payload, peer.socket);
    end
end

function Server:update(dt)
    self:accept() 
    -- print("receive from unknowns:")
    self:receive(self.peers.unknown)
    -- print("-------------------------------------")
    -- print("receive from actives:")
    self:receive(self.peers.active)
    -- print("-------------------------------------")
    -- self:dispatch()
    for uuid,obj in pairs(Game.Things) do
        if obj.update then obj:update(dt) end
    end

    message = {
        event = "NetworkUpdate",
        data = {};
    }
    data_to_send = false;
    for uuid,obj in pairs(Game.Things) do
        if obj.dirty then
            if obj.Serialize then
                data_to_send = true;
                obj_payload = obj:Serialize()
                obj_payload._class = obj._class;
                message.data[obj.uuid] = obj_payload;
            end
            obj.dirty = false;
        end
    end
    if data_to_send then self:broadcast(message); print(">>broadcasted<<") end
end



return Server;
