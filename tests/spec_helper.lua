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
		nvim_buf_get_name = function(n)
			return _G.vim._test.bufname
		end,
		nvim_buf_set_lines = function(buf, start, end_, strict, lines)
			_G.vim._test.set_lines = lines
		end,
	},
	-- Werte die einzelne Tests überschreiben können
	_test = {
		commentstring = "-- %s",
		bufname = "/test/file.lua",
		set_lines = nil,
	},
}
