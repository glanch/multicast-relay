{
  description = "Multicast Relay (Python) with netifaces";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";
    flake-utils.url = "github:numtide/flake-utils";
  };

  outputs = { self, nixpkgs, flake-utils }:
    {
      nixosModules.default = { lib, config, pkgs, ... }:
        with lib;
        let
          cfg = config.services.multicast-relay;
        in
        {
          options.services.multicast-relay = {
            enable = mkEnableOption "Enable the Python multicast-relay";

            interfaces = mkOption {
              type = types.listOf types.str;
              description = "List of interfaces to relay between (min 2)";
            };

            relays = mkOption {
              type = types.listOf types.str;
              default = [ "239.255.255.250:1900" ];
              description = "List of multicast or broadcast IP:PORT pairs to relay.";
            };

            noTransmitInterfaces = mkOption {
              type = types.listOf types.str;
              default = [ ];
              description = "Interfaces to receive from but not transmit to.";
            };

            masqueradeInterfaces = mkOption {
              type = types.listOf types.str;
              default = [ ];
              description = "Interfaces from which to masquerade packets (rewrite source IP).";
            };

            extraArgs = mkOption {
              type = types.listOf types.str;
              default = [ ];
              description = "Additional command line arguments for multicast-relay.";
            };

            logFile = mkOption {
              type = types.str;
              default = "/var/log/multicast-relay.log";
              description = "Log file path for multicast-relay.";
            };

            package = mkOption {
              type = types.package;
              default = pkgs.multicast-relay;
              description = "Package to use for the multicast-relay service.";
            };
          };

          config = mkIf cfg.enable {
            systemd.services.multicast-relay = {
              description = "Python-based Multicast Relay";
              after = [ "network.target" ];
              wantedBy = [ "multi-user.target" ];

              serviceConfig = {
                Type = "simple";
                ExecStart = concatStringsSep " " ([
                  "${cfg.package}/bin/multicast-relay"
                  "--foreground"
                  "--verbose"
                  "--logfile ${cfg.logFile}"
                ]
                ++ (map (iface: "--interfaces ${iface}") cfg.interfaces)
                ++ (map (relay: "--relay ${relay}") cfg.relays)
                ++ (map (noTx: "--noTransmitInterfaces ${noTx}") cfg.noTransmitInterfaces)
                ++ (map (masq: "--masquerade ${masq}") cfg.masqueradeInterfaces)
                ++ cfg.extraArgs);

                Restart = "always";
                RestartSec = 5;
                StandardOutput = "journal";
                StandardError = "journal";
              };
            };
          };


        };
    } //
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
