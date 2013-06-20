tup.include 'luatweaks.lua'

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
local ItemMetatable = {
	__tostring = function(Item) return Item.Filename end,
	__concat = function(This, That)
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
}
function Item(Arguments)
	if not Arguments[1] then error 'Missing filename' end
	Arguments.Filename = (not TopLevel) and (tup.getcwd() .. '/' .. Arguments[1]) or Arguments[1]
	Arguments[1] = nil
	setmetatable(Arguments, ItemMetatable)
	return Arguments
end

function Object(Arguments)
	local Output = tup.base(tostring(Arguments.Source)) .. '.o'
	if TopLevel 
	then
		local Command
		if Debug
		then
			Command = 'g++-4.8 -c -std=c++11 -Wall -Werror -pedantic -Wno-unused-local-typedefs -O0 -ggdb ' .. 
				'-o ' .. Output .. ' ' .. Arguments.Source
		else
			Command = 'g++-4.8 -c -std=c++11 -Wall -Werror -pedantic -Wno-unused-local-typedefs -O3 ' .. 
				'-o ' .. Output .. ' ' .. Arguments.Source
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
		for Index, Source in ipairs(Arguments.Sources)
		do
			Arguments.Source = Source
			Inputs[#Inputs + 1] = Object(Arguments)
		end
		local Command
		if Debug
		then
			Command = 'g++ -Wall -Werror -pedantic -O0 -ggdb ' .. 
				'-o ' .. Output .. ' ' .. table.concat(Inputs, ' ')
		else
			Command = 'g++ -Wall -Werror -pedantic -O3 ' .. 
				'-o ' .. Output .. ' ' .. table.concat(Inputs, ' ')
		end
		tup.definerule{inputs = Inputs, outputs = {Output}, command = Command}
	end
	return Item{Output}
end

function Test(Arguments)
	local Output = Arguments.Executable .. '.results.txt'
	if TopLevel
	then
		tup.definerule{inputs = {Arguments.Executable}, outputs = {Output}, command = './' .. Arguments.Executable .. ' > ' .. Output}
	end
	return Item{Output}
end

