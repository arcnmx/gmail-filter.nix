{ self, ... }: let
  inherit (self.lib) toPropertyValue defaultUpdatedTimestamp applyActions query;
  importModule = { config, lib, ... }: let
    inherit (lib)
      mkOption mkOrder mkIf mkBefore mkMerge
      head concatStringsSep mapAttrsToList;
    ids = concatStringsSep "," (mapAttrsToList (_: filter: filter.id) config.filters);
    updated' = mapAttrsToList (_: filter: filter.updated) config.filters;
    updated = if updated' == [ ] then defaultUpdatedTimestamp else head updated';
    filterXmls = mapAttrsToList (_: filter: mkIf filter.enable ''
      <entry>
      ${filter.xmlContent}
      </entry>
    '') config.filters;
  in {
    options = with lib.types; {
      author = {
        name = mkOption {
          type = nullOr str;
          default = null;
        };
        email = mkOption {
          type = nullOr str;
          default = null;
        };
      };
      filters = mkOption {
        type = attrsOf (submodule filterModule);
        default = { };
      };
      xmlContent = mkOption {
        type = lines;
      };
    };
    config = {
      xmlContent = mkMerge ([
        (mkOrder 250 ''
          <?xml version='1.0' encoding='UTF-8'?>
          <feed xmlns='http://www.w3.org/2005/Atom' xmlns:apps='http://schemas.google.com/apps/2006'>
        '')
        (mkBefore ''
            <title>Mail Filters</title>
            <id>tag:mail.google.com,2008:filters:${ids}</id>
            <updated>${updated}</updated>
        '')
        (mkIf (config.author.name != null && config.author.email != null) (mkBefore ''
            <author>
              <name>${config.author.name}</name>
              <email>${config.author.email}</email>
            </author>
        ''))
        (mkOrder 2000 ''
          </feed>
        '')
      ] ++ filterXmls);
    };
  };
  filterModule = { config, name, lib, ... }: let
    inherit (lib)
      mkOption mkEnableOption mkOptionDefault mkIf mkMerge mkBefore
      mapAttrs mapAttrs' mapAttrsToList nameValuePair singleton;
  in {
    options = with lib.types; {
      enable = mkEnableOption "filter" // { default = true; };
      title = mkOption {
        type = str;
        default = "Mail Filter";
      };
      updated = mkOption {
        type = str;
        default = defaultUpdatedTimestamp;
      };
      id = mkOption {
        type = str;
        default = name;
      };
      content = mkOption {
        type = str;
        default = "";
      };
      properties = mkOption {
        type = with types; attrsOf (oneOf [ str bool ]);
        default = { };
      };
      query = mkOption {
        type = str;
        readOnly = true;
      };
      apply = mapAttrs (_: { description, ... }: mkOption {
        description = "Instruct the filter to ${description}";
        type = bool;
        default = false;
      }) applyActions // {
        label = mkOption {
          description = "Instruct the filter to label matching mail";
          type = nullOr str;
          default = null;
        };
      };
      xmlContent = mkOption {
        type = lines;
      };
    };
    config = {
      properties = mapAttrs (_: mkOptionDefault) {
        sizeOperator = "s_sl";
        sizeUnit = "s_smb";
      } // mapAttrs' (name: { property, ... }: nameValuePair property (
        mkIf config.apply.${name} (mkOptionDefault true)
      )) applyActions // {
        label = mkIf (config.apply.label != null) (mkOptionDefault config.apply.label);
      };
      xmlContent = mkMerge (singleton (mkBefore ''
        <category term='filter'></category>
        <title>${config.title}</title>
        <id>tag:mail.google.com,2008:filter:${config.id}</id>
        <updated>${config.updated}</updated>
        <content>${config.content}</content>
      '') ++ mapAttrsToList (key: value: ''<apps:property name='${key}' value='${toPropertyValue value}'/>'') config.properties);
      query = query.forProperties config.properties;
    };
  };
in {
  importFilters = importModule;
  filter = filterModule;
}
