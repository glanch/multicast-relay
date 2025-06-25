{
  description = "Multicast Relay (Python) with netifaces";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";
    flake-utils.url = "github:numtide/flake-utils";
  };

  outputs = { self, nixpkgs, flake-utils }:
    let
      overlay = final: prev: {
        multicast-relay = final.python3Packages.buildPythonApplication {
          pname = "multicast-relay";
          version = "1.0";
          src = ./.;
          format = "other";
          propagatedBuildInputs = with final.python3Packages; [ netifaces ];
          installPhase = ''
            mkdir -p $out/bin
            cp multicast-relay.py $out/bin/multicast-relay.py
            chmod +x $out/bin/multicast-relay.py
            ln -s $out/bin/multicast-relay.py $out/bin/multicast-relay
          '';
          meta.description = "Multicast relay written in Python using netifaces";
        };
      };
    in
    flake-utils.lib.eachDefaultSystem (system:
      let
        pkgs = import nixpkgs { inherit system; overlays = [ overlay ]; };
      in {
        packages.default = pkgs.multicast-relay;

        devShells.default = pkgs.mkShell {
          buildInputs = [ pkgs.multicast-relay ];
        };

        nixosModules.default = { config, lib, ... }: {
          options.services.multicast-relay = with lib; {
            enable = mkEnableOption "Enable multicast-relay";

            interfaces = mkOption {
              type = types.listOf types.str;
              description = "Interfaces to relay between";
            };

            relays = mkOption {
              type = types.listOf types.str;
              default = [ "239.255.255.250:1900" ];
              description = "Multicast or broadcast targets";
            };

            masqueradeInterfaces = mkOption {
              type = types.listOf types.str;
              default = [];
              description = "Interfaces to masquerade from";
            };

            extraArgs = mkOption {
              type = types.listOf types.str;
              default = [];
              description = "Extra command-line arguments";
            };

            logFile = mkOption {
              type = types.str;
              default = "/var/log/multicast-relay.log";
              description = "Log file path";
            };

            package = mkOption {
              type = types.package;
              default = config.pkgs.multicast-relay;
              defaultText = "pkgs.multicast-relay";
              description = "Package to use";
            };
          };

          config = lib.mkIf config.services.multicast-relay.enable {
            systemd.services.multicast-relay = {
              description = "Multicast Relay Service";
              after = [ "network.target" ];
              wantedBy = [ "multi-user.target" ];
              serviceConfig = {
                ExecStart = lib.concatStringsSep " " (
                  [ "${config.services.multicast-relay.package}/bin/multicast-relay"
                    "--foreground"
                    "--verbose"
                    "--logfile ${config.services.multicast-relay.logFile}"
                  ]
                  ++ (map (i: "--interfaces ${i}") config.services.multicast-relay.interfaces)
                  ++ (map (r: "--relay ${r}") config.services.multicast-relay.relays)
                  ++ (map (m: "--masquerade ${m}") config.services.multicast-relay.masqueradeInterfaces)
                  ++ config.services.multicast-relay.extraArgs
                );
                Restart = "always";
                RestartSec = 5;
                StandardOutput = "journal";
                StandardError = "journal";
              };
            };
          };
        };
      });
}