-- Only inside the sbx sandbox (nixos/modules/sandbox/nvim.nix), where the
-- tools Mason installs and the treesitter parsers are already built by Nix.
if not vim.g.sbx_plugins then
	return {}
end

return {
	{ "mason-org/mason.nvim", enabled = false },
	{ "mason-org/mason-lspconfig.nvim", enabled = false },
	{
		"nvim-treesitter/nvim-treesitter",
		build = false,
		opts = { install_dir = vim.g.sbx_treesitter },
	},
}
