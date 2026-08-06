describe("plugin/insgitheader/init.lua", function()
	local function load_plugin()
		vim._test.reset()
		package.loaded["insgitheader.helper.get-chezmoi"] = nil
		dofile("plugin/insgitheader/init.lua")
	end

	-- Fetches the registered autocommand listening for `event`.
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

	it("should register the :InsGitHeader command", function()
		assert.is_not_nil(vim._test.commands["InsGitHeader"])
	end)

	it("should create the InsGitHeader augroup", function()
		assert.are.equal(1, #vim._test.augroups)
		assert.are.equal("InsGitHeader", vim._test.augroups[1].name)
		assert.is_true(vim._test.augroups[1].opts.clear)
	end)

	it("should attach an autocommand to BufFilePost", function()
		assert.is_not_nil(autocmd_for("BufFilePost"))
	end)

	it("should attach an autocommand to BufWritePost", function()
		assert.is_not_nil(autocmd_for("BufWritePost"))
	end)

	it("should bind the autocommand to the augroup", function()
		assert.are.equal("InsGitHeader", autocmd_for("BufWritePost").opts.group)
	end)

	it("should drop the cache of exactly the affected buffer in the callback", function()
		vim.b[7].insgitheader_chezmoi = { path = "/x", is_chezmoi = true }
		vim.b[8].insgitheader_chezmoi = { path = "/y", is_chezmoi = true }

		autocmd_for("BufWritePost").opts.callback({ buf = 7 })

		assert.is_nil(vim.b[7].insgitheader_chezmoi)
		assert.is_not_nil(vim.b[8].insgitheader_chezmoi)
	end)

	it("should drop the cache via BufFilePost as well", function()
		vim.b[7].insgitheader_chezmoi = { path = "/x", is_chezmoi = true }
		autocmd_for("BufFilePost").opts.callback({ buf = 7 })
		assert.is_nil(vim.b[7].insgitheader_chezmoi)
	end)
end)
