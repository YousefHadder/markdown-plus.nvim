.PHONY: test test-coverage test-file test-watch lint format format-check check demo help

# Default target
help:
	@echo "markdown-plus.nvim - Makefile commands:"
	@echo ""
	@echo "  make test          - Run all tests"
	@echo "  make test-coverage - Run tests with coverage threshold checks"
	@echo "  make test-file     - Run specific test file (FILE=spec/path/to/file_spec.lua)"
	@echo "  make test-watch    - Watch files and run tests on change (requires entr)"
	@echo "  make lint          - Run luacheck linter"
	@echo "  make format        - Format all Lua files with stylua"
	@echo "  make format-check  - Check formatting without modifying files"
	@echo "  make check         - Run lint + format-check + test (CI checks)"
	@echo "  make demo          - Generate all demo GIFs (requires vhs)"
	@echo "  make help          - Show this help message"
	@echo ""

# Run all tests using plenary.nvim's test runner
test:
	@echo "Running all tests..."
	@# Check if plenary.nvim is available
	@if [ -n "$${PLENARY_DIR}" ] && [ -d "$${PLENARY_DIR}" ]; then \
		true; \
	elif [ -d "${HOME}/.local/share/nvim/site/pack/vendor/start/plenary.nvim" ]; then \
		true; \
	elif [ -d "${HOME}/.local/share/nvim/lazy/plenary.nvim" ]; then \
		true; \
	elif [ -d "${HOME}/.local/share/nvim/site/pack/packer/start/plenary.nvim" ]; then \
		true; \
	else \
		echo ""; \
		echo "⚠️  Tests require plenary.nvim to be installed"; \
		echo "   Install with your plugin manager or set PLENARY_DIR environment variable"; \
		echo ""; \
		exit 1; \
	fi
	@nvim --headless --noplugin -u spec/minimal_init.lua \
		-c "lua require('plenary.test_harness').test_directory('spec/', { minimal_init = 'spec/minimal_init.lua' })"

# Run tests with coverage threshold checks
test-coverage:
	@echo "Running tests with coverage checks..."
	@MARKDOWN_PLUS_ENFORCE_COVERAGE=1 ./scripts/test

# Run a specific test file
test-file:
	@if [ -z "$(FILE)" ]; then \
		echo "Error: FILE not specified"; \
		echo "Usage: make test-file FILE=spec/markdown-plus/config_spec.lua"; \
		exit 1; \
	fi
	@echo "Running test file: $(FILE)"
	@nvim --headless --noplugin -u spec/minimal_init.lua \
		-c "lua require('plenary.busted').run('$(FILE)')"

# Watch for file changes and run tests
test-watch:
	@command -v entr >/dev/null 2>&1 || \
		(echo "Error: 'entr' command not found"; \
		 echo "Install with: brew install entr (macOS) or apt-get install entr (Linux)"; exit 1)
	@echo "Watching for changes... (Press Ctrl+C to stop)"
	@find spec lua -name '*.lua' | entr -c make test

# Lint Lua code
lint:
	@command -v luacheck >/dev/null 2>&1 || \
		(echo "Error: 'luacheck' not found"; \
		 echo "Install with: luarocks install luacheck"; exit 1)
	@echo "Running luacheck..."
	@luacheck lua/ spec/ --globals vim

# Format Lua code with stylua
format:
	@command -v stylua >/dev/null 2>&1 || \
		(echo "Error: 'stylua' not found"; \
		 echo "Install with: cargo install stylua"; \
		 echo "Or on macOS: brew install stylua"; exit 1)
	@echo "Formatting Lua files with stylua..."
	@stylua lua/ spec/ plugin/

# Check formatting without modifying files
format-check:
	@command -v stylua >/dev/null 2>&1 || \
		(echo "Error: 'stylua' not found"; \
		 echo "Install with: cargo install stylua"; \
		 echo "Or on macOS: brew install stylua"; exit 1)
	@echo "Checking Lua formatting..."
	@stylua --check lua/ spec/ plugin/

# Run all CI checks (lint + format-check + test)
check: lint format-check test
	@echo "✓ All checks passed!"

# Generate demo GIFs
demo:
	@command -v vhs >/dev/null 2>&1 || \
		(echo "Error: 'vhs' not found"; \
		 echo "Install with: brew install vhs (macOS)"; \
		 echo "See: https://github.com/charmbracelet/vhs#installation"; exit 1)
	@echo "Generating demo GIFs..."
	@cd demo && for tape in *.tape; do \
		echo "  Generating $${tape}..."; \
		vhs "$${tape}"; \
	done
	@echo "Done! GIFs are in demo/ directory"
