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

local CXXBuildFlags = ' -std=c++1y'
local CBuildFlags = ''
local BuildFlags = ' -Wall -pedantic'
local LinkFlags = ' -Wall -Werror -pedantic'
local LibraryBuildFlags = ''
if tup.getconfig 'COMPILER' == 'clang' then
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
	(tup.getconfig 'PLATFORM' == 'ubuntu') or
	(tup.getconfig 'PLATFORM' == 'ubuntu64')
then
	LibraryBuildFlags = LibraryBuildFlags .. ' -fPIC'
	if IsDebug()
	then BuildFlags = BuildFlags .. ' \'-DRESOURCELOCATION="."\''
	else BuildFlags = BuildFlags .. ' \'-DRESOURCELOCATION="/usr/share/' .. ProjectName .. '"\''
	end
end
if IsDebug()
then
	BuildFlags = BuildFlags .. ' -O0'
	LinkFlags = LinkFlags .. ' -O0'
	if tup.getconfig 'PLATFORM' == 'windows'
	then 
		LinkFlags = LinkFlags .. ' -g'
		BuildFlags = BuildFlags .. ' -g'
	else 
		LinkFlags = LinkFlags .. ' -ggdb'
		BuildFlags = BuildFlags .. ' -ggdb'
	end
else
	BuildFlags = BuildFlags .. ' -O3 -DNDEBUG'
	LinkFlags = LinkFlags .. ' -O3'
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

Define.Write = Target(function(Arguments)
	if IsTopLevel()
	then
		local Output = Arguments.Output or Item()
		tup.definerule
		{
			outputs = Arguments.Output:Form():Extract('Filename'),
			command = 'cat > ' .. tostring(Arguments.Output) .. ' <<\'FOOGWAR\'\n' .. Arguments.Text .. '\nFOOGWAR'
		}
	end
	return Arguments.Output
end)

Define.Object = Target(function(Arguments)
	local Source = tostring(Arguments.Source)
	local Output = tup.base(Source) .. '.o'
	if IsTopLevel()
	then
		local IsC = Source:match('%.c$')
		local UseBuildFlags =
			(IsC and CBuildFlags or CXXBuildFlags) ..
			(Arguments.IsLibrary and LibraryBuildFlags or '') ..
			BuildFlags .. ' ' .. tup.getconfig('BUILDFLAGS')
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
	if not Arguments.Sources then return Item() end
	local Sources = Arguments.Sources:Form()
	local Outputs = Item()
	for Index, Source in ipairs(Sources)
	do
		Outputs = Outputs:Include(Define.Object(Mask({Source = Item(Source)}, Arguments)))
	end
	return Outputs
end)

local Directory = function(Input)
	return Input:gsub('/[^/]+$', '')
end

local FormatLocalLibraries = function(Arguments)
	if tup.getconfig 'PLATFORM' ~= 'windows'
	then
		if Arguments.LocalLibraries
		then
			local Flags = ''
			for Index, Library in ipairs(Arguments.LocalLibraries:Form():Extract('Filename'))
			do
				Flags = Flags .. ' -L' .. Directory(Library) .. ' -l' .. tup.base(Library):gsub('^lib', '')
				print(Flags)
			end
			return Flags, Arguments.LocalLibraries
		else
			return nil, nil
		end
	else
		return nil, Arguments.LocalLibraries
	end
end

Define.Executable = Target(function(Arguments)
	local Output = Arguments.Name
	if tup.getconfig 'PLATFORM' == 'windows'
	then
		Output = Output .. '.exe'
	end
	if IsTopLevel()
	then
		local Inputs = Define.Objects(Arguments)
		if Arguments.Objects then Inputs = Arguments.Objects + Inputs end
		LocalLibraryFlags, LocalLibraries = FormatLocalLibraries(Arguments)
		local ExplicitInputs = Inputs
		if LocalLibraries then Inputs = Inputs + LocalLibraries end
		local Command = tup.getconfig('LINKERBIN') .. LinkFlags ..
			' -o ' .. Output .. ' ' .. tostring(ExplicitInputs:Form()) ..
			' ' .. (Arguments.LinkFlags or '') .. 
			' ' .. (LocalLibraryFlags or '') ..
			' ' .. tup.getconfig('LINKFLAGS')
		tup.definerule
		{
			inputs = Inputs:Form():Extract('Filename'), 
			outputs = {Output}, 
			command = Command
		}
	end
	return Item(Output)
end)

Define.Library = Target(function(Arguments)
	local Output = Arguments.Name
	if tup.getconfig 'PLATFORM' == 'windows'
	then
		Output = Output .. '.dll'
	else
		Output = 'lib' .. Output .. '.so'
	end
	if IsTopLevel()
	then
		Arguments.IsLibrary = true
		local Inputs = Define.Objects(Arguments)
		if Arguments.Objects then Inputs = Arguments.Objects + Inputs end
		LocalLibraryFlags, LocalLibraries = FormatLocalLibraries(Arguments)
		local ExplicitInputs = Inputs
		if LocalLibraries then Inputs = Inputs + LocalLibraries end
		local Command = tup.getconfig('LINKERBIN') .. ' -shared' .. LinkFlags ..
			' -o ' .. Output .. ' ' .. tostring(ExplicitInputs:Form()) ..
			' ' .. (Arguments.LinkFlags or '') .. 
			' ' .. (LocalLibraryFlags or '') ..
			' ' .. tup.getconfig('LINKFLAGS')
		tup.definerule
		{
			inputs = Inputs:Form():Extract('Filename'), 
			outputs = {Output}, 
			command = Command
		}
	end
	return Item(Output)
end)

Define.Test = Target(function(Arguments)
	local Executable = tostring(Arguments.Executable:Form())
	local Output = Executable .. '.results.txt'
	if IsTopLevel() and (tup.getconfig 'TEST' ~= 'false')
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

