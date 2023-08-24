{
  inputs = {
    nixpkgs = { };
  };
  outputs = { self, nixpkgs, ... }@inputs: let
    nixlib = nixpkgs.lib;
  in {
    modules = {
      inherit (import ./module.nix inputs) filter importFilters;
      default = self.modules.importFilters;
    };
    homeModules = {
      inherit (import ./home.nix inputs) emailAccount default importFilters;
    };
    lib = import ./lib.nix inputs;
  };
}
