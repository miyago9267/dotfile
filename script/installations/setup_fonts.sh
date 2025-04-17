#!/bin/sh
curl -LO https://github.com/romkatv/powerlevel10k-media/raw/master/MesloLGS%20NF%20Regular.ttf
mkdir -p ~/.local/share/fonts
old_filename=$(ls | grep ttf)
new_filename=$(echo "$old_filename" | sed "s/%20/ /g")
mv "$old_filename" "$new_filename"
mv "$new_filename" ~/.local/share/fonts
fc-cache -f -v
