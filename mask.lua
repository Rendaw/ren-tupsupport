function Mask(Mask, Original)
	return setmetatable(Mask, { __index = Original })
end

