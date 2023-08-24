{ self, ... }: let
  importFiltersModule = { pkgs, config, emailAccount, lib, ... }: let
    inherit (lib)
      mkOption mkDefault mkOptionDefault
      mapAttrs;
  in {
    options = with lib.types; {
      xmlFile = mkOption {
        type = either package path;
      };
    };
    config = {
      author = mapAttrs (_: mkDefault) {
        name = emailAccount.realName;
        email = emailAccount.address;
      };
      xmlFile = mkOptionDefault (pkgs.writeText "mailFilters.xml" config.xmlContent);
      _module.args = {
        gmailQuery = mkOptionDefault (self.lib.query.withFilters config.filters);
      };
    };
  };
  accountModule = { pkgs, config, name, lib, ... }: let
    inherit (lib) mkOption;
  in {
    options = with lib.types; {
      gmail = mkOption {
        type = submoduleWith {
          shorthandOnlyDefinesConfig = true;
          modules = [
            self.modules.importFilters
            self.homeModules.importFilters
          ];
          specialArgs = {
            emailAccount = config;
            inherit pkgs;
          };
        };
        default = { };
      };
    };
  };
  homeModule = { pkgs, lib, ... }: let
    inherit (lib) mkOption;
  in {
    options = with lib.types; {
      accounts.email.accounts = mkOption {
        type = attrsOf (submoduleWith {
          shorthandOnlyDefinesConfig = true;
          modules = [ self.homeModules.emailAccount ];
          specialArgs = {
            inherit pkgs;
          };
        });
      };
    };
  };
in {
  emailAccount = accountModule;
  importFilters = importFiltersModule;
  default = homeModule;
}
