.PHONY: test

# Dependency: luarocks install busted
test:
	busted tests/
