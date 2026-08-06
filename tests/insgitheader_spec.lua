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
		package.loaded["insgitheader.helper.get-chezmoi"] = nil
		package.loaded["insgitheader.helper.find-header"] = nil

		original_popen = io.popen
		original_getenv = os.getenv

		vim._test.commentstring = "-- %s"
		vim._test.bufname = "/project/src/file.lua"
		vim._test.reset({ "local x = 1" })

		-- io.popen-Mock: antwortet auf die einzelnen git-Befehle. chezmoi ist
		-- hier nicht installiert, das deckt der eigene Block weiter unten ab.
		io.popen = function(cmd)
			local result
			if cmd:match("^chezmoi") then
				result = nil
			elseif cmd:match("git config user%.name") then
				result = "Test User"
			elseif cmd:match("git config user%.email") then
				result = "test@example.com"
			elseif cmd:match("is%-inside%-work%-tree") then
				result = "true"
			elseif cmd:match("show%-toplevel") then
				result = "/project"
			end
			return {
				read = function(self, fmt)
					return result
				end,
				close = function(self) end,
			}
		end

		os.getenv = function()
			return nil
		end

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
			assert.truthy(vim._test.lines[3]:match("Jane Doe"))
		end)

		it("überschreibt die E-Mail-Adresse", function()
			ins.setup({ name = "Jane Doe", email = "jane@example.com" })
			ins.insert_headers()
			assert.truthy(vim._test.lines[3]:match("jane@example%.com"))
		end)

		it("lässt Name und E-Mail unverändert wenn opts leer", function()
			ins.setup({})
			ins.insert_headers()
			assert.truthy(vim._test.lines[3]:match("Test User"))
			assert.truthy(vim._test.lines[3]:match("test@example%.com"))
		end)

		it("schreibt vorgabegemäß den vollständigen Pfad", function()
			ins.setup({})
			ins.insert_headers()
			assert.are.equal("-- file: /project/src/file.lua", vim._test.lines[1])
		end)

		it("schreibt mit path='basename' nur den Dateinamen", function()
			ins.setup({ path = "basename" })
			ins.insert_headers()
			assert.are.equal("-- file: file.lua", vim._test.lines[1])
		end)

		it("schreibt mit path='full' den vollständigen Pfad", function()
			ins.setup({ path = "full" })
			ins.insert_headers()
			assert.are.equal("-- file: /project/src/file.lua", vim._test.lines[1])
		end)

		it("warnt bei unbekanntem path-Wert und behält die Vorgabe", function()
			ins.setup({ path = "relative" })
			ins.insert_headers()
			assert.are.equal(1, #vim._test.notifications)
			assert.truthy(vim._test.notifications[1].msg:match("unknown path option"))
			assert.are.equal(vim.log.levels.WARN, vim._test.notifications[1].level)
			assert.are.equal("-- file: /project/src/file.lua", vim._test.lines[1])
		end)

		it("aktualisiert einen bestehenden Header nach path='basename'", function()
			vim._test.reset({
				"-- file: /project/src/file.lua",
				"-- git: /project",
				"-- author: Test User <test@example.com> 2026",
				"",
			})
			ins.setup({ path = "basename" })
			ins.insert_headers()
			assert.are.equal("-- file: file.lua", vim._test.lines[1])
			assert.are.equal(4, #vim._test.lines)
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
			assert.truthy(vim._test.lines[1]:match("file%.lua"))
		end)

		it("erste Zeile beginnt mit dem Kommentarsymbol", function()
			ins.insert_headers()
			assert.truthy(vim._test.lines[1]:match("^%-%-"))
		end)

		it("zweite Zeile enthält den Repo-Pfad", function()
			ins.insert_headers()
			assert.truthy(vim._test.lines[2]:match("/project"))
		end)

		it("dritte Zeile enthält das aktuelle Jahr", function()
			ins.insert_headers()
			local year = tostring(os.date("%Y"))
			assert.truthy(vim._test.lines[3]:match(year))
		end)

		it("setzt die E-Mail in spitze Klammern", function()
			ins.insert_headers()
			assert.truthy(vim._test.lines[3]:match("<test@example%.com>"))
		end)

		it("vierte Zeile ist leer", function()
			ins.insert_headers()
			assert.are.equal("", vim._test.lines[4])
		end)

		it("lässt den restlichen Pufferinhalt stehen", function()
			ins.insert_headers()
			assert.are.equal("local x = 1", vim._test.lines[5])
		end)

		it("verwendet rechtes Kommentarsymbol bei Blockkommentaren", function()
			vim._test.commentstring = "/* %s */"
			package.loaded["insgitheader.helper.get-comment-chars"] = nil
			ins.insert_headers()
			assert.truthy(vim._test.lines[1]:match("%*/$"))
		end)

		it("fällt auf '#' zurück wenn kein commentstring gesetzt", function()
			vim._test.commentstring = ""
			package.loaded["insgitheader.helper.get-comment-chars"] = nil
			ins.insert_headers()
			assert.truthy(vim._test.lines[1]:match("^#"))
		end)

		it("verdoppelt eine vorhandene Leerzeile am Blockende nicht", function()
			vim._test.reset({ "", "local x = 1" })
			ins.insert_headers()
			assert.are.equal(3, #vim._test.set_lines)
			assert.are.equal("", vim._test.lines[4])
			assert.are.equal("local x = 1", vim._test.lines[5])
		end)

		it("setzt den Cursor auf die file:-Zeile", function()
			ins.insert_headers()
			assert.are.same({ 1, 0 }, vim._test.cursor)
		end)

		it("lässt die git-Zeile leer wenn kein Repo gefunden wird", function()
			io.popen = function(cmd)
				local result
				if cmd:match("git config user%.name") then
					result = "Test User"
				elseif cmd:match("git config user%.email") then
					result = "test@example.com"
				end
				return {
					read = function(self, fmt)
						return result
					end,
					close = function(self) end,
				}
			end
			package.loaded["insgitheader.helper.get-repo-name"] = nil
			package.loaded["insgitheader.helper.get-chezmoi"] = nil
			ins.insert_headers()
			assert.are.equal("--", vim._test.lines[2])
		end)
	end)
end)
