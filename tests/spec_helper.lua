-- Setzt package.path damit require() die Plugin-Module findet
package.path = "./lua/?.lua;./lua/?/init.lua;" .. package.path

-- vim-API-Stub: simuliert die Neovim-API für Tests
_G.vim = {
	api = {
		nvim_get_current_buf = function()
			return 1
		end,
		nvim_get_option_value = function(name, opts)
			return _G.vim._test.commentstring
		end,
		-- Einzelne Tests können pro Buffer einen Namen in _test.bufnames
		-- hinterlegen; sonst gilt für alle Buffer _test.bufname.
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
		-- Wendet die Änderung wirklich auf _test.lines an, damit Tests das
		-- Ergebnis prüfen können. Semantik wie in Neovim: start 0-basiert,
		-- end_ exklusiv, negative Werte zählen vom Dateiende.
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
	-- Werte die einzelne Tests überschreiben können
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

-- vim.b[bufnr] verhält sich wie in Neovim: Zuweisungen bleiben am Buffer
-- hängen, Löschen und nie gesetzte Schlüssel liefern nil.
_G.vim.b = setmetatable({}, {
	__index = function(_, bufnr)
		local vars = _G.vim._test.buffer_vars
		vars[bufnr] = vars[bufnr] or {}
		return vars[bufnr]
	end,
})

-- Setzt den simulierten Puffer zurück; `lines` ist der Ausgangsinhalt.
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
