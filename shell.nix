{ pkgs ? import ./pinned-nixpkgs.nix }:

let
  base = import ./default.nix { inherit pkgs; };
in
pkgs.mkShell {
  buildInputs = base.buildInputs ++ [
    pkgs.git        # Additional tools
    pkgs.entr
    pkgs.html-tidy
    pkgs.eslint
  ];

  # Optional: Shell hook for custom actions
  shellHook = ''
    echo "Welcome to the development shell!"
  '';
}
