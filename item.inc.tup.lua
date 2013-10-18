-- Deferred data...

local IsDeferred = function(Object) return Object.Form and true or false end

local ItemMetatable = {}
local Realize
local Methods = {}

-- 1. Construction
function Item(Argument)
	local Out = { Methods = Methods }
	setmetatable(Out, ItemMetatable)
	if Argument then Out = Out:Include(Argument) end
	return Out
end

-- 2. Assembly
local ExtendItem = function(Method, Data, Parent)
	local Instance = { Method = Method, Data = Data, Parent = Parent }
	setmetatable(Instance, getmetatable(Parent))
	return Instance
end
ItemMetatable.__newindex = function(Instance, Index, Value)
	error('Can only defer method calls.')
end
ItemMetatable.__index = function(Instance, Index)
	if Index == 'Form' then return Realize end
	return function(Instance, Argument)
		if not Argument then error('Invalid argument to ' .. Index) end
		if type(Argument) ~= 'table'
		then
			Argument = (not IsTopLevel()) and (tup.getcwd() .. '/' .. Argument) or Argument
		end
		return ExtendItem(Index, Argument, Instance)
	end
end
ItemMetatable.__add = function(Instance, Other)
	if not Instance or type(Instance) ~= 'table' or not IsDeferred(Instance) then error 'Deferred items must go on the left' end
	if not Other then error 'Invalid argument in deferred item addition' end
	return ExtendItem('Include', Other, Instance)
end
ItemMetatable.__subtract = function(Instance, Other)
	if not Instance or type(Instance) ~= 'table' or not IsDeferred(Instance) then error 'Deferred items must go on the left' end
	if not Other then error 'Invalid argument in deferred item subtraction' end
	return ExtendItem('Exclude', Other, Instance)
end

-- 3. Realization
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
local RealizeRecurse
local GetMethods
Realize = function(Instance, Arguments)
	local Aggregate = { Include = {}, Exclude = {} }
	Aggregate = RealizeRecurse(GetMethods(Instance), Instance, Aggregate)
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
ItemMetatable.__tostring = function(Instance)
	return tostring(Realize(Instance))
end

GetMethods = function(Instance)
	return rawget(Instance, 'Methods') or GetMethods(rawget(Instance, 'Parent'))
end
RealizeRecurse = function(Methods, Instance, Out)
	if not rawget(Instance, 'Parent') or not rawget(Instance, 'Method') or not rawget(Instance, 'Data') then return Out end
	return RealizeRecurse(Methods, Instance.Parent, Methods[Instance.Method](Out, Instance.Data))
end

-- 4. Realization verbs
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
Methods.Include = function(Aggregate, Data)
	if type(Data) == 'table'
	then
		if Data.Form
		then
			for Index, Element in ipairs(Data:Form())
			do
				Aggregate.Include[#Aggregate.Include + 1] = Element
			end
		else
			if not Data.Filename then error 'Including invalid element.' end
			Aggregate.Include[#Aggregate.Include + 1] = Data
		end
	else
		Data = tostring(Data)
		for Index, Element in ipairs(ProcessFileString(Data))
		do
			Aggregate.Include[#Aggregate.Include + 1] = Element
		end
	end
	return Aggregate
end
Methods.Exclude = function(Aggregate, Data)
	if type(Data) == 'table'
	then
		if Data.Form
		then
			for Index, Element in ipairs(Data:Form())
			do
				Aggregate.Exclude[Element.Filename] = true
			end
		else
			if not Data.Filename then error 'Excluding invalid element.' end
			Aggregate.Exclude[Data.Filename] = true
		end
	else
		Data = tostring(Data)
		for Index, Element in ipairs(ProcessFileString(Data))
		do
			Aggregate.Exclude[Element.Filename] = true
		end
	end
	return Aggregate
end

