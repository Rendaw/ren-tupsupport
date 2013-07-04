tup.include 'luatweaks.lua'

local TopLevel = true
function IsTopLevel() return TopLevel end
local IncludedFiles = {}
local Root = tup.getcwd()
function DoOnce(RootedFilename)
	if IncludedFiles[RootedFilename] then return end
	IncludedFiles[RootedFilename] = true
	TopLevel = false
	tup.include(Root .. '/../' .. RootedFilename)
	TopLevel = true
end

tup.include 'mask.lua'
tup.include 'item.lua'
tup.include 'target.lua'

--|| Settings
local Debug = true

--|| Build functions
-- All definition function inputs and outputs are items

Define = {}

Define.Lua = Target(function(Arguments)
	if TopLevel
	then
		tup.definerule
		{
			outputs = {Arguments.Out},
			command = 'lua ' .. Arguments.Script
		}
	end
	return Item(Arguments.Out)
end)

Define.Object = Target(function(Arguments)
	local Source = tostring(Arguments.Source)
	local Output = tup.base(Source) .. '.o'
	if TopLevel 
	then
		local Command
		if Debug
		then
			Command = 'g++ -c -std=c++11 -Wall -Werror -pedantic -Wno-unused-local-typedefs -O0 -ggdb ' .. 
				'-o ' .. Output .. ' ' .. Source ..
				' ' .. (Arguments.BuildFlags or '')

		else
			Command = 'g++ -c -std=c++11 -Wall -Werror -pedantic -Wno-unused-local-typedefs -O3 ' .. 
				'-o ' .. Output .. ' ' .. Source
				' ' .. (Arguments.BuildFlags or '')
		end
		local Inputs = Arguments.Source:Include(Arguments.BuildExtras):Form():Extract('Filename')
		tup.definerule{inputs = Inputs, outputs = {Output}, command = Command}
	end
	return Item(Output)
end)

Define.Objects = Target(function(Arguments)
	local Sources = Arguments.Sources:Form()
	local Outputs = Item()
	for Index, Source in ipairs(Sources)
	do
		Outputs = Outputs:Include(Define.Object(Mask({Source = Item(Source)}, Arguments)))
	end
	return Outputs
end)

Define.Executable = Target(function(Arguments)
	local Output = Arguments.Name
	if TopLevel 
	then
		local Inputs = Define.Objects(Arguments)
		if Arguments.Objects then Inputs = Inputs:Include(Arguments.Objects) end
		Inputs = Inputs:Form()
		local Command
		if Debug
		then
			Command = 'g++ -Wall -Werror -pedantic -O0 -ggdb ' .. 
				'-o ' .. Output .. ' ' .. tostring(Inputs) .. 
				' ' .. (Arguments.LinkFlags or '')
		else
			Command = 'g++ -Wall -Werror -pedantic -O3 ' .. 
				'-o ' .. Output .. ' ' .. tostring(Inputs) .. 
				' ' .. (Arguments.LinkFlags or '')
		end
		tup.definerule{inputs = Inputs:Extract('Filename'), outputs = {Output}, command = Command}
	end
	return Item(Output)
end)

Define.Test = Target(function(Arguments)
	local Output = tostring(Arguments.Executable) .. '.results.txt'
	if TopLevel
	then
		tup.definerule{inputs = {Arguments.Executable}, outputs = {Output}, command = './' .. Arguments.Executable .. ' > ' .. Output}
	end
	return Item(Output)
end)

