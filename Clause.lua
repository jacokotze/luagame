Object = require "classic/classic"

local Clause = Object:extend()
Clause.db = nil;

function Clause:new()
    self.statement = nil;
    self.bindings = {};
    self.children = {};
    self.col = nil;
    self.opr = nil;
    self.val = nil;
    print("new clause...","\n");
end

function Clause:bind(that, forceWithoutPK)
    forceWithoutPK = forceWithoutPK or false;
    if(type(that) == "table") then
        for k,v in pairs(that) do
            if type(v) == "nil" then that[k] = SqlNull(); end
            table.insert(Clause.bindings,that[k]);
        end
    else
        table.insert(Clause.bindings,that);
    end
    return Clause;
end

function Clause:where(col, operator, val, and_or)
    and_or = and_or or "AND"
    if val then
        _operator = operator;
        _val = val;
    else
        _operator = "=";
        _val = operator
    end
    table.insert(Clause._where, {col=col,operator=_operator,val=_val, and_or=and_or});
    return Clause;
end

function Clause:andWhere(col,operator,val)
    if val then
        _operator = operator;
        _val = val;
    else
        _operator = "=";
        _val = operator
    end
    return Clause:where(col,_operator,_val,"AND")
end

function Clause:orWhere(col,operator,val)
    if val then
        _operator = operator;
        _val = val;
    else
        _operator = "=";
        _val = operator
    end
    return Clause:where(col,_operator,_val,"OR")
end

function Clause:whereIn(col, val, and_or)
    and_or= and_or or "AND"
    table.insert(Clause._where, {col=col,operator="IN",val=val, and_or=and_or});
    return Clause;
end

function Clause:orWhereIn(col, val)
    return Clause:whereIn(col,val,"OR")
end

function Clause:andWhereIn(col, val)
    return Clause:whereIn(col,val,"AND")
end

function Clause:leftJoin(what, whatColumn, comp, onColumn)
    table.insert(Clause.joins, "LEFT JOIN " .. what .. ' ON ' .. whatColumn .. ' ' .. comp .. ' ' .. onColumn);
    return Clause
end

local function arg_count(args)
    col_count = 0;
    for k,v in pairs(args) do
        col_count = col_count + 1;
    end
    return col_count;
end

function Clause:__tostring(ln)
    ln = ln or "\n"
    return "Query {" .. ln .. Clause:make().statement .. ln .. "}"; 
end

function Clause:getBindings()
    out = ""
    line  = "";
    for k,v in pairs(Clause.bindings) do 
        line = line .. tostring(v) .. ", "
    end
    line = string.sub(line,1,#line-2);
    out = out .. line
    return out
end
return Clause;