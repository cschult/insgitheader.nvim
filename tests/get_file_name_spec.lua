describe("get-file-name", function()
	local gfn
	local original_popen

	local SRC = "/home/user/.local/share/chezmoi"

	local function popen_mock(rules)
		return function(cmd)
			local result
			for _, rule in ipairs(rules) do
				if cmd:match(rule[1]) then
					result = rule[2]
					break
				end
			end
			return {
				read = function(self, fmt)
					return result
				end,
				close = function(self) end,
			}
		end
	end

	before_each(function()
		package.loaded["insgitheader.helper.get-file-name"] = nil
		package.loaded["insgitheader.helper.get-chezmoi"] = nil
		-- The chezmoi cache sits on the buffers, not on the module
		vim._test.buffer_vars = {}
		original_popen = io.popen
		-- Default: chezmoi is not installed
		io.popen = popen_mock({})
		gfn = require("insgitheader.helper.get-file-name")
	end)

	after_each(function()
		io.popen = original_popen
	end)

	it("should return the full buffer path", function()
		vim._test.bufname = "/home/user/project/file.lua"
		assert.are.equal("/home/user/project/file.lua", gfn.get_file_name())
	end)

	it("should return an empty string for an unnamed buffer", function()
		vim._test.bufname = ""
		assert.are.equal("", gfn.get_file_name())
	end)

	describe("mode 'basename'", function()
		it("should return the file name only", function()
			vim._test.bufname = "/home/user/project/file.lua"
			assert.are.equal("file.lua", gfn.get_file_name("basename"))
		end)

		it("should cope with a path without a slash", function()
			vim._test.bufname = "file.lua"
			assert.are.equal("file.lua", gfn.get_file_name("basename"))
		end)

		it("should return an empty string for an unnamed buffer", function()
			vim._test.bufname = ""
			assert.are.equal("", gfn.get_file_name("basename"))
		end)

		it("should take the basename of the target path for a chezmoi source file", function()
			vim._test.bufname = SRC .. "/dot_bashrc.tmpl"
			io.popen = popen_mock({
				{ "^chezmoi source%-path 2>", SRC },
				{ "^chezmoi target%-path ", "/home/user/.bashrc" },
				{ "^chezmoi source%-path ", SRC .. "/dot_bashrc.tmpl" },
				{ "show%-toplevel", SRC },
			})
			package.loaded["insgitheader.helper.get-file-name"] = nil
			package.loaded["insgitheader.helper.get-chezmoi"] = nil
			gfn = require("insgitheader.helper.get-file-name")
			assert.are.equal(".bashrc", gfn.get_file_name("basename"))
		end)
	end)

	describe("chezmoi", function()
		before_each(function()
			package.loaded["insgitheader.helper.get-file-name"] = nil
			package.loaded["insgitheader.helper.get-chezmoi"] = nil
		end)

		it("should show the target path for a source file", function()
			vim._test.bufname = SRC .. "/dot_bashrc.tmpl"
			io.popen = popen_mock({
				{ "^chezmoi source%-path 2>", SRC },
				{ "^chezmoi target%-path ", "/home/user/.bashrc" },
				{ "^chezmoi source%-path ", SRC .. "/dot_bashrc.tmpl" },
				{ "show%-toplevel", SRC },
			})
			gfn = require("insgitheader.helper.get-file-name")
			assert.are.equal("/home/user/.bashrc", gfn.get_file_name())
		end)

		it("should keep the real path if the round-trip fails", function()
			vim._test.bufname = SRC .. "/README.md"
			io.popen = popen_mock({
				{ "^chezmoi source%-path 2>", SRC },
				{ "^chezmoi target%-path ", "/home/user/README.md" },
				{ "^chezmoi source%-path ", nil },
				{ "show%-toplevel", SRC },
			})
			gfn = require("insgitheader.helper.get-file-name")
			assert.are.equal(SRC .. "/README.md", gfn.get_file_name())
		end)

		it("should keep the current path for a target file", function()
			vim._test.bufname = "/home/user/.bashrc"
			io.popen = popen_mock({
				{ "^chezmoi source%-path 2>", SRC },
				{ "^chezmoi source%-path ", SRC .. "/dot_bashrc.tmpl" },
				{ "show%-toplevel", SRC },
			})
			gfn = require("insgitheader.helper.get-file-name")
			assert.are.equal("/home/user/.bashrc", gfn.get_file_name())
		end)
	end)
end)
