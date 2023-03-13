-- Object = require "classic/classic"
Model = require("Model");

local Item = Model:extend()

Item.primary_key = 'id';
Item.columns = {
    'id',
    'name',
}
Item.fillable = {
    'id',
    'name',
}
Item.table = "Item";

function Item:__tostring()
    return "Model<Item>";
end

return Item;