Object = require "classic/classic"

local Channel = Object:extend()

function Channel:new(name)
    self.name = name
    self.subscribers = {};
end

function Channel:subscribe(f_)
    name = uuid(tostring(f_));
    self.subscribers[name] = f_;
    return name;
end

function Channel:unsubscribe(name)
    self.subscribers[name] = nil;
end

function EventBus:trigger(...)
    for k,f_ in pairs(self.subscribers) do
        if(f_) then
            f_(unpack({...}));
        end
    end
end

return Channel
