QueryResult = require("QueryResults");
Object = require "classic/classic"
local SqlNull = Object:extend()
function SqlNull:__tostring()
    return "null"
end

local Query = Object:extend()
Query.db = nil;

function Query:new(table_name)
    self._table = table_name or nil
    self.type = "unknown"
    self.insert = ""
    self.joins = {}
    self._where = {}
    self._where_statement = {}
    self.selects = {}
    self.values = {}
    self.statement = nil;
    self.bindings = {}
    self.withPK = true;
    self.query = nil;
    self.db = Query.db;
    self._results = {}
    self._results_headers = nil;
    self._transformsTo = nil;
    print("construct new query...","\n")
end

function Query:setType(typ)
    self.type = typ;
    return self;
end

function Query:raw(statement)
    self.statement = statement;
    self.type = "raw"
    return self;
end

function Query:bind(that, forceWithoutPK)
    forceWithoutPK = forceWithoutPK or false;
    if(not forceWithoutPK) then
        if(self.withPK) then table.insert(self.bindings,SqlNull()) end
    end
    if(type(that) == "table") then
        for k,v in pairs(that) do
            if type(v) == "nil" then that[k] = SqlNull(); end
            -- print("inserted binding :",v);
            table.insert(self.bindings,that[k]);
        end
    else
        -- print("inserted binding :",that);
        table.insert(self.bindings,that);
    end
    return self;
end

function Query:inserts(into,...)
    local values = {...};
    if(self.type == "insert" or self.type == "unknown") then
        self.type = "insert"
        if(self._table == nil) then
            self:table(into);
        else
            table.insert(values,1,into);
        end
        for k,v in pairs(values) do
            self:value(v);
        end
        return self;
    else
        error("can not make insert statement")
    end
end

function Query:update(with)
    self._updates = with;
    self.type = "update";
    return self;
end

function Query:where(col, operator, val, and_or)
    and_or = and_or or "AND"
    if val then
        _operator = operator;
        _val = val;
    else
        _operator = "=";
        _val = operator
    end
    table.insert(self._where, {col=col,operator=_operator,val=_val, and_or=and_or});
    return self;
end

function Query:andWhere(col,operator,val)
    if val then
        _operator = operator;
        _val = val;
    else
        _operator = "=";
        _val = operator
    end
    return self:where(col,_operator,_val,"AND")
end

function Query:orWhere(col,operator,val)
    if val then
        _operator = operator;
        _val = val;
    else
        _operator = "=";
        _val = operator
    end
    return self:where(col,_operator,_val,"OR")
end

function Query:whereIn(col, val, and_or)
    and_or = and_or or "AND"
    table.insert(self._where, {col=col,operator="IN",val=val, and_or=and_or});
    return self;
end

function Query:orWhereIn(col, val)
    return self:whereIn(col,val,"OR")
end

function Query:andWhereIn(col, val)
    return self:whereIn(col,val,"AND")
end

function Query:leftJoin(what, whatColumn, comp, onColumn)
    table.insert(self.joins, "LEFT JOIN " .. what .. ' ON ' .. whatColumn .. ' ' .. comp .. ' ' .. onColumn);
    return self
end

local function arg_count(args)
    col_count = 0;
    for k,v in pairs(args) do
        col_count = col_count + 1;
    end
    return col_count;
end

function Query:value(...)
    assert(self.type == "insert", "unable to specify values for non-insert query")
    args = {...}
    count = arg_count(args);
    table.insert(self.values, {values=args,count=count});
    return self;
end

function Query:makeWheres()
    self.statement = self.statement or ""
    if(#self._where > 0) then self.statement = self.statement .. " WHERE "; end
    -- print("Make the where clauses")
    --resolve where clauses :
    made_wheres = {};
    first = true;
    for k,where in pairs(self._where) do
        if(not first) then and_or = " " .. where.and_or .. " "; else and_or = ""; first=false; end
        if(type(where.col) == "function") then
            error("unsupported atm")
        else
            if(where.operator == "IN") then
                count = arg_count(where.val)
                self.statement = self.statement .. and_or .. where.col .. " IN " .. '('.. string.rep('?',count,', ') .. ') ';
                for i,v in pairs(where.val) do
                    self:bind(v,true);
                end
            else
                self.statement = self.statement .. and_or .. where.col .. " " .. where.operator .. " ? " ;
                self:bind(where.val,true);
            end
        end
    end
    -- print("-----------------------")
    return self;
end

function Query:make(query)
    -- print("will be making the SQL...")
    self.statement = "";
    self.bindings = {};
    local statement = "";
    -- print("this statement type :",self.type)
    if(self.type == "insert") then
        statement = "INSERT INTO " .. self._table .. " VALUES ";
        for k,v in pairs(self.values) do
            line = '( ';
            if(self.withPK) then line = line .. "null, " end
            line = line .. string.rep('?',v.count,',') .. " ) , ";
            statement = statement .. line
            for i,binded in pairs(v.values) do self:bind(binded) end
        end
        statement = string.sub(statement,1,#statement-2);
    elseif self.type == "select" then
        -- print("as a select :")
        statement = "SELECT " .. table.concat(self.selects, ",") .. " FROM " .. self._table;
    elseif self.type == "update" then
        statement = "UPDATE " .. self._table .. " SET ";
        for k,v in pairs(self._updates) do
            statement = statement .. " " .. tostring(k) .. " = ?, ";
            self:bind(v,false);
        end
        statement = string.sub(statement,1,#statement-2) .. "\n";
    elseif self.type == "nested" then
        -- print("as a NESTED :")
        statement = ""
    else 
        error("unknown query type: " .. tostring(self.type));
    end
    self.statement = statement .. "\n";

    --add joins
    for k,v in pairs(self.joins) do
        self.statement = self.statement .. "\n" .. v;
    end

    self.statement = self.statement .. "\n";

    self:makeWheres();

    -- print(self.statement)

    return self;
end

function Query:database(database)
    self.db = database or Query.db;
end

function Query:build(query)
    self:make();
    -- print("prepared the statement\n"..self.statement.."\n")
    self.query = self.db:prepare(self.statement);
    prepare_message = self.db:error_message();
    if(prepare_message ~= "not an error") then
        error(prepare_message .. " => SQL `\n" .. tostring(self.statement) .. "\n`");
    end
    count = 1;
    for k,bound in pairs(self.bindings) do
        -- print("will bind [" .. tostring(bound) .. " @ " .. tostring(count) .. "]")
        count = count + 1
    end

    -- print("\n");

    count = 1;
    for k,bound in pairs(self.bindings) do
        if(tostring(bound) ~= "null") then
            -- print("binding [" .. tostring(bound) .. " @ " .. tostring(count) .. "]")
            bound_result = self.query:bind(count,tostring(bound))
            assert(bound_result == sqlite3.OK,"failed to bind [" .. tostring(bound) .. " @ " .. tostring(count) .. "]");
            count = count + 1
        end
    end
    return self;
end

function Query:execute(f_step_callback)
    if not self.query then self:build() end
    self._results_headers = {self.query:get_unames()};
    while true do
        self:_step()
        if(self.step == sqlite3.ROW) then
            if f_step_callback then
                f_step_callback(self,self.step);
            end
            values = {self.query:get_uvalues()}
            table.insert(self._results,values);
        else
            if(self.step == sqlite3.DONE) then break; end
            if(self.step == sqlite3.MISUSE) then error("QUERY MISUSE"); end
            error("UKNOWN SQLITE3 QUERY STEP RESULT [" .. tostring(self.step) .. "]")
        end
    end
    if(self.type == "insert") then self.last_insert_row_id = self.db:last_insert_rowid() end
    if(self.type == "delete" or self.type == "update" or self.type == "insert") then self.changes = self.db:changes() end

    if(self._transformsTo) then
        r = self:results();
        if r.count == 0 then
            return false
        end
        if r.count == 1 then
            return self._transformsTo():fill(r:toRelational())
        end
        collected = {};
        for k, row in pairs(r:toRelational()) do
            table.insert(collected, self._transformsTo():fill(row));
        end
        return collected;
    end
    return self;
end

function Query:transformsTo(this)
    self._transformsTo = this;
    return self
end

function Query:_step()
    self.step = self.query:step();
end

function Query:results()
    if(self.type == "insert") then
        return QueryResult("INSERT",{self.changes},{"inserted"})
    end
    if(self.type == "update") then
        return QueryResult("update",{self.changes},{"updated"})
    end
    return QueryResult("SELECT",self._results,self._results_headers)
    -- return {rows=self._results,header=self._results_headers}
end


function Query:table(table_name)
    assert(self._table == nil, 'table already set')
    self._table = table_name
    return self
end

function Query:select(table_name,...)
    if(self.type == "unknown" or self.type == "select") then
        self.type = "select"
        print("set type to:",self.type);
        if(not self._table) then
            self:table(table_name)
            print("add selects to table",self._table)
        else
            print("add selects to table",self._table)
            if(type(table_name) == "table") then
                for k,v in pairs(table_name) do
                    table.insert(self.selects,v)
                    print("add col",v)
                end
            else
                table.insert(self.selects,table_name)
                print("add col",table_name)
            end
        end

        for k,v in pairs({...}) do
            if(type(v == "function")) then
                for i,o in pairs(v) do
                    table.insert(self.selects,o)
                    print("add col",o)
                end
            else
                table.insert(self.selects,v)
                print("add col",v)
            end
        end
        return self;
    else
        error("can not add a select statement to non selecting query")
    end
end

function Query:__tostring(ln)
    ln = ln or "\n"
    return "Query {" .. ln .. tostring(self.statement) .. ln .. "}"; 
end

function Query:getBindings()
    out = ""
    line  = "";
    for k,v in pairs(self.bindings) do 
        line = line .. tostring(v) .. ", "
    end
    line = string.sub(line,1,#line-2);
    out = out .. line
    return out
end
return Query;