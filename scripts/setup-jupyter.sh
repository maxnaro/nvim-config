#!/usr/bin/env bash
set -euo pipefail
jupyter_env="${XDG_DATA_HOME:-$HOME/.local/share}/nvim/jupyter"
python3 -m venv "$jupyter_env"
"$jupyter_env/bin/python" -m pip install pynvim jupyter_client jupytext nbformat pillow ipykernel
mkdir -p "$HOME/.local/bin"
if ! command -v jupytext >/dev/null 2>&1; then
  ln -s "$jupyter_env/bin/jupytext" "$HOME/.local/bin/jupytext"
fi
"$jupyter_env/bin/python" -m ipykernel install --user --name nvim-python --display-name 'Neovim Python'
printf '%s\n' 'Restart Neovim, run :Lazy install, then :UpdateRemotePlugins and restart again.'
