{ pkgs ? import ./pinned-nixpkgs.nix }:

pkgs.stdenv.mkDerivation {
  name = "oatCAD";
  src = ./src;
  buildInputs = [ pkgs.zig ];
  buildPhase = ''
    zig build
  '';
  installPhase = ''
    mkdir -p $out/bin
    cp ./zig-out/bin/* $out/bin/
  '';
}
