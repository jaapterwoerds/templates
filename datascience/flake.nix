{
  description = "JupyterLab Flake";

  inputs = {
      jupyterWith.url = "github:tweag/jupyterWith";
      mach-nix.url = "mach-nix/3.5.0";
      flake-utils.url = "github:numtide/flake-utils";
      nixpkgs.follows = "jupyterWith/nixpkgs";
  };

  outputs = { self, nixpkgs, mach-nix, jupyterWith, flake-utils }:
    flake-utils.lib.eachSystem [ "x86_64-linux" "x86_64-darwin" "aarch64-darwin" ] (system:
      let
        pkgs = import nixpkgs {
          system = system;
          overlays = nixpkgs.lib.attrValues jupyterWith.overlays;
        };
        machNix =   mach-nix.lib."${system}".mkPython  {
          providers.lightgbm = "nixpkgs,wheel,sdist";
          providers.xgboost = "nixpkgs,wheel,sdist";
          providers.numpy="nixpkgs,wheel";
          providers.pandas="nixpkgs,wheel";
          requirements = builtins.readFile ./requirements.txt;
        };
        iPython = pkgs.kernels.iPythonWith {
          name = "Python-env";
          ignoreCollisions = true;
          python3 = machNix.python;
          packages = machNix.python.pkgs.selectPkgs;
        };
        jupyterEnvironment = pkgs.jupyterlabWith {
          kernels = [ iPython ];
        };
      in rec {
        packages ={
          apps.jupterlab = {
            type = "app";
            program = "${jupyterEnvironment}/bin/jupyter-lab";
          };
          shell=jupyterEnvironment.env.overrideAttrs(old: {
            shellHook=''
              #!/bin/sh
              ENV_FILE='.env'
              if [[ -f "$ENV_FILE" ]]; then
                echo "Set environment variables from $ENV_FILE"
                source  "$ENV_FILE"
                export $(cut -d= -f1  "$ENV_FILE")
              else
                echo "File  $ENV_FILE not found"
                echo "Create and .env file from the .env.sample file"
              fi'';
            });
        };

        devShells.default = packages.shell;

      }
    );
}