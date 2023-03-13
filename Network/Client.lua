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

function Client:new()
    self.buffer = {};
    self.identity = 'identity:archangel075:password';
    self.uuid = uuid(self.identity);
    self.ClientPlayer = ClientPlayer(true)
    self.ClientPlayer.identity = self.uuid;
    ClientPlayer.ThisPlayer = self;
    Game.Context.ThisClient = self;
end

function Client:handle( packet )
    if (message.event) then
        if( message.event == "RPC" ) then
            self:RPC(message.method,unpack(message.args))
        end
        if (message.event == "SEED") then
            --received some state of the server world. we must replicate :
            print("Seed the first state of world")
            self:Seeding(message.data);
        end
    end
end

function Client:Seeding(data)
    --seed players
    Game.Context.Players = {};
    for k,player_data in pairs(data.Players) do
        local player = ClientPlayer(false)
        player.uuid = player_data.uuid
        table.insert(Game.Context.Players,player)
        player:spawn(player_data);
    end
end

function Client:send(message)
    local send_result, message, num_bytes = self.socket:send(Client.JSON_START..json.encode(message)..Client.JSON_END)
    if (send_result == nil) then
        print("transmit error: "..message..'  sent '..num_bytes..' bytes');
        if (message == 'closed') then  error("failed to send to closed connection") end
        return false;
    end
    return true
end

function Client:keypressed(key, scancode)
    self:send({
        event="kp",
        key=key
    })
end

function Client:keyreleased(key, scancode)
    self:send({
        event="kr",
        key=key
    })
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

end



return Client;
