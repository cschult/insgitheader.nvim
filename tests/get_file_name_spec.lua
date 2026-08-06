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
		-- Der chezmoi-Cache hängt an den Buffern, nicht am Modul
		vim._test.buffer_vars = {}
		original_popen = io.popen
		-- Vorgabe: chezmoi ist nicht installiert
		io.popen = popen_mock({})
		gfn = require("insgitheader.helper.get-file-name")
	end)

	after_each(function()
		io.popen = original_popen
	end)

	it("gibt den vollständigen Pufferpfad zurück", function()
		vim._test.bufname = "/home/user/project/file.lua"
		assert.are.equal("/home/user/project/file.lua", gfn.get_file_name())
	end)

	it("gibt leeren String zurück für unbenannten Puffer", function()
		vim._test.bufname = ""
		assert.are.equal("", gfn.get_file_name())
	end)

	describe("mode 'basename'", function()
		it("gibt nur den Dateinamen zurück", function()
			vim._test.bufname = "/home/user/project/file.lua"
			assert.are.equal("file.lua", gfn.get_file_name("basename"))
		end)

		it("kommt mit einem Pfad ohne Schrägstrich zurecht", function()
			vim._test.bufname = "file.lua"
			assert.are.equal("file.lua", gfn.get_file_name("basename"))
		end)

		it("gibt leeren String zurück für unbenannten Puffer", function()
			vim._test.bufname = ""
			assert.are.equal("", gfn.get_file_name("basename"))
		end)

		it("nimmt bei einer chezmoi-Quelldatei den Basename des Zielpfads", function()
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

		it("weist bei einer Quelldatei den Zielpfad aus", function()
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

		it("behält den echten Pfad wenn der Round-Trip fehlschlägt", function()
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

		it("behält bei einer Target-Datei den aktuellen Pfad", function()
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
