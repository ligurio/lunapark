# Nix development shell for lunapark
#
# Usage:
#   nix-shell                      # Native (x86_64) development environment.
#   nix-shell --argstr arch i386   # 32-bit (i386) development environment.
#   nix-shell --pure               # Enter pure (isolated) environment.
#
{ pkgs ? import <nixpkgs> {}
, arch ? null
}:

let
  isI386 = arch == "i386";
  p = if isI386 then pkgs.pkgsi686Linux else pkgs;
  suffix = if isI386 then "-i386" else "";

  commonInputs = with p; [
    clang
    cmake
    emmylua-check
    git
    gnumake
    libunwind
    ninja
    protobuf_21
    readline
    xz
    zlib
  ];

  # Formal verification and lint tooling. Not needed for a 32-bit target
  # and not present in the i686 binary cache, so keep them native-only.
  nativeInputs = with pkgs; [
    cbmc
    cbmc-viewer
    emmylua-check
  ];
in
p.mkShell {
  name = "lunapark-dev${suffix}";

  buildInputs = commonInputs ++ (if isI386 then [] else nativeInputs);

  shellHook = ''
    echo "lunapark Development Environment${suffix}"
    echo "To list available presets in CMake, use:"
    echo "  cmake --workflow --list-presets"
    echo "some presets:"
    echo "  cmake --workflow --preset luajit-i386"
    echo "  cmake --workflow --preset lua-i386"
    echo "  cmake --workflow --preset luajit"
    echo "  cmake --workflow --preset lua"
  '';
}
