Object = require "classic/classic"
Channel = require("Lib.EventBus.Channel")

local EventBus = Object:extend()

function EventBus:new()
    self.channels = {};
end

function EventBus:register(channel_name)
    self.channels[channel_name] = Channel(channel_name);
    return self.channels[channel_name];
end

function EventBus:trigger(channel,...)
    self.channels[channel_name]:trigger(...);
end


return EventBus
