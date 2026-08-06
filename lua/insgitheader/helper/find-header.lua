local M = {}

-- Lines that must stay at the start of the file; the header is placed below
-- them. The scan is hard-limited to two lines: per PEP 263 the coding
-- declaration is only valid in line 1 or 2 anyway, and the limit keeps a
-- coincidentally matching comment further down from pushing the header
-- towards the end of the file.
local PROLOG_PATTERNS = {
	"^#!",
	"^<%?xml",
	"^<%?php",
	"^#.*coding[:=]",
	"^@charset",
}

local MAX_PROLOG_LINES = 2

function M.is_prolog(line)
	for _, pattern in ipairs(PROLOG_PATTERNS) do
		if line:match(pattern) then
			return true
		end
	end
	return false
end

-- Number of consecutive prologue lines at the start of the file.
function M.prolog_length(lines)
	local n = 0
	while n < MAX_PROLOG_LINES and lines[n + 1] and M.is_prolog(lines[n + 1]) do
		n = n + 1
	end
	return n
end

local function escape(s)
	return (s:gsub("(%W)", "%%%1"))
end

local function is_blank(line)
	return line:match("^%s*$") ~= nil
end

-- Looks for the three consecutive file:/git:/author: lines directly below the
-- prologue, skipping leading blank lines. It does not search further down, so
-- that no unrelated comment block is picked up.
-- Returns: first and last line number (1-based) or nil.
function M.find_block(lines, cleft)
	local prefix = "^%s*" .. escape(cleft) .. "%s*"
	local i = M.prolog_length(lines) + 1
	while lines[i] and is_blank(lines[i]) do
		i = i + 1
	end
	if not lines[i] or not lines[i]:match(prefix .. "file:") then
		return nil
	end
	if not lines[i + 1] or not lines[i + 1]:match(prefix .. "git:") then
		return nil
	end
	if not lines[i + 2] or not lines[i + 2]:match(prefix .. "author:") then
		return nil
	end
	return i, i + 2
end

-- Is there a prologue line below the block (blank lines ignored)? Then the
-- header was once inserted above it and the shebang has no effect.
function M.prolog_below(lines, last)
	local i = last + 1
	while lines[i] and is_blank(lines[i]) do
		i = i + 1
	end
	return lines[i] ~= nil and M.is_prolog(lines[i])
end

-- Splits an existing author line into its parts.
-- Returns: first year, current author, existing previous-author chain.
function M.parse_author(line)
	local body = line:match("author:%s*(.*)$")
	if not body then
		return nil
	end
	local chain = body:match("%(orig%.%s*(.-)%)")
	if chain then
		body = (body:gsub("%s*%(orig%..-%)", ""))
	end
	-- The year field is the last token that on its own is a year or a year
	-- range. Not the first group of four digits: email addresses such as
	-- 12900332+user@example.com do start with digits.
	local first_year, who
	for pos, token in body:gmatch("()(%S+)") do
		if token:match("^%d%d%d%d$") or token:match("^%d%d%d%d%-%d%d%d%d$") then
			first_year = token:sub(1, 4)
			who = (body:sub(1, pos - 1):gsub("%s+$", ""))
		end
	end
	if who == "" then
		who = nil
	end
	return first_year, who, chain
end

return M
