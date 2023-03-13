-- Object = require "classic/classic"
Query = require("Builder")
Model = require("Model");

local Position = Model:extend()

Position.primary_key = 'id';
Position.columns = {
    'id',
    'x',
    'y',
    'z',
    'dim'
}
Position.fillable = {
    'id',
    'x',
    'y',
    'z',
    'dim'
}
Position.table = "Position";

function Position:__tostring()
    return "Model<Position>";
end

function Position:new()
    Position.super.new(self)
    -- self:hasManyThrough("items",Item,'item_Position','Position_id','item_id','id','id');
end

return Position;