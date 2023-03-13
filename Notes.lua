-- Object = require "classic/classic"
Model = require("Model");

local Notes = Model:extend()

Notes.primary_key = 'id';
Notes.columns = {
    'id',
    'text',
    'test_id'
}
Notes.fillable = {
    'id',
    'text',
    'test_id'
}
Notes.table = "NOTES";

function Notes:__tostring()
    return "Model<Note>";
end

return Notes;