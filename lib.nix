{ nixpkgs, ... }@inputs: {
  defaultUpdatedTimestamp = "1970-01-01T00:00:00Z";
  applyActions = {
    star = {
      description = "star matching mail";
      property = "shouldStar";
    };
    archive = {
      description = "archive matching mail";
      property = "shouldArchive";
    };
    trash = {
      description = "trash matching mail";
      property = "shouldTrash";
    };
    read = {
      description = "mark matching mail as read";
      property = "shouldMarkAsRead";
    };
    important = {
      description = "mark matching mail as important";
      property = "shouldAlwaysMarkAsImportant";
    };
    neverImportant = {
      description = "never mark matching mail as important";
      property = "shouldNeverMarkAsImportant";
    };
    neverSpam = {
      description = "never mark matching mail as spam";
      property = "shouldNeverSpam";
    };
  };
  toPropertyValue = value:
    if value == true then "true"
    else if value == false then "false"
    else toString value;
  query = import ./query.nix inputs;
}
