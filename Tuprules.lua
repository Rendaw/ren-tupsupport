--|| Settings
local Debug = true

--|| Build functions
local TopLevel = true
local IncludedFiles = {}
function DoOnce(RootedFilename)
	if IncludedFiles[RootedFilename] then return end
	IncludedFiles[RootedFilename] = true
	TopLevel = false
	tup.include('../' .. RootedFilename)
	TopLevel = true
end

-- All definition function inputs and outputs are items
function Item(Arguments)
	if not Arguments[1] then error 'Missing filename' end
	Arguments.Filename = tup.getcwd() .. '/' .. Arguments[1]
	Arguments[1] = nil
	return Arguments
end

function Object(Arguments)
	local Output = tup.base(Arguments.Source.Filename) .. '.o'
	if TopLevel 
	then
		local Command
		if Debug
		then
			Command = 'g++ -c -Wall -Werror -pedantic -O0 -ggdb ' .. 
				'-o ' .. Output .. ' ' .. Argument.Source.Filename
		else
			Command = 'g++ -c -Wall -Werror -pedantic -O3 ' .. 
				'-o ' .. Output .. ' ' .. Argument.Source.Filename
		end
		tup.definerule{inputs = {Arguments.Source}, outputs = {Output}, command = Command}
	end
	return Item{Output}
end

function Executable(Arguments)
	local Output = Arguments.Name
	if TopLevel 
	then
		local Inputs = {}
		local InputFilenames
		do
			InputFilenames = {}
			for Index, Source in ipairs(Arguments.Sources)
			do
				Arguments.Source = Source
				Inputs[#Inputs + 1] = Object(Arguments)
				InputFilenames[#InputFilenames + 1] = Inputs[#Inputs].Filename
			end
			InputFilenames = table.concat(InputFilenames, ' ')
		end
		local Command
		if Debug
		then
			Command = 'g++ -Wall -Werror -pedantic -O0 -ggdb ' .. 
				'-o ' .. Output .. ' ' .. InputFilenames
		else
			Command = 'g++ -Wall -Werror -pedantic -O3 ' .. 
				'-o ' .. Output .. ' ' .. InputFilenames
		end
		tup.definerule{inputs = Inputs, outputs = {Output}, command = Command}
	end
	return Item{Output}
end

function Test(Arguments)
	local Output = Arguments.Executable.Filename .. '.results.txt'
	if TopLevel
	then
		tup.definerule{inputs = {Arguments.Executable.Filename}, outputs = {Output}, command = './' .. Arguments.Executable.Filename .. ' > ' .. Output}
	end
	return Item{Output}
end

