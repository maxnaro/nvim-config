# Neovim configuration

Personal [LazyVim](https://www.lazyvim.org/) configuration, extracted with its
history from [wsl-dotfiles](https://github.com/maxnaro/wsl-dotfiles).

## Installation

Requires Neovim 0.11.6 or newer, Git, a C compiler, and the other
[LazyVim requirements](https://www.lazyvim.org/). Install a Nerd Font in your
terminal for icons. Ripgrep, fd, and LazyGit are recommended for search and Git
integration; language tools may have their own runtime requirements.

Move any existing `~/.config/nvim` aside before cloning:

```bash
git clone git@github.com:maxnaro/nvim-config.git ~/.config/nvim
nvim
```

Lazy installs plugins on first launch using the committed `lazy-lock.json`.

Alternatively, use the parent dotfiles repository's `./setup.sh` or `stow -R nvim`.
It includes this repository as a submodule at `nvim/.config/nvim` and symlinks it
to `~/.config/nvim`.

## Configuration

- `init.lua` and `lua/config/lazy.lua`: LazyVim bootstrap and plugin setup.
- `lua/config/`: options, keymaps, autocommands, AI state, and shared theme palette.
- `lua/plugins/`: completion, Copilot, status line, navigation, and language tools.
- `lazyvim.json`: enabled LazyVim extras.
- `lazy-lock.json`: pinned plugin revisions.

The compact, transparent status line shows file changes, Git details,
diagnostics, cursor position, and macro recording. Buffer tabs are disabled;
native tab pages remain available.

Shared light mode loads `morhetz/gruvbox` with medium contrast; dark mode uses
Chocolatier. Editor backgrounds, floats, gutters, and status lines remain
transparent. Selection and completion surfaces retain their colours. The shared
`dotfiles-theme` command switches open editors live.

Space is the leader key:

| Shortcut | Action |
| --- | --- |
| `H` / `L`, `[b` / `]b` | Previous / next buffer |
| `Space ,` | Buffer picker |
| `Space bb` | Alternate buffer |
| `Space gg`, `Space lg` | LazyGit at the project Git root |
| `Space gG` | LazyGit at Neovim's working directory |
| `Space gf` | Current-file Git history |
| `Space lz` | Plugin manager |
| `Space cl` | LSP info |
| `Space cLh/j/s/w` | Live Share host / join / stop / workspace |
| `Space qs`, `Space qS` | Restore project session / select session |
| `Space sr` | Search and replace |
| `Space gh` | Git hunk actions |
| `Space wm`, `Space uz` | Zoom window / zen mode |
| `Space au` | Toggle Copilot across buffers |

Alt-h/j/k/l navigate editor splits and tmux panes from Normal, Insert, Visual,
and terminal modes. Navigation leaves input/selection mode; picker-local keys
remain available, including Alt-h to toggle hidden files.

## DBML language server

Install the [DBML language server](https://github.com/kamal-hamza/dbml-language-server)
with `cargo install dbml-language-server` and ensure Cargo's bin directory is
on Neovim's PATH. Mason does not install this server. Open a `.dbml` file and
use `:LspInfo` to check attachment; standalone files work outside Git projects.

For diagrams, install `npm install -g @softwaretechnik/dbml-renderer` and ensure
`dbml-renderer` is on PATH. `:DBMLPreview` (or `Space cp` in a DBML buffer)
renders the current buffer, including unsaved edits, as SVG and opens it using the
system viewer. On WSL, preview uses `wslpath` and Windows `explorer.exe`; Windows
interop and a Windows SVG viewer or browser association are required.
`:DBMLExport` (or `Space ce` in a DBML buffer) writes an SVG next to the source
file; `:DBMLExport path/to/diagram.svg` chooses a path. Existing files are
protected unless you use `:DBMLExport!`. These commands render locally.

## Markdown formatting

Markdown and MDX buffers run Prettier followed by `markdownlint-cli2 --fix`
on save or with `Space cf`, even before lint diagnostics appear. A table of
contents is also updated when the file contains `<!-- toc -->`. Mason installs
the tools through the LazyVim Markdown and Prettier extras; use `:ConformInfo`
to check their availability. Prettier wraps prose (overriding its `proseWrap`
setting) at its configured `printWidth`, 80 by default. Set that width to match
the project's markdownlint MD013 line-length rule. Long URLs, tables, code blocks,
and other unbreakable content may still need manual attention or rule exceptions.
Not every markdownlint issue can be fixed automatically; remaining diagnostics
need manual edits. Prettier and markdownlint rules should be configured
compatibly in each project.

## SQL formatting

The LazyVim SQL extra installs SQLFluff through Mason. SQL, MySQL, and PL/SQL
buffers use it for formatting on save and with `Space cf`; formatting also works
without a project configuration. Use `:ConformInfo` to check availability and
inspect the formatter log if formatting fails.

The extra currently passes `--dialect=ansi`, overriding the dialect in a project
`.sqlfluff` file. For database-specific syntax, change the SQLFluff `args` in
`lua/plugins/formatting.lua` to use the desired dialect (or remove the flag and
set `dialect` in each project's SQLFluff configuration). SQLFluff may refuse to
format SQL it cannot parse, including incomplete statements.

## AI completion

Copilot starts disabled in each session. Enable it with `Space au`, then run
`:Copilot auth` to sign in. Copilot access is required; its native language server
downloads on first use. Explicit `:Copilot` commands also load the plugin.

Tab accepts regular completion first, advances snippet placeholders, then
accepts AI ghost text or opens completions after a typed word. Otherwise it
inserts a normal Tab. Shift-Tab selects the previous completion or snippet
placeholder. AI text hides while the regular completion menu is open.
Alt-`]` / Alt-`[` cycle AI suggestions; Ctrl-`]` dismisses them.

The toggle does not persist between sessions. Chat, assistant terminals, and
next-edit suggestions are not enabled.

## Jupyter notebooks

Python `.ipynb` notebooks open as Python `# %%` cells with commented Markdown,
using Jupytext. Existing Python completion and formatting remain available.
Run `bash ~/.config/nvim/scripts/setup-jupyter.sh` once (Python 3.10+ required),
ensure `~/.local/bin` is on PATH, then follow its restart instructions.
Dependencies live in `${XDG_DATA_HOME:-~/.local/share}/nvim/jupyter`, separate
from project environments. Plugins are pinned in `lazy-lock.json`.

| Shortcut | Action |
| --- | --- |
| `Space ji` | Select and start a Jupyter kernel |
| `Space jr` | Run current cell or visual selection |
| `Space jn` | Run cell and advance |
| `Space ja` | Run all cells |
| `[j` / `]j` | Previous / next cell |
| `Space jo` | Open cell output |
| `Space jp` | Open plot in the system image viewer |
| `Space jx` / `Space jR` | Interrupt / restart kernel |

Kernels start explicitly; opening a notebook never executes its code. Existing
outputs load when its kernel starts. `:write` saves source first, then exports
results into the same notebook. Wait for execution to finish before saving final
results. Text output appears below cells; images use an external viewer through
Pillow (`xdg-open` on Linux, requiring a working desktop image association).
Use `:MoltenDeinit` to stop the current kernel. Quarto, inline images, and browser
widgets are not configured.

Choose `nvim-python` for the isolated default environment. For project packages,
activate the project environment and run `python -m pip install ipykernel`, then
`python -m ipykernel install --user --name my-project`. Select `my-project` with
`Space ji`. `:VenvSelect` affects Python tooling, not the running Jupyter kernel.

To create a notebook, write a Python file with `# %%` separators and run
`jupytext --to ipynb notebook.py`, then open the resulting `.ipynb` file. Jupytext
uses a sibling Python file while editing; avoid editing both representations at
once. An existing sibling is retained and used as the text source.

If notebooks show JSON, check `:!jupytext --version` and `:Lazy`. If Molten commands
are missing, run `:UpdateRemotePlugins` and restart. Use `:checkhealth provider`
and `:checkhealth molten` to diagnose Python dependencies. Ordinary editing
remains available without notebook dependencies; notebook commands require setup.


## Updating

For a standalone installation, run `git pull --ff-only` in `~/.config/nvim`.
Use `:Lazy` to manage plugins and commit intentional lockfile updates here.

When working through wsl-dotfiles, commit and push configuration changes in this
repository first, then commit the updated submodule pointer in wsl-dotfiles:

```bash
cd ~/dotfiles/nvim/.config/nvim
git switch main
# Edit, commit, and push changes here.
cd ../../..
git add nvim/.config/nvim
git commit -m "chore(nvim): update configuration submodule"
```

After pulling parent-repository updates, run `git submodule update --init --recursive`.

## License

See [LICENSE](LICENSE) (Apache-2.0, retained from the LazyVim starter).
