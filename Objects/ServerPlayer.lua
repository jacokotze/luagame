PlayerModel = require("Models.Player")

local ServerPlayer = require("Objects.Player"):extend()

function ServerPlayer:new(peer)
    self.peer = peer;
    self.position = {0,0}; --this is where query should grab the players position!
end

function ServerPlayer:keypressed( message )



end

function ServerPlayer:keyreleased( message )



end

function ServerPlayer:RPC(method,...)
    message = {}
    message['event'] = "RPC";
    message['uuid'] = self.peer.uuid;
    message['type'] = 'PLAYER';
    message['method'] = method;
    message['args'] = {...}
    Game.Server:send(message);
end

function ServerPlayer:handleMessage( message )

    if (message.event) then
        if( message.event == "kp" ) then
            self:keypressed(message.key);
        end
        if( message.event == "kr" ) then
            self:keyreleased(message.key);
        end
    end

end

return ServerPlayer;