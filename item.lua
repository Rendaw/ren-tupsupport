local ProcessFileString = function(FileString)
	local Out = {}
	if FileString:match('%*') or FileString:match('%?') or FileString:match('%[.*%]') 
	then
		for Index, File in ipairs(tup.glob(FileString)) 
		do
			Out[#Out + 1] = {Filename = File}
		end
	else
		Out[#Out + 1] = {Filename = FileString}
	end 
	return Out
end
local ItemMethods = { Access = {} } 
ItemMethods.Initialize = function()
	return { Include = {}, Exclude = {} }
end
ItemMethods.Access.Include = function(Aggregate, Data)
	if type(Data) == 'table'
	then
		if Data.Form
		then
			for Index, Element in ipairs(Data:Form())
			do
				Aggregate.Include[#Aggregate.Include + 1] = Element
			end
		else
			for Index, String in ipairs(Data)
			do
				for Index, Element in ipairs(ProcessFileString(String))
				do
					Aggregate.Include[#Aggregate.Include + 1] = Element
				end
			end
		end
	else
		for Index, Element in ipairs(ProcessFileString(Data))
		do
			Aggregate.Include[#Aggregate.Include + 1] = Element
		end
	end
	return Aggregate
end
ItemMethods.Access.Exclude = function(Aggregate, Data)
	if type(Data) == 'table' 
	then
		if Data.Form
		then
			for Index, Element in ipairs(Data:Form())
			do
				Aggregate.Exclude[Element.Filename] = true
			end
		else
			for Index, String in ipairs(Data)
			do
				for Index, Element in ipairs(ProcessFileString(String))
				do
					Aggregate.Exclude[Element] = true
				end
			end
		end
	else
		for Index, Element in ipairs(ProcessFileString(Data))
		do
			Aggregate.Exclude[Element.Filename] = true
		end
	end
	return Aggregate
end
ItemMethods.Concatenate = function(This, That)
	local ThisAndThat = {This, That}
	local Strings = {}
	for Index, Which in ipairs(ThisAndThat)
	do
		if type(Which) == 'table' and Which.Filename 
		then
			Strings[Index] = Which.Filename
		else 
			Strings[Index] = tostring(Which)
		end
	end
	return table.concat(Strings, '')
end
local ItemFinalMetatable =
{
	__tostring = function(Aggregate)
		return table.concat(Aggregate:Extract('Filename'), ' ')
	end,
	__index = {
		Extract = function(Aggregate, DataName)
			local Out = {}
			for Index, Element in ipairs(Aggregate)
			do
				Out[#Out + 1] = Element[DataName]
			end
			return Out
		end
	}
}
ItemMethods.Finalize = function(Aggregate)
	local Out = {}
	setmetatable(Out, ItemFinalMetatable)
	for Index, Element in ipairs(Aggregate.Include)
	do
		if not Aggregate.Exclude[Element.Filename] 
		then 
			Out[#Out + 1] = Element
		end
	end
	return Out
end
ItemMethods.ToString = function(Aggregate)
end

-- Preparsing arguments to qualify with directory path
local Qualify = function(FileString)
	return (not IsTopLevel()) and (tup.getcwd() .. '/' .. FileString) or FileString
end
local ItemMetatable = {}
local DeferredMetatable = getmetatable(Deferred({}))
ItemMetatable.__tostring = DeferredMetatable.__tostring
ItemMetatable.__index = function(Instance, Index)
	local DeferredIndex = DeferredMetatable.__index(Instance, Index)
	return function(Instance, Argument)
		if type(Argument) == 'table' 
		then
			if not Argument.Form
			then
				local NewArgument = {}
				for Index, String in ipairs(Argument)
				do
					NewArgument[#NewArgument + 1] = Qualify(String)
				end
				Argument = NewArgument
			end
		else
			Argument = Qualify(Argument)
		end
		return DeferredIndex(Instance, Argument)
	end

end

-- Item construction
function Item(Argument)
	local Out = Deferred(ItemMethods)
	setmetatable(Out, ItemMetatable)
	if Argument then Out = Out:Include(Argument) end
	return Out
end

