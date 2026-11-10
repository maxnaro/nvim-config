# PlantUML language server

Install [plantuml-lsp](https://github.com/ptdewey/plantuml-lsp) with
`go install github.com/ptdewey/plantuml-lsp@latest` and ensure Go's bin
directory is on Neovim's PATH. Mason does not install this server.

Files ending in `.puml` or `.plantuml` use the server. Install the `plantuml`
executable as well to enable syntax diagnostics; it must be on PATH when
Neovim starts. The server also supports an optional `--stdlib-path` for stdlib
completion and navigation; see its upstream documentation to set that up and
add the flag to `lua/plugins/plantuml.lua` if needed.

Open a diagram and use `:LspInfo` to check attachment. The server is early in
development, so some language features may be incomplete.
