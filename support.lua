tup.include 'luatweaks.lua'

local TopLevel = true
function IsTopLevel() return TopLevel end
local IncludedFiles = {}
local Root = tup.nodevariable('.')
function DoOnce(RootedFilename)
	if IncludedFiles[RootedFilename] then return end
	IncludedFiles[RootedFilename] = true
	local OldTopLevel = TopLevel
	TopLevel = false
	tup.include(Root .. '/../' .. RootedFilename)
	TopLevel = OldTopLevel
end

tup.include 'mask.lua'
tup.include 'item.lua'
tup.include 'target.lua'

--|| Settings
local Debug = tup.getconfig('DEBUG') ~= 'false'

local BuildFlags = '-std=c++11 -Wall -Werror -pedantic -Wno-unused-local-typedefs'
if tup.getconfig 'PLATFORM' == 'windows'
then
	BuildFlags = BuildFlags .. ' -DWINDOWS'
end

--|| Build functions
-- All definition function inputs and outputs are items

Define = {}

Define.Lua = Target(function(Arguments)
	if TopLevel
	then
		local Inputs = Item(Arguments.Script)
		if Arguments.Inputs then Inputs = Inputs:Include(Arguments.Inputs) end
		tup.definerule
		{
			inputs = Inputs:Form():Extract('Filename'),
			outputs = Arguments.Outputs:Form():Extract('Filename'),
			command = 'lua ' .. Arguments.Script .. ' ' .. (Arguments.Arguments or '')
		}
	end
	return Arguments.Outputs
end)

Define.Object = Target(function(Arguments)
	local Source = tostring(Arguments.Source)
	local Output = tup.base(Source) .. '.o'
	if TopLevel 
	then
		local Command
		if Debug
		then
			Command = tup.getconfig('COMPILERBIN') ..' -c ' .. BuildFlags .. ' -O0 -ggdb ' .. 
				'-o ' .. Output .. ' ' .. Source ..
				' ' .. (Arguments.BuildFlags or '')

		else
			Command = tup.getconfig('COMPILERBIN') .. ' -c ' .. BuildFlags .. ' -O3 ' .. 
				'-o ' .. Output .. ' ' .. Source ..
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
	if tup.getconfig 'PLATFORM' == 'windows'
	then
		Output = Output .. '.exe'
	end
	if TopLevel 
	then
		local Inputs = Define.Objects(Arguments)
		if Arguments.Objects then Inputs = Inputs:Include(Arguments.Objects) end
		Inputs = Inputs:Form()
		local Command
		if Debug
		then
			Command = tup.getconfig('LINKERBIN') .. ' -Wall -Werror -pedantic -O0 -ggdb ' .. 
				'-o ' .. Output .. ' ' .. tostring(Inputs) .. 
				' ' .. (Arguments.LinkFlags or '')
		else
			Command = tup.getconfig('LINKERBIN') .. ' -Wall -Werror -pedantic -O3 ' .. 
				'-o ' .. Output .. ' ' .. tostring(Inputs) .. 
				' ' .. (Arguments.LinkFlags or '')
		end
		tup.definerule{inputs = Inputs:Extract('Filename'), outputs = {Output}, command = Command}
	end
	return Item(Output)
end)

Define.Test = Target(function(Arguments)
	local Executable = tostring(Arguments.Executable:Form())
	local Output = Executable .. '.results.txt'
	if TopLevel
	then
		local Inputs = Arguments.Executable
		if Arguments.Inputs then Inputs = Inputs:Include(Arguments.Inputs) end
		tup.definerule
		{
			inputs = Inputs:Form():Extract('Filename'),
			outputs = {Output},
			command = './' .. Executable .. ' ' .. (Arguments.Arguments or '') .. ' 2>&1 > ' .. Output
		}
	end
	return Item(Output)
end)

