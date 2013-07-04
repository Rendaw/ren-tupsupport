local Realize = function(TargetData)
	local Out = TargetData.Function(TargetData.Arguments)
	return Out:Form()
end
function Target(Function)
	if IsTopLevel() 
	then
		return Function
	else 
		return function(Arguments)
			return { Function = Function, Arguments = Arguments, Form = Realize }
		end
	end
end

