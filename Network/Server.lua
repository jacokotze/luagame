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

function Server:start()
    self.peers = {
        unknown = {},
        inactive = {},
        active = {},
    }

    self.buffer = "";

    self.socket, err = socket.bind('*',1337)
    if(err) then error(err) end
    if(not self.socket) then error("failed to make server socket?") end
    --place holder for now. just return true to indicate server has "Started"
    print("server bound")
    return true;
end

function Server:handle( message , from )
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
        print("peer moved to active list")
        peer.Player = ServerPlayer(peer);
        self:seedPlayerContext(peer);
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
        event = "SEED",
        data = {};
    }
    message.data.Players  = {}
    --seed players, items etc important to the players current location?
    for k,v in pairs(self.peers.active) do
        local player = {
            identity = v.uuid;
        }
        if v ~= peer then table.insert(message.data.Players,player) end
    end
    peer:send(message);
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
        if(#self.peers.unknown > 0) then
            print("receive from unknown:",k,self.peers.unknown[1].socket == from[1], v == from[1], v == self.peers.unknown[1].socket);
        end
        if(#self.peers.active > 0) then
            print("receive from active:",k,self.peers.active[1].socket == from[1], v == from[1], v == self.peers.active[1].socket);
        end
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

function Server:update()
    self:accept() 
    -- print("receive from unknowns:")
    self:receive(self.peers.unknown)
    -- print("-------------------------------------")
    -- print("receive from actives:")
    self:receive(self.peers.active)
    -- print("-------------------------------------")
    -- self:dispatch()
end



return Server;