local Vanilla = {
	table = { concat = table.concat }
}
table.concat = function(Table, Separator)
	local Strings = {}
	for Index, Element in ipairs(Table) do Strings[Index] = tostring(Element) end
	return Vanilla.table.concat(Strings, Separator)
end

function rawtostring(Table)
	if type(Table) ~= 'table' then return tostring(Table) end
	local OldMetatable = getmetatable(Table)
	setmetatable(Table, {})
	local Out = tostring(Table)
	setmetatable(Table, OldMetatable)
	return Out
end
