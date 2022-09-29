#!/bin/bash
cmds=("cpp java")
args=("-d -f")
res[0]=" -Wall -g"
res[1]=" -D DEBUG"
debugArgs=""
fileTest=""

Y='\033[1;33m'
R='\033[0;31m'
G='\033[1;32m'
B='\033[1;34m'
N='\033[0m'
help="Usage: rc <cpp|java> <file> [-d|-f]"

for i in ${cmds[@]}; do
    if [ "$1" = "$i" ]; then
        cmd=$1
    fi
done

if [ "$cmd" = "" ]; then
    printf "${help}\n"
    exit 1
fi

if [ -f "./${2%.*}.cpp" ]; then
    fileName=`echo "${2%.*}"`
else
    printf "${R}No such file: ${Y}${2}${N}\n"
    printf "${help}\n"
fi
# fileName=$2
# echo $fileName

if [ "$3" = "-d" ] || [ "$4" = "-d" ]; then
    debugArgs=" -Wall -g"
fi

if [ "$3" = "-f" ] || [ "$4" = "-f" ]; then
    fileTest=" -D DEBUG"
fi

if [ "$cmd" = "cpp" ]; then
    g++$debugArgs$fileTest $fileName.cpp -o $fileName
    if [ -f "./${fileName}" ]; then
        printf "${G}Compile Success, executing now${N}\n"
        if [ "$debugArgs" != "" ]; then
		    gdb $FileName
        else
            ./${fileName}
        fi
        printf "${G}Done${N}\n"
    else
        printf "${R}Compile Error${N}\n"
        exit 1
    fi
elif [ "$cmd" = "java" ]; then
    javac $fileName.java
    if [ -f "./${fileName}.class" ]; then
        printf "${G}Compile Success, executing now${N}\n"
        if [ "$fileTest" != "" ]; then
            touch t.in
            java $fileName < t.in > t.out
        else 
            java $fileName
        fi
        printf "${G}Done${N}\n"
    else
        printf "${R}Compile Error${N}\n"
        exit 1
    fi
fi


# Go fuck urself
# safe=1
if [ "$safe" = "1" ]; then
    if [ -f "./${fileName}.class" ]; then
        rm -f $fileName.class
        rm -f t.in
        rm -f t.out
    elif [ -f "./${fileName}" ];  then
        rm -rf $fileName
    fi
fi
