{ pkgs ? import ./pinned-nixpkgs.nix }:

let
  base = import ./default.nix { inherit pkgs; };
in
pkgs.mkShell {
  buildInputs = base.buildInputs ++ [
    pkgs.git
    pkgs.graphviz
    pkgs.entr
    pkgs.feh
    pkgs.html-tidy
    # language agnostic formatter $ uncrustify -c /dev/null --replace babylon-render.js
    pkgs.uncrustify
    pkgs.zls
  ];

  # Optional: Shell hook for custom actions
  shellHook = ''
    echo "Welcome to the development shell!"
  '';
}
