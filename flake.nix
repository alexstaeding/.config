{
  description = "Alex's PC Configuration";

  inputs = {
    nixpkgs.url = "github:nixos/nixpkgs/nixos-unstable";
    home-manager = {
      url = "github:nix-community/home-manager";
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
    home-manager,
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
            home-manager.users.alex = import ./home-manager/home.nix;
            home-manager.extraSpecialArgs = {
	            inherit inputs outputs;
              pkgs = self.packages."x86_64-linux";
	          };
	        }
	        home-manager.nixosModules.home-manager {
            home-manager.users.alex = import ./home-manager/extra-linux.nix;
            home-manager.sharedModules = [ plasma-manager.homeManagerModules.plasma-manager ];
            home-manager.extraSpecialArgs = {
              inherit inputs outputs;
              pkgs = self.packages."x86_64-linux";
            };
          }
        ];
      };
    };

    # Standalone home-manager configuration entrypoint
    # Available through 'home-manager --flake .#your-username@your-hostname'
    homeConfigurations = {
      "alex" = home-manager.lib.homeManagerConfiguration {
        pkgs = self.packages."aarch64-darwin";
        extraSpecialArgs = { inherit inputs outputs; };
        modules = [
          ./home-manager/home.nix
          ./home-manager/extra-macos.nix
        ];
      };
    };
  };
}
