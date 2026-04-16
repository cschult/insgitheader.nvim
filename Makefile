.PHONY: test

# Abhängigkeit: luarocks install busted
test:
	busted tests/
