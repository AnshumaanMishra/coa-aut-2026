{ pkgs, lib, config, inputs, ... }:

{
  # Define the packages to install in your environment
  packages = [
    pkgs.xspim
    pkgs.asm-lsp
    pkgs.vimPlugins.nvim-treesitter-parsers.asm
  ];

  # enterShell replaces shellHook in devenv
  enterShell = ''
    echo "=========================================="
    echo " MIPS Development Environment Loaded"
    echo "=========================================="
    echo "Simulator      : spim"
    echo "Language Server: asm-lsp"
    echo "Editor         : neovim"
    echo ""
    echo "Run the simulator with:"
    echo "  spim"
    echo ""
  '';
}
