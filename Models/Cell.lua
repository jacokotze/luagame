-- Object = require "classic/classic"
Model = require("Model");

local Cell = Model:extend()

Cell.primary_key = 'id';
Cell.columns = {
    'id',
    'x',
    'y',
}
Cell.fillable = {
    'id',
    'x',
    'y',
}
Cell.table = "Cells";

function Cell:__tostring()
    return "Model<Cells>";
end

return Cell;