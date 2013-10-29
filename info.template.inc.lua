Info =
{
	ProjectName = '',
	Company = '',
	ShortDescription = '', -- One sentence
	ExtendedDescription = '', -- Three sentences
	Version = 0,
	Website = 'http://www.zarbosoft.com/PACKAGENAME',
	Forum = 'http://www.zarbosoft.com/forum/index.php?board=BOARDNUMBER',
	CompanyWebsite = 'http://www.zarbosoft.com/',
	Author = 'Rendaw',
	EMail = 'spoo@zarbosoft.com'
}

if arg and arg[1]
then
	print(Info[arg[1]])
end

