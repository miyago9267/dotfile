#!/bin/sh
# Install Poetry
curl -sSL https://install.python-poetry.org | python3 -
# Install UV
curl -LsSf https://astral.sh/uv/install.sh | sh
# Install Pyenv
git clone https://github.com/pyenv/pyenv.git ~/.pyenv