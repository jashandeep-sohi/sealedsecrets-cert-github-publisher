{
  description = "Publish SealedSecret certificate to a Github Repository";

  inputs = {
    nixpkgs.url = "github:cachix/devenv-nixpkgs/rolling";
    devenv.url = "github:cachix/devenv";
    nix2container.url = "github:nlewo/nix2container";
    nix2container.inputs.nixpkgs.follows = "nixpkgs";
    mk-shell-bin.url = "github:rrbutani/nix-mk-shell-bin";

    octopilot = {
      url = "github:dailymotion-oss/octopilot/v1.12.34";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    devenv-root = {
      url = "file+file:///dev/null";
      flake = false;
    };

  };

  nixConfig = {
    extra-trusted-public-keys = "devenv.cachix.org-1:w1cLUi8dv3hnoSPGAuibQv+f9TZLr6cv/Hm9XgU50cw=";
    extra-substituters = "https://devenv.cachix.org";
  };

  outputs = inputs@{ flake-parts, ... }:
    flake-parts.lib.mkFlake { inherit inputs; } {
      imports = [
        inputs.devenv.flakeModule
      ];
      systems = [ "x86_64-linux" "i686-linux" "x86_64-darwin" "aarch64-linux" "aarch64-darwin" ];

      perSystem = { config, self', inputs', pkgs, system, ... }:
      let
        runtimeDeps = [
          pkgs.kubeseal
          pkgs.coreutils
          inputs'.octopilot.packages.default
        ];
      in {
        # Per-system attributes can be defined here. The self' and inputs'
        # module parameters provide easy access to attributes of the same
        # system.

        packages.default = pkgs.writeShellApplication {
          name = "sealedsecrets-cert-github-publisher";

          runtimeInputs = runtimeDeps;

          text = builtins.readFile ./cert-github-publisher.sh;
        };

        packages.container =  let
          user = "nobody";
          group = "nobody";
          alpine = inputs'.nix2container.packages.nix2container.pullImage {
            imageName = "alpine";
            imageDigest = "sha256:25109184c71bdad752c8312a8623239686a9a2071e8825f20acb8f2198c3f659";
            arch = "amd64";
            sha256 = "sha256-nMVDjf8Mgfx+A6x+98VLwMUhJtizi/Ln5yH7x1o4nUk=";
          };
          package = config.packages.default;
        in with inputs'.nix2container.packages; nix2container.buildImage {
          name = "ghcr.io/jashandeep-sohi/sealedsecrets-cert-github-publisher";
          tag = "latest";
          fromImage = alpine;
          config = {
            User = user;
            runAsRoot = ''
              addgroup -S ${group} && adduser -S ${user} -G ${group}
            '';
            Entrypoint = [
                "${package}/bin/${package.name}"
            ];
          };
        };

        devenv.shells.default = {
          imports = [
            # This is just like the imports in devenv.nix.
            # See https://devenv.sh/guides/using-with-flake-parts/#import-a-devenv-module
            # ./devenv-foo.nix
          ];

          devenv.root = let
            devenvRootFileContent = builtins.readFile inputs.devenv-root.outPath;
          in pkgs.lib.mkIf (devenvRootFileContent != "") devenvRootFileContent;

          # https://devenv.sh/reference/options/
          packages = [
            config.packages.default
          ] ++ runtimeDeps;

          enterShell = ''
            export SHELL=${pkgs.bashInteractive}/bin/bash
          '';
        };

      };
      flake = {
        # The usual flake attributes can be defined here, including system-
        # agnostic ones like nixosModule and system-enumerating ones, although
        # those are more easily expressed in perSystem.

      };
    };
}
