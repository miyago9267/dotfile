case=$1
file="cpp"
file=$2
dir=$(pwd)
path="/public/miyago/ContestWriteUp/uva"
if [ ! -f "${path}/other/${case}/sol.${2}" ]; then
    touch $path/other/$case/sol.$file
fi
ln -s $path/other/$case/sol.$file /$dir/sol.$file
