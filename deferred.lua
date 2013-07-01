-- Deferred data
local DeferredMetatable = {}
function Deferred(Methods)
	local Instance = { Methods = Methods }
	setmetatable(Instance, DeferredMetatable)
	return Instance
end
local ExtendDeferred = function(Method, Data, Parent)
	local Instance = { Method = Method, Data = Data, Parent = Parent }
	setmetatable(Instance, getmetatable(Parent))
	return Instance
end
DeferredMetatable.__newindex = function(Instance, Index, Value)
	error('Can only defer method calls.')
end

-- Realization
local GetMethods
GetMethods = function(Instance)
	return rawget(Instance, 'Methods') or GetMethods(rawget(Instance, 'Parent'))
end
local RealizeRecurse
RealizeRecurse = function(Instance, Methods, Out)
	if not rawget(Instance, 'Parent') or not rawget(Instance, 'Method') or not rawget(Instance, 'Data') then return Out end
	return RealizeRecurse(Instance.Parent, Methods, Methods.Access[Instance.Method](Out, Instance.Data))
end
local Realize = function(Instance, Arguments)
	local Methods = GetMethods(Instance)
	local Out = (Methods.Initialize and Methods.Initialize(Arguments)) or {}
	Out = RealizeRecurse(Instance, Methods, Out)
	if Methods.Finalize then return Methods.Finalize(Out) end
	return Out
end
DeferredMetatable.__tostring = function(Instance)
	return tostring(Realize(Instance))
end

-- Deferral
DeferredMetatable.__index = function(Instance, Index)
	if Index == 'Form' then return Realize end
	return function(Instance, Argument)
		return ExtendDeferred(Index, Argument, Instance)
	end
end
DeferredMetatable.__concat = function(Instance, Other)
	if type(Instance) == 'table' and Instance.Form
	then
		return ExtendDeferred('Concatenate', Other, Instance)
	elseif type(Other) == 'table' and Other.Form
	then
		return ExtendDeferred('Concatenate', Instance, Other)
	end
end

-- Automatic realization
setmetatable(_G, 
{
	__newindex = function(Globals, Index, Value)
		if IsTopLevel() and type(Value) == 'table' and Value.Form
		then
			rawset(Globals, Index, Value:Form())
		else
			rawset(Globals, Index, Value)
		end
	end
})

