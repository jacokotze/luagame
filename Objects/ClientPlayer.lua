Player = require("Objects.Player")

local ClientPlayer = Player:extend()

function ClientPlayer:new(me)
    self.me = me or false;
end

function ClientPlayer:spawn(...)
    --copy to self those fields and states from var_arg
end

function ClientPlayer:RPC(method,...)
    if(self[method] and type(self[type]) == 'function') then
        self[method](self,...)
    end
end

function ClientPlayer:handleMessage( message )

    

end

function ClientPlayer:keypressed( message )
    
    

end

function ClientPlayer:keyreleased( message )

    

end

return ClientPlayer;