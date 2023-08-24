{ self, nixpkgs }: let
  inherit (nixpkgs.lib)
    isFunction
    hasInfix replaceStrings concatMapStringsSep toLower
    mapAttrs attrValues
    optional length head toList filter groupBy;
  inherit (builtins)
    match;
  gq = self.lib.query;
  size' = let
    toNumber = toString;
  in query: {
    mb = amt: query "${toNumber amt}M";
    kb = amt: query "${toNumber amt}K";
    b = amt: query (toNumber amt);
  };
  wrapRight = let
    gq.wrap' = f: recurse: query:
      if isFunction query
      then arg: recurse (query arg)
      else f query;
  in f: gq.wrap' f (wrapRight f);
  wrapLeft = f: query:
    if isFunction query
    then arg: query (f arg)
    else f query;
  many' = sep: let
    query' = concatMapStringsSep sep gq.toPart;
    query'' = parts': let
      parts = toList parts';
      count = length parts;
    in assert count > 0; if count == 1 then head parts else query' parts;
  in wrapLeft query'';
in {
  paren = value: "(${value})"; # TODO: why does the gmail UI sometimes use "{}" instead?
  isEscaped = let
    matchEscaped = let
      enclosed = "[^ ]*|\\([^)]*\\)|\"[^\"]*\"";
    in match "-?(${enclosed}|[a-zA-Z]+:(${enclosed}))";
  in query: matchEscaped query != null;
  isPlain = let
    matchNonPlain = match "[^ :]+:.*";
  in query: matchNonPlain query == null;
  toPart = value:
    if !gq.isEscaped value then (gq.paren value)
    else value;
  forProperties = properties: let
    parts =
      optional (properties ? hasTheWord) properties.hasTheWord
      ++ optional (properties ? from) (gq.from properties.from)
      ++ optional (properties ? to) (gq.to properties.to)
      ++ optional (properties ? subject) (gq.subjectExact properties.subject)
      ++ optional (properties.excludeChats or false == true) gq.excludeChats
      ;
  in gq.and parts;
  or = many' " OR ";
  and = many' " ";
  any = gq.or;
  all = gq.and;
  compare = ty: query: "${ty}:${gq.toPart query}";
  from = gq.compare "from";
  to = {
    __functor = _: gq.compare "to";
    me = gq.to "me";
  };
  deliveredTo = gq.compare "deliveredto";
  subject = gq.compare "subject";
  subjectExact = subject: gq.compare "subject" (gq.exact subject);
  isIn = {
    __functor = _: gq.compare "in";
    spam = gq.isIn "spam";
    chats = gq.isIn "chats";
    drafts = gq.isIn "drafts";
    inbox = gq.isIn "inbox";
    anywhere = gq.isIn "anywhere"; # roughly equivalent to: gq.any [ mail gq.isIn.spam gq.isIn.trash ]
  };
  is = {
    __functor = _: gq.compare "is";
    starred = gq.is "starred";
    sent = gq.is "sent";
    read = gq.is "read";
    unread = gq.is "unread";
  };
  category = {
    __functor = _: gq.compare "category";
    social = gq.category "social";
    updates = gq.category "updates";
    forums = gq.category "forums";
    promotions = gq.category "promotions";
  };
  has = {
    __functor = _: gq.compare "has";
    attachment = gq.has "attachment";
  };
  larger = {
    __functor = _: gq.compare "larger";
  } // size' gq.larger;
  smaller = {
    __functor = _: gq.compare "smaller";
  } // size' gq.smaller;
  excludeChats = gq.not gq.isIn.chats;
  not = wrapRight (query: "-${gq.toPart query}");
  exact = let
    hasSpaces = hasInfix " ";
  in query: if hasSpaces query
    then "\"${query}\""
    else query;
  label = let
    sanitizeLabel = label: toLower (replaceStrings [ "/" ] [ "-" ] label);
  in label: gq.compare "label" (sanitizeLabel label);
  interestForFilters = let
    queryForFilter = { query ? gq.forProperties properties, properties ? null, ... }: query;
    interestQueryLabel = interest: label: gq.any (map queryForFilter interest.labelled.${label});
    interestQueryIs = interest: mapAttrs (_: filters:
      gq.any (map queryForFilter filters)
    ) interest;
  in filters_: let
    filters = attrValues filters_;
    interest = {
      labelled = groupBy (filter: filter.apply.label) (filter (filter: filter.apply.label != null) filters);
      starred = filter (filter: filter.apply.star == true) filters;
      archived = filter (filter: filter.apply.archive == true) filters;
      unimportant = filter (filter: filter.apply.neverImportant == true) filters;
      trashed = filter (filter: filter.apply.trash == true) filters;
      read = filter (filter: filter.apply.read == true) filters;
    };
  in {
    inherit interest;
    query = {
      label = interestQueryLabel interest;
      is = interestQueryIs interest;
    };
  };
  withInterest = interest: gq // {
    inherit (interest.query) label is;
  };
  withFilters = filters: gq.withInterest (gq.interestForFilters filters);
}
