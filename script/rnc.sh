FileName=$1
F=""
D=""
if [ "$FileName" = "*.cpp" ]; then
	echo "\e[1;1;31mNo fucking cpp file to input\e[0m"
	exit 1
fi
if [ -f "./${FileName}" ]; then
	rm -rf $FileName
fi
if [ "$2" = "-d" ]; then
	D="-Wall -g"
fi
if [ "$3" = "-d" ]; then
	D="-Wall -g"
fi
if [ "$2" = "-f" ]; then
	F="-D DEBUG"
fi
if [ "$3" = "-f" ]; then
	F="-D DEBUG"
fi
g++ $FileName.cpp $D $F -o $FileName
if [ -f "./${FileName}" ]; then
	if [ "$D" != "" ]; then
		gdb $FileName
	else
		echo "\e[1;32mCompile Success, executing now\e[0m"
		./$FileName
	fi
else
	echo "\e[1;31mCompile Error\e[0m"
fi
rm -rf $FileName
