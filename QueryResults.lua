Object = require "classic/classic"

local QueryResult = Object:extend()
QueryResult.db = nil;

local function count(args)
    col_count = 0;
    for k,v in pairs(args) do
        col_count = col_count + 1;
    end
    return col_count;
end

function QueryResult:new(typ,contents,headers)
    print("new QueryResult...","\n");
    self.rows = {};
    self.headers = {}
    self.count = -1
    self.type = typ
    self.rows = contents;
    self.headers = headers;
    self.count = count(contents);
end

function QueryResult:toRelational()
    results = {};
    for k,row in pairs(self.rows) do
        result = {}
        for col,header in pairs(self.headers) do
            result[header] = row[col];
        end
        table.insert(results,result)
    end
    return results;
end

function prettify(headers,rows)

    tabCounts = {};
    for k,row in pairs(rows) do
        for col,val in pairs(row) do
            tabCounts[col] = tabCounts[col] or #tostring(headers[col])+1;
            if(tabCounts[col] < #tostring(val)) then tabCounts[col] = #tostring(val)+1 end
        end
    end

    str = "";

    for col,header in pairs(headers) do
        print("col",col,"tabCounts",tabCounts[col])
        str = str .. header .. string.rep(" ",tabCounts[col]-#tostring(header)) .. "| "
    end

    str = str .. "\n";

    for k,row in pairs(rows) do
        for col,val in pairs(row) do
            str = str .. tostring(val) .. string.rep(" ",tabCounts[col]-#tostring(val)) .. "| "
        end
        str = str .. "\n"
    end 

    return str
end

function QueryResult:__tostring()
    return "QueryResult\n" .. prettify(self.headers,self.rows);
end

return QueryResult;