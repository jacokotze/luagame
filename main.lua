local md5 = require('Lib.md5.md5')
require("sqlite3");
Query = require("builder")
Test = require("Models/Test")
Player = require("Models/Player")
Item = require("Models/Item")
Server = nil;
Client = nil;
Game = {}
Game.Object = require "classic/classic"
Game.Blueprints = {};
--[[
    load all classes and blueprints :
]]
local _files = love.filesystem.getDirectoryItems( 'Objects' )
for k,v in pairs(_files) do 
    local info = love.filesystem.getInfo('Object/'..v)
    file_name = string.sub(v,1,string.find(v,'.lua')-1);
    print("discovered Object [".. file_name .."] from filename [" .. v .. ']');
    Game.Blueprints[file_name] = require("Objects." .. file_name);
    print("Registered a Object [".. file_name .."] from filename [" .. v .. ']');
end
Game.isServer = false;
Game.isClient = false;
Game.Things = {};
local db = sqlite3.open("testing.db");

function uuid(this)
    str = md5.sumhexa(this);
    part_size = 8
    size = math.ceil(str:len() / part_size)
    parts = {};
    for i = 1,size do
        part = str:sub(i*part_size-part_size,i*part_size-1)
        table.insert(parts,part);
    end
    return table.concat(parts,'-')
end

function prettyPrint(result)
    print(table.concat(result.header,",\t| "));
    for k,v in pairs(result.rows) do
        print(table.concat(v,"\t| "));
    end
end

function love.load(args)
    local htype = args[1] or 'client'
    if(htype == "client") then
        Client = require("Network.Client")

        Game.isClient = true;
        Game.Client = Client();
    else
        Server = require("Network.Server")

        Game.isServer = true;
        Game.Server = Server();
    end

    Query.db = db;

    -- print("\n---------\nnow select back the elements\n----------\n")

    -- print("get potatos")
    -- myPotatos = Player:find(1):items():where("name","POTATO"):execute()
    -- for k,potato in pairs(myPotatos) do
    --     print(potato);
    --     print(potato:getName())
    -- end

    if(Game.isClient) then
        Game.Client:start()
    end
    if(Game.isServer) then
        Game.Server:start()
    end
end
    
function love.draw()


end

function love.keypressed(key, scancode)
    if(Game.isClient and Game.Client.keypressed) then
        Game.Client:keypressed(key,scancode)
    end
    if(Game.isServer and Game.Server.keypressed) then
        Game.Server:keypressed(key,scancode)
    end
end

function love.keyreleased(key, scancode)
    if(Game.isClient and Game.Client.keyreleased) then
        Game.Client:keyreleased(key,scancode)
    end
    if(Game.isServer and Game.Server.keyreleased) then
        Game.Server:keyreleased(key,scancode)
    end
end

function love.update(dt)
    if(Game.isClient) then
        Game.Client:update()
    end
    if(Game.isServer) then
        Game.Server:update()
    end
end