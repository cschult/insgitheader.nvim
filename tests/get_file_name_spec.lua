describe("get-file-name", function()
	local gfn

	before_each(function()
		package.loaded["insgitheader.helper.get-file-name"] = nil
		gfn = require("insgitheader.helper.get-file-name")
	end)

	it("gibt den vollständigen Pufferpfad zurück", function()
		vim._test.bufname = "/home/user/project/file.lua"
		assert.are.equal("/home/user/project/file.lua", gfn.get_file_name())
	end)

	it("gibt leeren String zurück für unbenannten Puffer", function()
		vim._test.bufname = ""
		assert.are.equal("", gfn.get_file_name())
	end)
end)
