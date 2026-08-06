describe("plugin/insgitheader/init.lua", function()
	local function load_plugin()
		vim._test.reset()
		package.loaded["insgitheader.helper.get-chezmoi"] = nil
		dofile("plugin/insgitheader/init.lua")
	end

	-- Holt das registrierte Autocmd, das auf `event` hört.
	local function autocmd_for(event)
		for _, entry in ipairs(vim._test.autocmds) do
			local events = type(entry.event) == "table" and entry.event or { entry.event }
			for _, e in ipairs(events) do
				if e == event then
					return entry
				end
			end
		end
	end

	before_each(load_plugin)

	it("registriert den Befehl :InsGitHeader", function()
		assert.is_not_nil(vim._test.commands["InsGitHeader"])
	end)

	it("legt die Augroup InsGitHeader an", function()
		assert.are.equal(1, #vim._test.augroups)
		assert.are.equal("InsGitHeader", vim._test.augroups[1].name)
		assert.is_true(vim._test.augroups[1].opts.clear)
	end)

	it("hängt ein Autocmd an BufFilePost", function()
		assert.is_not_nil(autocmd_for("BufFilePost"))
	end)

	it("hängt ein Autocmd an BufWritePost", function()
		assert.is_not_nil(autocmd_for("BufWritePost"))
	end)

	it("bindet das Autocmd an die Augroup", function()
		assert.are.equal("InsGitHeader", autocmd_for("BufWritePost").opts.group)
	end)

	it("verwirft im Callback den Cache genau des betroffenen Buffers", function()
		vim.b[7].insgitheader_chezmoi = { path = "/x", is_chezmoi = true }
		vim.b[8].insgitheader_chezmoi = { path = "/y", is_chezmoi = true }

		autocmd_for("BufWritePost").opts.callback({ buf = 7 })

		assert.is_nil(vim.b[7].insgitheader_chezmoi)
		assert.is_not_nil(vim.b[8].insgitheader_chezmoi)
	end)

	it("verwirft den Cache auch über BufFilePost", function()
		vim.b[7].insgitheader_chezmoi = { path = "/x", is_chezmoi = true }
		autocmd_for("BufFilePost").opts.callback({ buf = 7 })
		assert.is_nil(vim.b[7].insgitheader_chezmoi)
	end)
end)
