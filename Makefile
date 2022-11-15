test:
	nvim --headless --noplugin -u tests/minimal.vim -c "PlenaryBustedDirectory tests/$(file) {minimal_init = 'tests/minimal.vim'}"
