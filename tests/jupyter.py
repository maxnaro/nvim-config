"""Run using ~/.local/share/nvim/jupyter/bin/python tests/jupyter.py."""
import json
import os
from pathlib import Path
import subprocess
import tempfile
import nbformat

root = Path(__file__).resolve().parents[1]
with tempfile.TemporaryDirectory(prefix='nvim notebook ') as directory:
    notebook = Path(directory) / 'test notebook.ipynb'
    original = nbformat.v4.new_notebook(
        metadata={'kernelspec': {'name': 'nvim-python', 'display_name': 'Neovim Python', 'language': 'python'}, 'custom': 'keep'},
        cells=[nbformat.v4.new_markdown_cell('# Keep prose'), nbformat.v4.new_code_cell('value = 40\nprint(value + 2)'), nbformat.v4.new_code_cell('print(7)', execution_count=1, outputs=[nbformat.v4.new_output('stream', name='stdout', text='7\n')])],
    )
    nbformat.write(original, notebook)
    lua = Path(directory) / 'check.lua'
    lua.write_text('''
local path = vim.env.NOTEBOOK_TEST
assert(vim.bo.filetype == "python", "notebook did not convert")
assert(vim.fn.search("# %%", "nw") > 0)
vim.cmd("MoltenInit nvim-python")
assert(vim.wait(15000, function() return vim.fn.MoltenStatusLineInit() == "Molten" end, 100))
vim.wait(1000)
local line = vim.fn.search("value = 40", "w")
assert(line > 0)
vim.fn.MoltenEvaluateRange(line, line + 1)
vim.wait(5000)
vim.cmd("write")
vim.wait(1000)
vim.cmd("MoltenDeinit")
vim.cmd("qa!")
''')
    result = subprocess.run(['nvim', '--headless', str(notebook), '-c', 'lua dofile(vim.env.NOTEBOOK_LUA)'],
        env=dict(os.environ, NOTEBOOK_TEST=str(notebook), NOTEBOOK_LUA=str(lua)), capture_output=True, text=True, timeout=40)
    assert result.returncode == 0, result.stdout + result.stderr
    saved = nbformat.read(notebook, as_version=4)
    assert saved.metadata.custom == 'keep'
    assert saved.cells[0].source == '# Keep prose'
    assert '42' in json.dumps(saved.cells[1].outputs), (saved, result.stderr)
    assert '7' in json.dumps(saved.cells[2].outputs), saved
    print('Notebook conversion, live kernel, and output round-trip passed')
