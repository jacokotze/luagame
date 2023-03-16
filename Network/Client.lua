Object = require "classic/classic"
socket = require("socket")
require("Lib.json")



local function ucwords(words)
    final = ""
    for word in words:gmatch("([^_]*)") do
        final = final .. word:sub(1,1):upper() .. word:sub(2);
    end
    return final
end

local Client = Object:extend()
Client.JSON_START = "__{START}__"
Client.JSON_END = "__{END}__"

function Client:encodeMessage(message)
    return Client.JSON_START..json.encode(message)..Client.JSON_END;
end

function Client:new()
    self.buffer = '';
    self.identity = 'identity:archangel075:password';
    self.uuid = uuid(self.identity);
end

function Client:handle( message )
    if (message.event) then
        if( message.event == "RPC" ) then
            self:RPC(message.method,unpack(message.args))
        end
        if (message.event == "NetworkUpdate") then
            --received some state of the server world. we must replicate :
            --[[
                just call network update, this should spawn all initial objects
                once done we should also have access to the ClientPlayer on THIS client /
                as ClientPlayer autodetects a spawn of THIS clients player object and handles such a case.
            ]]
            self:NetworkUpdate(message.data);
        end
    end
end

function Client:NetworkUpdate(data)
    print("NETWORK UPDATE PROCESSING.........")
    --seed players
    -- Game.Context.Players = Game.Context.Players;
    --[[
        In future all objects will be placed in {data}
        should instead make a static method on all objects;
        a message must declare the CLASS of the object (fully qualified dot or slash notation. ucwords)
        Attempt to GET that class.
        Next attempt to find in the Things that object by uuid
            IF object is not found then we must Instantiate the object and call Seed(obj_data)
            ELSE call on that object NetworkUpdate()
        Alternatively an RPC will attempt to find objects by UID and call.
            IF the object does not exist. we need to request that object and backlog the RPC call until the object is spawned.
    ]]
    for uuid,object_data in pairs(data) do
        object_data.uuid = uuid;
        --first determine the objects Class :
        --!NOTE! FOR NOW we assume classes are all stored on root Blueprints.
        --  in future would want to resolve the qualified name and discover.
        if(object_data._class and Game.Blueprints[object_data._class]) then
            --does obj exit already in the game?
            --  again there could be a grouping system here. perhps storing objects in Things by qualified name.
            --  this will make lookups by type faster, though strict UID lookup on a global table is justifiably fast enough? maybe.
            if(Game.Things[uuid] and Game.Things[uuid].NetworkUpdate) then
                print("handover to object to update itself...")
                Game.Things[uuid]:NetworkUpdate(object_data);
            else
                print("spawn a new object... [" .. object_data._class .. "]",Game.Blueprints[object_data._class]);
                new_obj = Game.Blueprints[object_data._class](nil)
                new_obj.uuid = uuid;
                print('new_object :',new_obj)
                assert(new_obj.is and new_obj:is(Game.Blueprints[object_data._class]), ' object failed to spawn ');
                new_obj:NetworkSpawn(object_data);
                Game.Things[uuid] = new_obj;
                if(new_obj.OnNetworkSpawn) then new_obj:OnNetworkObjectSpawn() end
            end
        else
            error("Object network updating did not declare a class or class unknown [" .. tostring(object_data._class) .. "]")
        end
    end
end

function Client:send(message)
    --[[
        detect SPAWN, buffer
        detect RPC on a SPAWN object (RPC should occur in order they are originally pushed.)
        TODO : add buffering to messages each frame
    ]]
    local send_result, message, num_bytes = self.socket:send(Client.JSON_START..json.encode(message)..Client.JSON_END)
    if (send_result == nil) then
        print("transmit error: "..message..'  sent '..num_bytes..' bytes');
        if (message == 'closed') then  error("failed to send to closed connection") end
        return false;
    end
    return true
end

function Client:keypressed(key, scancode)
    self.Player:keypressed(key);
    -- self:send({
    --     event="kp",
    --     key=key
    -- })
end

function Client:keyreleased(key, scancode)
    -- self:send({
    --     event="kr",
    --     key=key
    -- })
end

function Client:receive()
    local input,output = socket.select({ self.socket },nil, 0)
    for k,v in ipairs(input) do

        local _buffer_not_empty = false;
        while  true  do
            local data, err, partial = v:receive()
            if (data) then  self.buffer = self.buffer .. data;  _buffer_not_empty=true;  end
            if (partial) then  self.buffer = self.buffer .. partial;  _buffer_not_empty=true;  end
            if (not data) then break; end
            if (err) then break; end
        end -- /while-do
        

        while _buffer_not_empty do
            local start = string.find(self.buffer,Client.JSON_START)
            local finish = string.find(self.buffer,Client.JSON_END)
            if (start and finish) then -- found a message!
                local message = string.sub(self.buffer, start+11, finish-1)
                self.buffer = string.sub(self.buffer, 1, start-1)  ..   string.sub(self.buffer, finish + 9 ) -- cutting our message from buffer

                print("====")
                print(message)
                print("====")

                local data = json.decode(message)
                self:handle(  data  )
            else
                break
            end
        end

    end
end

function Client:start()
    self.socket,err = socket.connect('127.0.0.1',1337)
    if(err) then error(err) end
    self.socket:settimeout(0)
    r = self:send({handshake="1234",identity=self.uuid})
    print("handshake sent!",r)
    return true;
end

function Client:update()
    self:receive();
    -- self:dispatch()
    -- self:inlet() 
    payload = {}
    data_to_send = false;
    -- for uuid,obj in pairs(Game.Things) do
    --     if obj.dirty then
    --         if obj.NetworkUpdateClient then
    --             data_to_send = true;
                 
    --             obj_payload = obj:NetworkUpdateClient()
    --             obj_payload._class = obj._class;
    --             payload[obj.uuid] = obj_payload;
    --         end
    --     end
    -- end
    -- if data_to_send then self:send()

end



return Client;
