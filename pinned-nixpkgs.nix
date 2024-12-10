let
  nixpkgs = import (builtins.fetchTarball {
    url = "https://github.com/NixOS/nixpkgs/archive/68cf0d86c9dde16eac3b35729c3edeb74aeeb76a.tar.gz"; # Replace with your desired commit hash
    sha256 = "sha256:1n0j25r54l484qrfgimvk64cnnx1nymwlqhrqbrd7x1ap67df10f"; # Replace with the correct hash
  });
in
nixpkgs {}
