--[[

------------------------------- General
DoOnce LUA_FILE 
	Includes and runs LUA_FILE.  LUA_FILE should be relative to the tup root and have no leading slash.  Guards against re-includes.

------------------------------- Path management
Item()
Item FILENAME 
	Constructs an item, optionally initializing it with one value (FILENAME).
Item operator + FILENAME|ITEM|GLOB
	Returns a new item with the operand included.  GLOB is an expression like '*.cxx'.

------------------------------- Rule definition
All Define functions return Items.  Define functions may grab relevant config variables from tup.config in addition to explicit arguments.

Output = Define.Raw { Inputs = ITEM, Outputs = ITEM, Command = STRING }
	Creates a rule that runs an arbitrary command, Command.

Output = Define.Lua { Script = ITEM, Inputs = ITEM, Outputs = ITEM, Arguments = STRING }
	- Inputs (optional)
	- Arguments (optional)
	Creates a rule that runs a lua script Script, passing Arguments.

Output = Define.Text { Output = ITEM, Text = STRING }
	Creates a rule that generates a text file with the contents Text.

Object = Define.Object { Source = ITEM, IsLibrary = BOOL, BuildFlags = STRING, BuildExtras = ITEM }
	- Source (required) - Source file to compile.
	- IsLibrary (optional) - Indicates that the object will be used in a library.  If true, includes LibraryBuildFlags.
	- BuildFlags (optional) - Flags to use when compiling.
	- BuildExtras (optional) - Extra input dependencies.  This may be things like generated headers.
	Compiles a c/c++ source into an object.

Objects = Define.Objects  { Sources = ITEM, arguments from Define.Object }
	- Sources (required) - Source files to compile.
	Compiles multiple c/c++ sources into objects.  Each source individually and the remaining arguments are passed to Define.Object.

Executable = Define.Executable { Name = STRING, Objects = ITEM, LinkFlags = STRING, arguments from Define.Objects }
	- Name (required) - Name of the executable.  An extension is added automatically if required.
	- Objects (optional) - Objects to include when linking.
	- LinkFlags (optional) - Flags to use when linking.
	Creates an executable.  Objects to link can be passed in explicitly, or Sources can be passed in which will be compiled and then linked.
	
Library = Define.Library { Name = STRING, Objects = ITEM, LinkFlags = STRING, arguments from Define.Objects }
	- Name (required) - Name of the library.  A prefix and extension are added automatically if required.
	- Objects (optional) - Objects to include when linking.
	- LinkFlags (optional) - Flags to use when linking.
	Creates a dynamic library.  Objects to link can be passed in explicitly, or Sources can be passed in which will be compiled and then linked.
	
]]


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

