test:
	nvim --headless --noplugin -u tests/init.lua -c "PlenaryBustedDirectory tests/$(file) {minimal_init = 'tests/init.lua'}"

install_typescript_version:
	npm i --prefix tests/ts_project typescript@$(version)

test_typescript_version: export TEST_TYPESCRIPT_VERSION=$(version)
test_typescript_version: install_typescript_version test

clean:
	rm -rf .tests/ tests/ts_project/node_modules
	npm --prefix tests/ts_project ci
