{
  description = "Alex's PC Configuration";

  inputs = {
    nixpkgs.url = "github:nixos/nixpkgs/nixos-unstable";
    nix-darwin = {
      url = "github:LnL7/nix-darwin";
      inputs.nixpkgs.follows = "nixpkgs";
    };
    home-manager = {
      url = "github:nix-community/home-manager";
      inputs.nixpkgs.follows = "nixpkgs";
    };
    mac-app-util = {
      url = "github:hraban/mac-app-util";
      inputs.nixpkgs.follows = "nixpkgs";
    };
    algotex = {
      url = "github:alexstaeding/AlgoTeX/fix/flake";
      inputs.nixpkgs.follows = "nixpkgs";
    };
    plasma-manager = {
      url = "github:nix-community/plasma-manager";
      inputs.nixpkgs.follows = "nixpkgs";
      inputs.home-manager.follows = "home-manager";
    };
  };

  outputs = {
    self,
    nixpkgs,
    nix-darwin,
    home-manager,
    mac-app-util,
    algotex,
    plasma-manager,
    ...
  } @ inputs: let
    inherit (self) outputs;
    systems = [
      "aarch64-darwin"
      "aarch64-linux"
      "x86_64-linux"
    ];
    forAllSystems = nixpkgs.lib.genAttrs systems;
  in {
    packages = forAllSystems (system: import nixpkgs {
      inherit system;
      overlays = [ (final: previous: { algotex = algotex.packages.${system}.default; }) ];
      config = { allowUnfree = true; };
    });
    # Formatter for your nix files, available through 'nix fmt'
    # Other options beside 'alejandra' include 'nixpkgs-fmt'
    formatter = forAllSystems (system: nixpkgs.legacyPackages.${system}.alejandra);

    # Your custom packages and modifications, exported as overlays
    overlays = import ./overlays {inherit inputs;};
    # Reusable nixos modules you might want to export
    # These are usually stuff you would upstream into nixpkgs
    nixosModules = import ./modules/nixos;
    # Reusable home-manager modules you might want to export
    # These are usually stuff you would upstream into home-manager
    homeManagerModules = import ./modules/home-manager;

    # NixOS configuration entrypoint
    # Available through 'nixos-rebuild --flake .#your-hostname'
    nixosConfigurations = {
      desktopalex = nixpkgs.lib.nixosSystem {
        system = "x86_64-linux";
        specialArgs = { inherit inputs outputs; };
        modules = [
          ./nixos/configuration.nix
          home-manager.nixosModules.home-manager {
            home-manager.users.alex.imports = [
              ./home-manager/home.nix
              ./home-manager/extra-linux.nix
              ./home-manager/nano-module.nix
            ];
            home-manager.sharedModules = [ plasma-manager.homeManagerModules.plasma-manager ];
            home-manager.extraSpecialArgs = {
              inherit inputs outputs;
              pkgs = self.packages."x86_64-linux";
            };
          }
        ];
      };
    };

    darwinConfigurations = {
      macbookalex = nix-darwin.lib.darwinSystem {
        system = "aarch64-darwin";
        specialArgs = { inherit inputs outputs self; };
        modules = [
          ./nix-darwin/configuration.nix
          mac-app-util.darwinModules.default
          home-manager.darwinModules.home-manager {
            home-manager.users.alex.imports = [
              ./home-manager/home.nix
              ./home-manager/extra-macos.nix
              ./home-manager/nano-module.nix
            ];
            home-manager.sharedModules = [
              mac-app-util.homeManagerModules.default
            ];
            home-manager.extraSpecialArgs = {
              inherit inputs outputs;
              pkgs = self.packages."aarch64-darwin";
            };
          }
        ];
      };
    };
  };
}
