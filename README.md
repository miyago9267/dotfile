# Dotfile

## Usage

1. Clone this repo.
2. `cd` to `dotfile` folder
3. **remove the safe in `setup.sh`** and run `setup.sh`

> Warning! This script will modified your setting, please use after thinking.
> I'm not responsible for any damage caused by this script

```shell
git clone https://github.com/miyago9267/dotfile.git && cd dotfile
sh shell
```

## File Structure

```tree
.
├── nvim
│   ├── coc-config.vim
│   ├── init.lua
│   ├── lazy-lock.json
│   └── pack/
├── script
│   ├── installations
│   └── utils
├── template
│   └── template.cpp
└── tmux
│   ├── base.conf
│   └── nvim-extension.conf
├── alias.sh
├── init.vim
├── setup.sh
├── README.md
```

## How it work

1. Check what os you use and use the corresponding package manager to install package
2. Download the plugin.
3. Setup the plugin.
4. Link the configure file.
5. Done owo !!!
