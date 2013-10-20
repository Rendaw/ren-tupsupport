tup.include '../info.inc.lua'

tup.include 'luatweaks.inc.tup.lua'
tup.include 'mask.inc.tup.lua'
tup.include 'item.inc.tup.lua'
tup.include 'target.inc.tup.lua'

do
	local TopLevel = true
	function IsTopLevel() return TopLevel end

	local OldInclude = tup.include
	tup.include = nil
	local IncludedFiles = {}
	local Root = tup.nodevariable('.')
	function DoOnce(RootedFilename)
		if IncludedFiles[RootedFilename] then return end
		IncludedFiles[RootedFilename] = true
		local OldTopLevel = TopLevel
		TopLevel = false
		OldInclude(Root .. '/../' .. RootedFilename)
		TopLevel = OldTopLevel
	end
end

--|| Settings
do
	local Debug = tup.getconfig('DEBUG') ~= 'false'
	function IsDebug() return Debug end
end

if tup.getconfig 'PLATFORM' ~= 'windows'
       then tup.export 'LD_LIBRARY_PATH' end

local CXXBuildFlags = ' -std=c++11'
local CBuildFlags = ''
local BuildFlags = ' -Wall -pedantic -Wconversion'
if tup.getconfig 'COMPILER' == 'clang++' then
	BuildFlags = BuildFlags .. ' -Werror'
else
	BuildFlags = BuildFlags .. ' -Wno-unused-local-typedefs'
end
if tup.getconfig 'PLATFORM' == 'windows'
then
	BuildFlags = BuildFlags ..
		' -DWINDOWS' ..
		' \'-DRESOURCELOCATION="."\''
elseif (tup.getconfig 'PLATFORM' == 'arch64') or
	(tup.getconfig 'PLATFORM' == 'ubuntu12') or
	(tup.getconfig 'PLATFORM' == 'ubuntu12_64')
then
	if IsDebug()
	then BuildFlags = BuildFlags .. ' \'-DRESOURCELOCATION="."\''
	else BuildFlags = BuildFlags .. ' \'-DRESOURCELOCATION="/usr/share/' .. Info.PackageName .. '"\''
	end
end

--|| Build functions
-- All definition function inputs and outputs are items

Define = {}

Define.Lua = Target(function(Arguments)
	if IsTopLevel()
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

Define.Raw = Target(function(Arguments)
	if IsTopLevel()
	then
		local Inputs = Arguments.Inputs or Item()
		local Outputs = Arguments.Outputs or Item()
		tup.definerule
		{
			inputs = Inputs:Form():Extract('Filename'),
			outputs = Arguments.Outputs:Form():Extract('Filename'),
			command = Arguments.Command
		}
	end
	return Arguments.Outputs
end)

Define.Object = Target(function(Arguments)
	local Source = tostring(Arguments.Source)
	local Output = tup.base(Source) .. '.o'
	if IsTopLevel()
	then
		local IsC = Source:match('%.c$')
		local UseBuildFlags =
			(IsC and CBuildFlags or CXXBuildFlags) ..
			BuildFlags .. ' ' .. tup.getconfig('BUILDFLAGS') ..
			(IsDebug() and ' -O0 -ggdb' or ' -O3')
		local Command =
			(IsC and tup.getconfig('CCOMPILERBIN') or tup.getconfig('COMPILERBIN')) ..
			UseBuildFlags .. ' -c -o ' .. Output .. ' ' .. Source ..
			' ' .. (Arguments.BuildFlags or '')
		local Inputs = Arguments.Source
		if Arguments.BuildExtras then Inputs = Inputs:Include(Arguments.BuildExtras) end
		Inputs = Inputs:Form():Extract('Filename')
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
	if IsTopLevel()
	then
		local Inputs = Define.Objects(Arguments)
		if Arguments.Objects then Inputs = Inputs:Include(Arguments.Objects) end
		Inputs = Inputs:Form()
		local Command
		if IsDebug()
		then
			Command = tup.getconfig('LINKERBIN') .. ' -Wall -Werror -pedantic -O0 -ggdb ' ..
				'-o ' .. Output .. ' ' .. tostring(Inputs) ..
				' ' .. (Arguments.LinkFlags or '') .. ' ' .. tup.getconfig('LINKFLAGS')
		else
			Command = tup.getconfig('LINKERBIN') .. ' -Wall -Werror -pedantic -O3 ' ..
				'-o ' .. Output .. ' ' .. tostring(Inputs) ..
				' ' .. (Arguments.LinkFlags or '') ..  ' ' .. tup.getconfig('LINKFLAGS')
		end
		tup.definerule{inputs = Inputs:Extract('Filename'), outputs = {Output}, command = Command}
	end
	return Item(Output)
end)

Define.Test = Target(function(Arguments)
	local Executable = tostring(Arguments.Executable:Form())
	local Output = Executable .. '.results.txt'
	if IsTopLevel()
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

