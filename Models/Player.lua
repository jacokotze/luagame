-- Object = require "classic/classic"
Query = require("Builder")
Model = require("Model");
Item = require("Models/Item")

local Player = Model:extend()

Player.primary_key = 'id';
Player.columns = {
    'id',
    'name',
    'password'
}
Player.fillable = {
    'id',
    'name',
    'password',
}
Player.table = "Player";

function Player:__tostring()
    return "Model<Player>";
end

function Player:new()
    Player.super.new(self)
    self._items = {};
    self:hasManyThrough("items",Item,'item_player','player_id','item_id','id','id');
end

return Player;