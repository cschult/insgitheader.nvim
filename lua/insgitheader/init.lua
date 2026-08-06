local M = {}

local ggc = require("insgitheader.helper.get-git-config-user")
local fh = require("insgitheader.helper.find-header")

local settings = {
	name = ggc.get_git_user("name"),
	email = ggc.get_git_user("email"),
	path = "full",
}

local PATH_MODES = { full = true, basename = true }

M.setup = function(opts)
	opts = opts or {}
	if opts.name ~= nil then
		settings.name = opts.name
	end
	if opts.email ~= nil then
		settings.email = opts.email
	end
	if opts.path ~= nil then
		if PATH_MODES[opts.path] then
			settings.path = opts.path
		else
			vim.notify(
				"insgitheader: unknown path option " .. vim.inspect(opts.path) .. ", expected 'full' or 'basename'",
				vim.log.levels.WARN
			)
		end
	end
end

local function is_blank(line)
	return line:match("^%s*$") ~= nil
end

-- Compares two author entries leniently, so that a difference in format (an
-- address without angle brackets from an older header, say) does not pass as
-- a change of author and start a pointless chain.
local function same_person(a, b)
	local function norm(s)
		return (s:gsub("[<>]", ""):gsub("%s+", " "))
	end
	return norm(a) == norm(b)
end

local function build_author(cleft, cright, old_line)
	local year = os.date("%Y")
	local who = settings.name .. " <" .. settings.email .. ">"
	local years = year
	local chain

	if old_line then
		local first_year, previous, previous_chain = fh.parse_author(old_line)
		if first_year and first_year ~= year then
			years = first_year .. "-" .. year
		end
		chain = previous_chain
		-- Whoever is displaced moves to the end of the chain; oldest first.
		if previous and not same_person(previous, who) then
			chain = chain and (chain .. ", " .. previous) or previous
		end
	end

	local line = cleft .. " author: " .. who .. " " .. years
	if chain then
		line = line .. " (orig. " .. chain .. ")"
	end
	return line .. cright
end

local function build_block(cleft, cright, old_author)
	local gfn = require("insgitheader.helper.get-file-name")
	local line1 = cleft .. " file: " .. gfn.get_file_name(settings.path) .. cright

	local grn = require("insgitheader.helper.get-repo-name")
	local repo, is_chezmoi = grn.get_repo_name()
	local line2
	if repo and repo ~= "" then
		line2 = cleft .. " git: " .. repo
		if is_chezmoi then
			line2 = line2 .. " (managed by chezmoi)"
		end
		line2 = line2 .. cright
	elseif is_chezmoi then
		line2 = cleft .. " git: (managed by chezmoi)" .. cright
	else
		line2 = cleft .. cright
	end

	return { line1, line2, build_author(cleft, cright, old_author) }
end

M.insert_headers = function()
	-- get comment signs
	local gcc = require("insgitheader.helper.get-comment-chars")
	local cleft, cright = gcc.get_comment_chars()
	-- get_comment_chars returns the characters with their padding from
	-- commentstring ("-- ", " */"). We add our own separators, so trim it here,
	-- otherwise the spaces end up doubled.
	cleft = cleft and (cleft:gsub("%s+$", "")) or ""
	if cleft == "" then
		cleft = "#"
	end
	cright = cright and (cright:gsub("^%s+", "")) or ""
	if cright ~= "" then
		cright = " " .. cright
	end

	local lines = vim.api.nvim_buf_get_lines(0, 0, -1, false)
	local first, last = fh.find_block(lines, cleft)

	if first then
		-- Header present: replace just the three lines, leave the rest alone.
		local block = build_block(cleft, cright, lines[last])
		vim.api.nvim_buf_set_lines(0, first - 1, last, false, block)
		if fh.prolog_below(lines, last) then
			vim.notify(
				"insgitheader: header sits above the shebang, which has no effect there",
				vim.log.levels.WARN
			)
		end
		vim.api.nvim_win_set_cursor(0, { first, 0 })
		return
	end

	local block = build_block(cleft, cright, nil)
	local pos = fh.prolog_length(lines) + 1
	local header_at = pos

	if pos > 1 then
		-- Blank line between prologue and header; an existing one is reused
		-- instead of inserting a second one.
		if lines[pos] and is_blank(lines[pos]) then
			pos = pos + 1
			header_at = pos
		else
			table.insert(block, 1, "")
			header_at = pos + 1
		end
	end

	-- The same at the bottom end of the block.
	if not (lines[pos] and is_blank(lines[pos])) then
		table.insert(block, "")
	end

	vim.api.nvim_buf_set_lines(0, pos - 1, pos - 1, false, block)
	vim.api.nvim_win_set_cursor(0, { header_at, 0 })
end

return M
