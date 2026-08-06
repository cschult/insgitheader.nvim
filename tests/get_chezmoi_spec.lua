describe("get-chezmoi", function()
	local gc
	local original_popen
	local calls

	local SRC = "/home/user/.local/share/chezmoi"

	-- Zählt jeden Aufruf mit und beantwortet ihn nach der ersten passenden
	-- Regel; ohne Treffer kommt nil zurück.
	local function popen_mock(rules)
		return function(cmd)
			calls[#calls + 1] = cmd
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

	local function count(pattern)
		local n = 0
		for _, cmd in ipairs(calls) do
			if cmd:match(pattern) then
				n = n + 1
			end
		end
		return n
	end

	-- Der Standardfall: chezmoi ist da, /home/user/.bashrc ist verwaltet.
	local function chezmoi_available()
		return popen_mock({
			{ "^chezmoi source%-path 2>", SRC },
			{ "^chezmoi target%-path ", "/home/user/.bashrc" },
			{ "^chezmoi source%-path ", SRC .. "/dot_bashrc.tmpl" },
			{ "show%-toplevel", SRC },
		})
	end

	before_each(function()
		package.loaded["insgitheader.helper.get-chezmoi"] = nil
		original_popen = io.popen
		calls = {}
		vim._test.reset()
		vim._test.bufname = "/home/user/.bashrc"
		io.popen = chezmoi_available()
		gc = require("insgitheader.helper.get-chezmoi")
	end)

	after_each(function()
		io.popen = original_popen
	end)

	describe("Buffer-Cache", function()
		it("beantwortet den zweiten Aufruf ohne Prozessstart", function()
			local is_chezmoi, repo = gc.lookup(1)
			assert.is_true(is_chezmoi)
			assert.are.equal(SRC, repo)
			local before = #calls

			assert.is_true((gc.lookup(1)))
			assert.are.equal(before, #calls)
		end)

		it("legt das Ergebnis in b:insgitheader_chezmoi ab", function()
			gc.lookup(1)
			local cached = vim.b[1].insgitheader_chezmoi
			assert.are.equal("/home/user/.bashrc", cached.path)
			assert.is_true(cached.is_chezmoi)
			assert.are.equal(SRC, cached.repo)
		end)

		it("cacht auch ein negatives Ergebnis", function()
			vim._test.bufname = "/home/user/project/file.lua"
			io.popen = popen_mock({
				{ "^chezmoi source%-path 2>", SRC },
				{ "^chezmoi source%-path ", nil },
			})
			assert.is_false((gc.lookup(1)))
			local before = #calls

			assert.is_false((gc.lookup(1)))
			assert.are.equal(before, #calls)
			assert.is_false(vim.b[1].insgitheader_chezmoi.is_chezmoi)
		end)

		it("hält die Ergebnisse verschiedener Buffer auseinander", function()
			vim._test.bufnames = {
				[1] = "/home/user/.bashrc",
				[2] = "/home/user/project/file.lua",
			}
			io.popen = popen_mock({
				{ "^chezmoi source%-path 2>", SRC },
				{ "^chezmoi source%-path '/home/user/%.bashrc'", SRC .. "/dot_bashrc.tmpl" },
				{ "^chezmoi source%-path ", nil },
				{ "show%-toplevel", SRC },
			})
			assert.is_true((gc.lookup(1)))
			assert.is_false((gc.lookup(2)))
			assert.is_true((gc.lookup(1)))
			assert.is_false((gc.lookup(2)))
		end)

		it("fragt bei unbenanntem Buffer gar nicht erst nach", function()
			vim._test.bufname = ""
			assert.is_false((gc.lookup(1)))
			assert.are.equal(0, count("^chezmoi"))
		end)

		it("löst 0 auf den aktuellen Buffer auf", function()
			gc.lookup(0)
			assert.is_not_nil(vim.b[1].insgitheader_chezmoi)
		end)
	end)

	describe("Selbstinvalidierung über den Pfad", function()
		it("ermittelt neu wenn der Buffer-Name gewechselt hat", function()
			gc.lookup(1)
			local before = #calls

			vim._test.bufname = "/home/user/anders.lua"
			gc.lookup(1)
			assert.is_true(#calls > before)
			assert.are.equal("/home/user/anders.lua", vim.b[1].insgitheader_chezmoi.path)
		end)
	end)

	describe("invalidate()", function()
		it("verwirft den Eintrag eines Buffers", function()
			gc.lookup(1)
			assert.is_not_nil(vim.b[1].insgitheader_chezmoi)

			gc.invalidate(1)
			assert.is_nil(vim.b[1].insgitheader_chezmoi)
		end)

		it("führt zu einer erneuten Abfrage", function()
			gc.lookup(1)
			local before = #calls

			gc.invalidate(1)
			gc.lookup(1)
			assert.is_true(#calls > before)
		end)

		it("lässt andere Buffer unangetastet", function()
			vim._test.bufnames = { [1] = "/home/user/.bashrc", [2] = "/home/user/.bashrc" }
			gc.lookup(1)
			gc.lookup(2)

			gc.invalidate(1)
			assert.is_nil(vim.b[1].insgitheader_chezmoi)
			assert.is_not_nil(vim.b[2].insgitheader_chezmoi)
		end)

		it("stolpert nicht über einen ungültigen Buffer", function()
			gc.lookup(1)
			vim._test.invalid_bufs[1] = true
			assert.has_no.errors(function()
				gc.invalidate(1)
			end)
		end)
	end)

	describe("Source-Dir", function()
		it("ermittelt das Source-Dir nur einmal pro Sitzung", function()
			vim._test.bufnames = { [1] = "/home/user/.bashrc", [2] = "/home/user/.bashrc" }
			gc.lookup(1)
			gc.lookup(2)
			assert.are.equal(1, count("^chezmoi source%-path 2>"))
		end)

		it("behält das Source-Dir über invalidate() hinweg", function()
			gc.lookup(1)
			gc.invalidate(1)
			gc.lookup(1)
			assert.are.equal(1, count("^chezmoi source%-path 2>"))
		end)

		it("schreibt einen Fehlversuch nicht fest", function()
			io.popen = popen_mock({})
			assert.is_false((gc.lookup(1)))
			gc.invalidate(1)
			assert.is_false((gc.lookup(1)))
			assert.are.equal(2, count("^chezmoi source%-path 2>"))
		end)

		it("findet chezmoi das zweite Mal wenn es zwischenzeitlich auftaucht", function()
			io.popen = popen_mock({})
			assert.is_false((gc.lookup(1)))

			io.popen = chezmoi_available()
			gc.invalidate(1)
			assert.is_true((gc.lookup(1)))
		end)

		it("wird von reset() verworfen", function()
			gc.lookup(1)
			gc.reset()
			gc.invalidate(1)
			gc.lookup(1)
			assert.are.equal(2, count("^chezmoi source%-path 2>"))
		end)
	end)

	describe("Auflösung", function()
		it("liefert für eine Quelldatei den Zielpfad", function()
			vim._test.bufname = SRC .. "/dot_bashrc.tmpl"
			local is_chezmoi, repo, target = gc.lookup(1)
			assert.is_true(is_chezmoi)
			assert.are.equal(SRC, repo)
			assert.are.equal("/home/user/.bashrc", target)
		end)

		it("liefert für eine Datei im Source-Dir ohne Round-Trip keinen Zielpfad", function()
			vim._test.bufname = SRC .. "/README.md"
			io.popen = popen_mock({
				{ "^chezmoi source%-path 2>", SRC },
				{ "^chezmoi target%-path ", "/home/user/README.md" },
				{ "^chezmoi source%-path ", nil },
				{ "show%-toplevel", SRC },
			})
			local is_chezmoi, repo, target = gc.lookup(1)
			assert.is_true(is_chezmoi)
			assert.are.equal(SRC, repo)
			assert.is_nil(target)
		end)

		it("liefert für eine Target-Datei keinen Zielpfad", function()
			local is_chezmoi, _, target = gc.lookup(1)
			assert.is_true(is_chezmoi)
			assert.is_nil(target)
		end)
	end)
end)
