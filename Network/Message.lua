Object = require "classic/classic"

local Message = Object:extend()
Message._HEAD = "__{START}__"
Message._identity = 0;
Message._messages = {};

function Message.bytesToInteger(bytes)
    local a,b,c,d;
    a = (256*256*256*string.byte(bytes,1));
    b = (256*256*string.byte(bytes,2));
    c = (256*string.byte(bytes,3));
    d = (string.byte(bytes,4));
    return a + b + c + d;
end

function Message:encode(data)
    local bytes = {};
    for key,descriptor in pairs(self.structure) do
        if not data[key] then error("contract not met") end
        
    end
end

function Message:new()
    self.structure = {};
    self._identity = Message._identity;
    
    self._messages[self.identity] = self;
    Message._identity = Message._identity + 1;
end

function Message:define(type,key,meta)
    local meta = meta or false
    self.structure[key] = {type=type,meta=meta};
end




return Message
