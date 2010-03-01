module(..., package.seeall)

require("parser")
require("scanner")

--
-- A table of supported special syntaxes. Each is a function that returns the
-- final output string for that syntax.
--
specialSyntax = {
    ["cond"] = function ()
        local result = "(function ()\n"
            local token = scanner.peekToken()
            local first = true
            while token ~= ")" do
                scanner.nextToken()  -- Remove initial bracket of clause
                local test = parser.parse(scanner.nextToken())
                if first then
                    result = result .. "if "
                    .. test:selfAsString() .. ".value then\n"
                    first = false
                elseif tostring(test) == "else" then
                    result = result .. "else\n"
                else
                    result = result .. "elseif "
                    .. test:selfAsString() .. ".value then\n"
                end
                local expr = parser.parse(scanner.nextToken())
                if tostring(expr) == "=>" then
                    local func = parser.parse(scanner.nextToken())
                    result = result .. "return " .. func:selfAsString() ..
                    "(" .. scmArglist.fromTable{test:selfAsString()} .. ")\n"
                elseif tostring(expr) == ")" then
                    result = result .. "return " .. test:selfAsString() .. "\n"
                else
                    while tostring(expr) ~= ")" do
                        if scanner.peekToken() == ")" then
                            result = result .. "return "
                        end
                        result = result .. expr:selfAsString() .. "\n"
                        expr = parser.parse(scanner.nextToken())
                    end
                end
                token = scanner.peekToken()
            end
            return result .. "end\nend)()"
        end;

    ["define"] = function ()
        -- TODO implement other forms of define
        local assignee = parser.parse(scanner.nextToken())
        local object = parser.parse(scanner.nextToken())
        return assignee:selfAsString() .. " = " .. object:selfAsString()
    end;

    ["lambda"] = function ()
        local paramList = {}
        local vararg = false
        local params = parser.readDatum()
        if params.scmType == "List" then
            while params.value ~= nil do
                table.insert(paramList, params.value.car)
                if params.value.cdr.scmType ~= "List" then
                    vararg = params.value.cdr
                    break
                end
                params = params.value.cdr
            end
        else
            vararg = params
        end
        local result = "(function (args)\n"
            for _, param in ipairs(paramList) do
                result = result .. "local " .. tostring(param)
                .. " = args:nextArg()\n"
            end
            if vararg ~= false then
                result = result .. "local " .. tostring(vararg)
                .. " = scmList.fromArglist(args)\n"
            end
            result = result .. "return "
            .. tostring(parser.parse(scanner.nextToken())) .. "\nend)"
        return result
    end;
}

--
-- A table for scheme functions that need their arguments collected in a
-- non-standard way. Each is a function that returns the argument list as a
-- string.
--
specialArgs = {
    ["cond"] = function ()
        local token = scanner.peekToken()
        local args = {}
        while token ~= ")" do
            scanner.nextToken() -- Remove initial '('
            local clause = {}
            while scanner.peekToken() ~= ")" do
                local exp = parser.parse(scanner.nextToken())
                if exp.scmType == "Symbol" then
                    if exp.value == "else" then
                        exp = scmString:new("else")
                    elseif exp.scmValue == "=>" then
                        exp = scmString:new("=>")
                    end
                end
                table.insert(clause, exp)
            end
            scanner.nextToken() -- Remove ending ')'
            table.insert(args, scmList.fromTable(clause))
            token = scanner.peekToken()
        end
        return parser.argumentList(args)
    end;

    ["quote"] = function ()
        return scmArglist.fromTable{parser.readDatum():selfAsString()}
    end;

}

--
-- A table of the supported Scheme procedures
--
procedures = {
    ["cond"] = "s2l_cond";
    ["quote"] = "s2l_quote";

    ["cons"] = "s2l_cons";
    ["car"] = "s2l_car";
    ["cdr"] = "s2l_cdr";
    ["list"] = "s2l_list";
    ["length"] = "s2l_length";
    ["filter"] = "s2l_filter";

    -- Useful output routines
    ["display"] = "s2l_display";
    ["newline"] = "s2l_newline";

    -- Arithmetic operators
    ["+"] = "s2l_arithmeticPlus";
    ["-"] = "s2l_arithmeticMinus";
    ["*"] = "s2l_arithmeticMultiply";
    ["/"] = "s2l_arithmeticDivide";

    -- Relational operators
    ["<"] = "s2l_lessThan";
    ["<="] = "s2l_lessThanOrEqual";
    ["="] = "s2l_equals";
    [">"] = "s2l_greaterThan";
    [">="] = "s2l_greaterThanOrEqual";
    ["eqv?"] = "s2l_equals";   -- FIXME

    -- Boolean operators
    ["and"] = "s2l_and";
    ["or"] = "s2l_or";
    ["not"] = "s2l_not";

    -- Predicates
    ["pair?"] = "s2l_pair";
    ["boolean?"] = "s2l_boolean";
    ["null?"] = "s2l_null";
    ["number?"] = "s2l_number";
    ["integer?"] = "s2l_integer";
}
