{ pkgs ? import ./pinned-nixpkgs.nix }:

import ./default.nix {} // {
  buildInputs = [
    pkgs.git  # Additional dev tools
    pkgs.entr
  ];
}
