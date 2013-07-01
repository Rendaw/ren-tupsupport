local ArgumentMetatable = 
{
	__index = function(Arguments, Index)
		return function(Arguments, Value)
			return Arguments[Index](Arguments, Value)
		end
	end
}
local ArgumentsInit 
ArgumentsInit = function(Target)
	if Target then return Target end
	local Methods = { Initialize = ArgumentsInit, Access = {} }
	setmetatable(Methods.Access, ArgumentMetatable)
	return Deferred(Methods)
end
function DeferredFunction(Method)
	return function()
		local Methods = 
		{
			Initialize = ArgumentsInit,
			Finalize = Method,
			Access = {}
		}
		setmetatable(Methods.Access, ArgumentMetatable)
		return Deferred(Methods)
	end
end
local FinishMetatable = {
	__index = function(Arguments, Index)
		return function(Arguments, Value)
			Arguments[Index] = Value
			return Arguments
		end
	end
}
function FinishArguments(Arguments)
	local Methods = { Access = {} }
	setmetatable(Methods.Access, FinishMetatable)
	return Arguments:Form(Deferred(Methods)):Form()
end

