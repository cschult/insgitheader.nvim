-- Sets package.path so that require() finds the plugin modules
package.path = "./lua/?.lua;./lua/?/init.lua;" .. package.path

-- vim API stub: simulates the Neovim API for the tests
_G.vim = {
	api = {
		nvim_get_current_buf = function()
			return 1
		end,
		nvim_get_option_value = function(name, opts)
			return _G.vim._test.commentstring
		end,
		-- Individual tests can register a per-buffer name in _test.bufnames;
		-- otherwise _test.bufname applies to every buffer.
		nvim_buf_get_name = function(n)
			return _G.vim._test.bufnames[n] or _G.vim._test.bufname
		end,
		nvim_buf_is_valid = function(n)
			return _G.vim._test.invalid_bufs[n] ~= true
		end,
		nvim_create_augroup = function(name, opts)
			_G.vim._test.augroups[#_G.vim._test.augroups + 1] = { name = name, opts = opts }
			return name
		end,
		nvim_create_autocmd = function(event, opts)
			_G.vim._test.autocmds[#_G.vim._test.autocmds + 1] = { event = event, opts = opts }
		end,
		nvim_create_user_command = function(name, fn, opts)
			_G.vim._test.commands[name] = { fn = fn, opts = opts }
		end,
		nvim_buf_get_lines = function(buf, start, end_, strict)
			local copy = {}
			for i, line in ipairs(_G.vim._test.lines) do
				copy[i] = line
			end
			return copy
		end,
		-- Really applies the change to _test.lines, so that tests can assert the
		-- result. Same semantics as in Neovim: start 0-based, end_ exclusive,
		-- negative values count from the end of the file.
		nvim_buf_set_lines = function(buf, start, end_, strict, lines)
			local buffer = _G.vim._test.lines
			if end_ < 0 then
				end_ = #buffer + 1 + end_
			end
			local out = {}
			for i = 1, start do
				out[#out + 1] = buffer[i]
			end
			for _, line in ipairs(lines) do
				out[#out + 1] = line
			end
			for i = end_ + 1, #buffer do
				out[#out + 1] = buffer[i]
			end
			_G.vim._test.lines = out
			_G.vim._test.set_lines = lines
		end,
		nvim_win_set_cursor = function(win, pos)
			_G.vim._test.cursor = pos
		end,
	},
	notify = function(msg, level)
		table.insert(_G.vim._test.notifications, { msg = msg, level = level })
	end,
	inspect = function(value)
		if type(value) == "string" then
			return '"' .. value .. '"'
		end
		return tostring(value)
	end,
	log = {
		levels = { TRACE = 0, DEBUG = 1, INFO = 2, WARN = 3, ERROR = 4 },
	},
	-- Values that individual tests can override
	_test = {
		commentstring = "-- %s",
		bufname = "/test/file.lua",
		bufnames = {},
		invalid_bufs = {},
		lines = { "" },
		set_lines = nil,
		cursor = nil,
		notifications = {},
		augroups = {},
		autocmds = {},
		commands = {},
		buffer_vars = {},
	},
}

-- vim.b[bufnr] behaves as it does in Neovim: assignments stick to the buffer,
-- deleted and never-set keys return nil.
_G.vim.b = setmetatable({}, {
	__index = function(_, bufnr)
		local vars = _G.vim._test.buffer_vars
		vars[bufnr] = vars[bufnr] or {}
		return vars[bufnr]
	end,
})

-- Resets the simulated buffer; `lines` is the initial content.
function _G.vim._test.reset(lines)
	_G.vim._test.lines = lines or { "" }
	_G.vim._test.set_lines = nil
	_G.vim._test.cursor = nil
	_G.vim._test.notifications = {}
	_G.vim._test.bufnames = {}
	_G.vim._test.invalid_bufs = {}
	_G.vim._test.augroups = {}
	_G.vim._test.autocmds = {}
	_G.vim._test.commands = {}
	_G.vim._test.buffer_vars = {}
end
