{
  description = "Multicast Relay (Python) with netifaces";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";
    flake-utils.url = "github:numtide/flake-utils";
  };

  outputs = { self, nixpkgs, flake-utils }:
    flake-utils.lib.eachDefaultSystem (system:
      let
        pkgs = import nixpkgs {
          inherit system;
          overlays = [
            (final: prev: {
              multicast-relay = final.python3Packages.buildPythonApplication {
                pname = "multicast-relay";
                version = "1.0";

                src = ./.;

                format = "other"; # not a Python package with setup.py

                propagatedBuildInputs = with final.python3Packages; [ netifaces ];

                installPhase = ''
                  mkdir -p $out/bin
                  cp multicast-relay.py $out/bin/multicast-relay.py
                  chmod +x $out/bin/multicast-relay.py
                  ln -s $out/bin/multicast-relay.py $out/bin/multicast-relay
                '';

                meta = {
                  description = "Multicast relay written in Python using netifaces";
                  maintainers = with final.lib.maintainers; [ ];
                };
              };
            })
          ];
        };
      in
      {
        packages.default = pkgs.multicast-relay;

        devShells.default = pkgs.mkShell {
          buildInputs = [ pkgs.multicast-relay ];
        };
      }
    );
}
