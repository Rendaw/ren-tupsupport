local Vanilla = {
	table = { concat = table.concat }
}
table.concat = function(Table, Separator)
	local Strings = {}
	for Index, Element in ipairs(Table) do Strings[Index] = tostring(Element) end
	return Vanilla.table.concat(Strings, Separator)
end

