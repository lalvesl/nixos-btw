return {
	"mrcjkb/rustaceanvim",
	version = "^5", -- Recommended
	lazy = false, -- This plugin is already lazy
	config = function(_, opts)
		vim.g.rustaceanvim = vim.tbl_deep_extend("keep", vim.g.rustaceanvim or {}, opts or {})
		if vim.fn.executable("rust-analyzer") == 0 then
			LazyVim.error(
				"**rust-analyzer** not found in PATH, please install it.\nhttps://rust-analyzer.github.io/",
				{ title = "rustaceanvim" }
			)
		end
	end,
}

--
-- return {
-- 	"simrat39/rust-tools.nvim",
-- }
