test:
	nvim --headless --noplugin -u tests/minimal.vim -c "PlenaryBustedDirectory tests/$(file) {minimal_init = 'tests/minimal.vim'}"

install_typescript_version:
	npm i --prefix tests/ts_project typescript@$(version)

test_typescript_version: export TEST_TYPESCRIPT_VERSION=$(version)
test_typescript_version: install_typescript_version test
