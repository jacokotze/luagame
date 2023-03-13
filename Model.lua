Object = require "classic/classic"
Query = require("Builder")
QueryResult = require("QueryResults")

local function ucwords(words)
    final = ""
    for word in words:gmatch("([^_]*)") do
        final = final .. word:sub(1,1):upper() .. word:sub(2);
    end
    -- print("ucworded",final);
    return final
end

local Model = Object:extend()

function Model:find(by,comp,val)
    local q = self:query();
    if(not comp and not val) then
        q:where(self.primary_key,by)
    else
        if(comp and not val) then
            q:where(by,comp)
        elseif(comp and val) then
            q:where(by,comp,val)
        end
    end
    r = q:build():execute():results()
    if(r.count == 1) then
        m = self()
        m:fill(r);
        return m;
    end
    return nil;
end

--- Creates a HasMany relationship using a pivot Through
---@param as string The accessor to create
---@param thing table the model to morph results to
---@param through string the table that pivots the two models
---@param through_local_id string the reference to this model on the pivot
---@param through_foreign_id string the reference on the pivot
---@param local_id string the reference on this model
---@param foreign_id string the reference id on the foreign model
function Model:hasManyThrough(as,thing,through,through_local_id,through_foreign_id,local_id,foreign_id)
    assert(thing.is and thing:is(Model),"Can only Relate to a Model");
    self[as] = function(self)
        local_id = local_id or 'id';
        local_id = self.attributes[local_id];
        things = {};
        
        r = Query(through):select(through_foreign_id..' as id'):where(through_local_id,local_id):execute():results();

        ids = {};
        for k,v in pairs(r.rows) do
            table.insert(ids,v[1])
        end

        item_q = thing:query():whereIn(foreign_id,ids);
        item_q:transformsTo(Item);
        return item_q
    end
end

function Model:query()
    return Query(self.table):select(self.columns)
end


function Model:all()
    local q = self:query();
    local all = {};
    r = q:build():execute():results():toRelational()
    for k,v in pairs(r) do
        print("from all got",k)
        -- for i,o in pairs(v) do print(i,o) end
        m = self()
        print("filling...")
        m:fill(v);
        table.insert(all,m);
    end
    return all;
end

function Model:save()
    for k,v in pairs(self.attributes) do print(k,v) end
    q = Query(self.table):update(self.attributes);
    q:where(self.primary_key,self:getId());
    r = q:build():execute():results();
    return self,r
end

local function hasKey(t,f)
    for k,v in pairs(t) do if k == f then return true end end
    return false
end

function Model:fill(with)
    if with.is and with:is(QueryResult) and with.count == 1 then
        row = with.rows[1];
        for k,v in pairs(with.headers) do
            self.attributes[v] = row[k];
            self['get' .. ucwords(v)] = function(self) return self.attributes[v] end
            self['set' .. ucwords(v)] = function(self,val) self.attributes[v] = val; self:save(); end
        end
    else
        -- print("filling from table of col->val")
        for k,v in pairs(with) do
            -- print("put into attribute",k,v,"has",hasKey(self.attributes,k))
            if(hasKey(self.attributes,k)) then
                -- print("filll in ",k,"as",v)
                self.attributes[k] = v;
                self['get' .. ucwords(k)] = function(self) return self.attributes[k] end
                self['set' .. ucwords(k)] = function(self,val) self.attributes[k] = val; self:save(); end
            end
        end
    end
    return self;
end

function Model:new()
    print("new Model...","\n");
    self.attributes = {};
    for k,v in pairs(self.fillable) do
        self.attributes[v] = ""
        self['get' .. ucwords(v)] = function(self) return self.attributes[v] end
        self['set' .. ucwords(v)] = function(self,val) self.attributes[v] = val; self:save(); end
    end
end

function Model:__tostring()
    return "Model";
end

return Model;