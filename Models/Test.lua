-- Object = require "classic/classic"
Model = require("Model");

local Test = Model:extend()

Test.primary_key = 'id';
Test.columns = {
    'id',
    'name',
}
Test.fillable = {
    'id',
    'name',
}
Test.table = "test";

function Test:__tostring()
    return "Model<Test>";
end

return Test;