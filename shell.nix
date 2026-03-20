# Nix development shell for lunapark
#
# Usage:
#   nix-shell              # Enter development environment.
#   nix-shell --pure       # Enter pure (isolated) environment.
#
{ pkgs ? import <nixpkgs> {} }:

pkgs.mkShell {
  name = "lunapark-dev";

  buildInputs = with pkgs; [
    cbmc
    cbmc-viewer
    clang
    cmake
    git
    gnumake
    libunwind
    ninja
    protobuf_21
    readline
    xz
    zlib
  ];

  shellHook = ''
    echo "lunapark Development Environment"
    echo "  cmake --workflow --preset luajit"
    echo "  cmake --workflow --preset lua"
  '';
}
