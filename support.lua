-- TODO Form()->Form()
--

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

tup.include 'deferred.lua'
tup.include 'item.lua'
tup.include 'deferredfunction.lua'

--|| Settings
local Debug = true

--|| Build functions
-- All definition function inputs and outputs are items

Define = {}

Define.Object = DeferredFunction(function(Arguments)
	Arguments = FinishArguments(Arguments)
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
		tup.definerule{inputs = {Source}, outputs = {Output}, command = Command}
	end
	return Item(Output)
end)

Define.Objects = DeferredFunction(function(Arguments)
	local Sources = FinishArguments(Arguments).Sources:Form()
	local Outputs = Item()
	for Index, Source in ipairs(Sources)
	do
		Outputs = Outputs:Include(Arguments:Source(Item(Source.Filename)):Form(Define.Object()):Form())
	end
	return Outputs
end)

Define.Executable = DeferredFunction(function(Arguments)
	FinishedArguments = FinishArguments(Arguments)
	local Output = FinishedArguments.Name
	if TopLevel 
	then
		local Inputs = Arguments:Form(Define.Objects()):Form()
		if FinishedArguments.Objects then Inputs = Inputs:Include(FinishedArguments.Objects) end
		Inputs = Inputs:Form()
		local Command
		if Debug
		then
			Command = 'g++ -Wall -Werror -pedantic -O0 -ggdb ' .. 
				'-o ' .. Output .. ' ' .. tostring(Inputs) .. 
				' ' .. (FinishedArguments.LinkFlags or '')
		else
			Command = 'g++ -Wall -Werror -pedantic -O3 ' .. 
				'-o ' .. Output .. ' ' .. tostring(Inputs) .. 
				' ' .. (FinishedArguments.LinkFlags or '')
		end
		tup.definerule{inputs = Inputs:Extract('Filename'), outputs = {Output}, command = Command}
	end
	return Item(Output)
end)

Define.Test = DeferredFunction(function(Arguments)
	Arguments = FinishArguments(Arguments)
	local Output = tostring(Arguments.Executable) .. '.results.txt'
	if TopLevel
	then
		tup.definerule{inputs = {Arguments.Executable}, outputs = {Output}, command = './' .. Arguments.Executable .. ' > ' .. Output}
	end
	return Item(Output)
end)

