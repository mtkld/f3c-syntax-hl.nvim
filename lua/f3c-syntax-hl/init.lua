local M = {}

-- Default configuration options
local default_opts = {}

local opts = {}

-- Merge user config with defaults
function M.setup(user_opts)
	-----------------------------------------------------------------------
	--  Regex‑based highlighter for *.f3c
	-----------------------------------------------------------------------
	-- ─┤ file: after/ftplugin/f3c.lua ├─────────────────────────────────────────────
	vim.filetype.add({ extension = { f3c = "f3c" } })

	local ns = vim.api.nvim_create_namespace("f3c_highlight")

	-- ── test colours (all deliberately garish) ───────────────────────────────────

	vim.api.nvim_set_hl(0, "F3CKey", { fg = "#ffb000" }) -- bright goldenrod (strong, sunlit key tone)
	vim.api.nvim_set_hl(0, "F3CBlock", { fg = "#586e75" }) -- slate grey-blue

	vim.api.nvim_set_hl(0, "F3CSpec", { fg = "#b58900" }) -- mustard gold
	vim.api.nvim_set_hl(0, "F3CString", { fg = "#859900" }) -- olive green
	vim.api.nvim_set_hl(0, "F3CNumber", { fg = "#d33682" }) -- faded rose
	vim.api.nvim_set_hl(0, "F3CBoolTrue", { fg = "#2aa198" }) -- teal
	vim.api.nvim_set_hl(0, "F3CBoolFalse", { fg = "#dc322f" }) -- clay red
	vim.api.nvim_set_hl(0, "F3CNull", { fg = "#839496" }) -- steel grey

	vim.api.nvim_set_hl(0, "F3CPunct", { fg = "#ffffff" }) -- pale dust
	vim.api.nvim_set_hl(0, "F3COther", { fg = "#657b83" }) -- stone blue-grey

	--replaced by other vim.api.nvim_set_hl(0, "F3CValue", { fg = "#ffffff" }) -- white
	-- ── helpers ──────────────────────────────────────────────────────────────────
	local function trim(s)
		return (s:gsub("^%s+", ""):gsub("%s+$", ""))
	end
	local function chop(val) -- strip comment / , / ; then trim
		return trim(val:gsub("[,;#].*$", ""))
	end

	-- helper that both trims *and* removes trailing “#…”, “;…”, or “, …”
	local function clean(val)
		-- 1. strip inline comment / delimiter
		val = val:gsub("[,;#].*$", "")
		-- 2. trim leading / trailing whitespace
		return (val:gsub("^%s+", ""):gsub("%s+$", ""))
	end

	local function classify_value(raw)
		local bare = clean(raw)
		local lower = bare:lower()

		if bare:match('^".-"$') then
			return "F3CString" --   "hello"
		elseif bare:match("^%-?%d+%.?%d*$") then
			return "F3CNumber" --   42, -7, 3.14
		elseif lower == "true" then
			return "F3CBoolTrue"
		elseif lower == "false" then
			return "F3CBoolFalse"
		elseif lower == "null" or lower == "nil" then
			return "F3CNull"
		else
			return "F3COther" --   any other atom
		end
	end

	local function highlight_punct(bufnr, row, line)
		-- dot or dots on their own line
		if line:match("^%s*%.%.%s*$") then
			local col = line:find("%.%.")
			vim.api.nvim_buf_add_highlight(bufnr, ns, "F3CPunct", row, col - 1, col + 1)
		elseif line:match("^%s*%.%s*$") then
			local col = line:find("%.")
			vim.api.nvim_buf_add_highlight(bufnr, ns, "F3CPunct", row, col - 1, col)
		end

		-- two dots at end of line
		local dd_s, dd_e = line:find("%.%.$")
		if dd_s then
			vim.api.nvim_buf_add_highlight(bufnr, ns, "F3CPunct", row, dd_s - 1, dd_e)
		end

		-- every colon “:”
		for col in line:gmatch("()[:]") do
			vim.api.nvim_buf_add_highlight(bufnr, ns, "F3CPunct", row, col - 1, col)
		end
	end

	-- ── main walker ──────────────────────────────────────────────────────────────
	local function highlight_f3c(bufnr)
		bufnr = bufnr or vim.api.nvim_get_current_buf()
		vim.api.nvim_buf_clear_namespace(bufnr, ns, 0, -1)
		for i, line in ipairs(vim.api.nvim_buf_get_lines(bufnr, 0, -1, false)) do
			local touched = false

			-- Step 1: highlight quoted strings and track their spans
			-- Step 1: highlight from first to last double quote on the line
			local first_quote = line:find('"')
			local last_quote = line:match('.*()"')
			if first_quote and last_quote and last_quote > first_quote then
				vim.api.nvim_buf_add_highlight(bufnr, ns, "F3CString", i - 1, first_quote - 1, last_quote)
			end

			-- Create a simple in_string(col) checker for rest of logic
			local function in_string(col)
				return first_quote and last_quote and col >= first_quote and col <= last_quote
			end

			-- Step 2: find first colon not in a string (key : value)
			local colon_pos = nil
			for pos in line:gmatch("():") do
				if not in_string(pos) then
					colon_pos = pos
					break
				end
			end

			if colon_pos then
				local key = line:sub(1, colon_pos - 1)
				if key:match("%S") then
					touched = true
					local trimmed_key = trim(key)
					local key_start = line:find(trimmed_key, 1, true)
					local key_end = key_start + #trimmed_key
					vim.api.nvim_buf_add_highlight(bufnr, ns, "F3CKey", i - 1, key_start - 1, key_end)

					local raw_val = trim(line:sub(colon_pos + 1))
					if #raw_val > 0 then
						local hl = classify_value(raw_val)
						local vcol = line:find(raw_val, colon_pos + 1, true) - 1
						if not in_string(vcol + 1) then
							vim.api.nvim_buf_add_highlight(bufnr, ns, hl, i - 1, vcol, vcol + #raw_val)
						end
					end
				end
			elseif line:match("^%s*%w+::%s*$") and not in_string(line:find("::")) then
				touched = true
				local s, e = line:find("^%s*%w+")
				vim.api.nvim_buf_add_highlight(bufnr, ns, "F3CBlock", i - 1, s - 1, e)
			elseif line:match("^%s*%w+:%w+:%s*$") and not in_string(line:find(":")) then
				touched = true
				local s, e = line:find("^%s*%w+")
				vim.api.nvim_buf_add_highlight(bufnr, ns, "F3CSpec", i - 1, s - 1, e)
			elseif line:match("^%s*:%w+:%s*$") and not in_string(line:find(":")) then
				touched = true
				vim.api.nvim_buf_add_highlight(bufnr, ns, "F3CSpec", i - 1, 0, -1)
			else
				touched = false
			end

			-- punctuation (colons and dots), skipping inside strings
			if line:find("[:%.]") then
				for col in line:gmatch("()[:%.]") do
					if not in_string(col) then
						vim.api.nvim_buf_add_highlight(bufnr, ns, "F3CPunct", i - 1, col - 1, col)
					end
				end
			end

			if not touched and trim(line) ~= "" then
				vim.api.nvim_buf_add_highlight(bufnr, ns, "F3COther", i - 1, 0, -1)
			end
		end
	end

	vim.api.nvim_create_autocmd({ "BufEnter", "TextChanged", "TextChangedI" }, {
		pattern = "*.f3c",
		callback = function(a)
			highlight_f3c(a.buf)
		end,
	})
	-- ─────────────────────────────────────────────────────────────────────────────
end

return M
