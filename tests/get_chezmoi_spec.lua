describe("get-chezmoi", function()
	local gc
	local original_popen
	local calls

	local SRC = "/home/user/.local/share/chezmoi"

	-- Records every call and answers it by the first matching rule; without a
	-- match nil comes back.
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

	-- The standard case: chezmoi is there, /home/user/.bashrc is managed.
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

	describe("buffer cache", function()
		it("should answer the second call without starting a process", function()
			local is_chezmoi, repo = gc.lookup(1)
			assert.is_true(is_chezmoi)
			assert.are.equal(SRC, repo)
			local before = #calls

			assert.is_true((gc.lookup(1)))
			assert.are.equal(before, #calls)
		end)

		it("should store the result in b:insgitheader_chezmoi", function()
			gc.lookup(1)
			local cached = vim.b[1].insgitheader_chezmoi
			assert.are.equal("/home/user/.bashrc", cached.path)
			assert.is_true(cached.is_chezmoi)
			assert.are.equal(SRC, cached.repo)
		end)

		it("should cache a negative result too", function()
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

		it("should keep the results of different buffers apart", function()
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

		it("should not even ask for an unnamed buffer", function()
			vim._test.bufname = ""
			assert.is_false((gc.lookup(1)))
			assert.are.equal(0, count("^chezmoi"))
		end)

		it("should resolve 0 to the current buffer", function()
			gc.lookup(0)
			assert.is_not_nil(vim.b[1].insgitheader_chezmoi)
		end)
	end)

	describe("self-invalidation via the path", function()
		it("should look up again if the buffer name has changed", function()
			gc.lookup(1)
			local before = #calls

			vim._test.bufname = "/home/user/anders.lua"
			gc.lookup(1)
			assert.is_true(#calls > before)
			assert.are.equal("/home/user/anders.lua", vim.b[1].insgitheader_chezmoi.path)
		end)
	end)

	describe("invalidate()", function()
		it("should drop the entry of one buffer", function()
			gc.lookup(1)
			assert.is_not_nil(vim.b[1].insgitheader_chezmoi)

			gc.invalidate(1)
			assert.is_nil(vim.b[1].insgitheader_chezmoi)
		end)

		it("should lead to another lookup", function()
			gc.lookup(1)
			local before = #calls

			gc.invalidate(1)
			gc.lookup(1)
			assert.is_true(#calls > before)
		end)

		it("should leave other buffers untouched", function()
			vim._test.bufnames = { [1] = "/home/user/.bashrc", [2] = "/home/user/.bashrc" }
			gc.lookup(1)
			gc.lookup(2)

			gc.invalidate(1)
			assert.is_nil(vim.b[1].insgitheader_chezmoi)
			assert.is_not_nil(vim.b[2].insgitheader_chezmoi)
		end)

		it("should not trip over an invalid buffer", function()
			gc.lookup(1)
			vim._test.invalid_bufs[1] = true
			assert.has_no.errors(function()
				gc.invalidate(1)
			end)
		end)
	end)

	describe("source directory", function()
		it("should determine the source directory only once per session", function()
			vim._test.bufnames = { [1] = "/home/user/.bashrc", [2] = "/home/user/.bashrc" }
			gc.lookup(1)
			gc.lookup(2)
			assert.are.equal(1, count("^chezmoi source%-path 2>"))
		end)

		it("should keep the source directory across invalidate()", function()
			gc.lookup(1)
			gc.invalidate(1)
			gc.lookup(1)
			assert.are.equal(1, count("^chezmoi source%-path 2>"))
		end)

		it("should not pin down a failed probe", function()
			io.popen = popen_mock({})
			assert.is_false((gc.lookup(1)))
			gc.invalidate(1)
			assert.is_false((gc.lookup(1)))
			assert.are.equal(2, count("^chezmoi source%-path 2>"))
		end)

		it("should find chezmoi the second time if it appears in between", function()
			io.popen = popen_mock({})
			assert.is_false((gc.lookup(1)))

			io.popen = chezmoi_available()
			gc.invalidate(1)
			assert.is_true((gc.lookup(1)))
		end)

		it("should be dropped by reset()", function()
			gc.lookup(1)
			gc.reset()
			gc.invalidate(1)
			gc.lookup(1)
			assert.are.equal(2, count("^chezmoi source%-path 2>"))
		end)
	end)

	describe("resolution", function()
		it("should return the target path for a source file", function()
			vim._test.bufname = SRC .. "/dot_bashrc.tmpl"
			local is_chezmoi, repo, target = gc.lookup(1)
			assert.is_true(is_chezmoi)
			assert.are.equal(SRC, repo)
			assert.are.equal("/home/user/.bashrc", target)
		end)

		it("should return no target path for a file in the source directory without a round-trip", function()
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

		it("should return no target path for a target file", function()
			local is_chezmoi, _, target = gc.lookup(1)
			assert.is_true(is_chezmoi)
			assert.is_nil(target)
		end)
	end)
end)
