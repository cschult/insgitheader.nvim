describe("insgitheader", function()
	local ins
	local original_popen
	local original_getenv

	before_each(function()
		-- Alle gecachten Module verwerfen
		package.loaded["insgitheader"] = nil
		package.loaded["insgitheader.helper.get-comment-chars"] = nil
		package.loaded["insgitheader.helper.get-file-name"] = nil
		package.loaded["insgitheader.helper.get-git-config-user"] = nil
		package.loaded["insgitheader.helper.get-repo-name"] = nil

		original_popen = io.popen
		original_getenv = os.getenv

		vim._test.commentstring = "-- %s"
		vim._test.bufname = "/project/src/file.lua"
		vim._test.set_lines = nil

		-- io.popen-Mock: antwortet auf die einzelnen git-Befehle
		io.popen = function(cmd)
			local result
			if cmd:match("git config user%.name") then
				result = "Test User"
			elseif cmd:match("git config user%.email") then
				result = "test@example.com"
			elseif cmd:match("is%-inside%-work%-tree") then
				result = "true"
			elseif cmd:match("show%-toplevel") then
				result = "/project"
			end
			return {
				read = function(self, fmt) return result end,
				close = function(self) end,
			}
		end

		os.getenv = function() return nil end

		ins = require("insgitheader")
	end)

	after_each(function()
		io.popen = original_popen
		os.getenv = original_getenv
	end)

	describe("setup()", function()
		it("überschreibt den Autorennamen", function()
			ins.setup({ name = "Jane Doe", email = "jane@example.com" })
			ins.insert_headers()
			assert.truthy(vim._test.set_lines[3]:match("Jane Doe"))
		end)

		it("überschreibt die E-Mail-Adresse", function()
			ins.setup({ name = "Jane Doe", email = "jane@example.com" })
			ins.insert_headers()
			assert.truthy(vim._test.set_lines[3]:match("jane@example.com"))
		end)

		it("lässt Name und E-Mail unverändert wenn opts leer", function()
			ins.setup({})
			ins.insert_headers()
			assert.truthy(vim._test.set_lines[3]:match("Test User"))
			assert.truthy(vim._test.set_lines[3]:match("test@example.com"))
		end)
	end)

	describe("insert_headers()", function()
		before_each(function()
			ins.setup({})
		end)

		it("fügt genau 4 Zeilen ein (3 Header + Leerzeile)", function()
			ins.insert_headers()
			assert.are.equal(4, #vim._test.set_lines)
		end)

		it("erste Zeile enthält den Dateinamen", function()
			ins.insert_headers()
			assert.truthy(vim._test.set_lines[1]:match("file.lua"))
		end)

		it("erste Zeile beginnt mit dem Kommentarsymbol", function()
			ins.insert_headers()
			assert.truthy(vim._test.set_lines[1]:match("^%-%-"))
		end)

		it("zweite Zeile enthält den Repo-Pfad", function()
			ins.insert_headers()
			assert.truthy(vim._test.set_lines[2]:match("/project"))
		end)

		it("dritte Zeile enthält das aktuelle Jahr", function()
			ins.insert_headers()
			local year = tostring(os.date("%Y"))
			assert.truthy(vim._test.set_lines[3]:match(year))
		end)

		it("vierte Zeile ist leer", function()
			ins.insert_headers()
			assert.are.equal("", vim._test.set_lines[4])
		end)

		it("verwendet rechtes Kommentarsymbol bei Blockkommentaren", function()
			vim._test.commentstring = "/* %s */"
			package.loaded["insgitheader.helper.get-comment-chars"] = nil
			ins.insert_headers()
			assert.truthy(vim._test.set_lines[1]:match("%*/"))
		end)

		it("fällt auf '#' zurück wenn kein commentstring gesetzt", function()
			vim._test.commentstring = ""
			package.loaded["insgitheader.helper.get-comment-chars"] = nil
			ins.insert_headers()
			assert.truthy(vim._test.set_lines[1]:match("^#"))
		end)
	end)
end)
