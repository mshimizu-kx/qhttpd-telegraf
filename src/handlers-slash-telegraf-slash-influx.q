{[info_unused_;endpoint;payload]

  / FIXME: Possible bug in qhttpd, I think we get the trailing \n at the end of the HTTP body
  payload:-1 _ payload;
  endpoint:1 _ ssr[string endpoint; "/"; "_"], "_";

  // Processor for Influx Line Protocol formatted events
  //   e.g. readings,name=truck_40,fleet=North,driver=Rodney,... load_capacity=5000,fuel_capacity=300,... 1451606400000000000
  
  // Split on spaces, handling quoted spaces gracefully (note: cannot use S=* here)
  quotes:2 cut where payload="\"";
  spaces:where payload=" ";
  spacesnotinquotes:spaces where not any each spaces within/:\: quotes;
  newline:where payload="\n";
  splitted:-1 _/: (asc 0, 1+newline, spacesnotinquotes) _ payload, " ";

  // Each line is composed of [table,host] [various tags] [timestamp]
  lines:3 cut splitted;

  lines:{[line]
    // Extract timestamp with removing line separator "\n"
    timestamp:-1 _ last line;
    // Parse key-value
    .[!] "S=*," 0: "time=", (10#timestamp), ".", (-9#timestamp), ",table=", line[0], ",", line[1]
  } each lines;

  // Group by table
  table_map:lines group lines[::; `table];
  // Included tables in this chunk of payloads
  tables_in_data:`$/:endpoint,/: key table_map;
  // Create a table if a new one is included.
  @[`.; ; :; `time`table!"PS"] each tables_in_data except system "a";

  // Return list of dictionaries by razing list of tables
  raze {[table_name;dicts]
    table:(uj/) enlist each dicts;
    exist:key schema:get table_name;
    new:cols[table] except exist;
    // Parse existing keys
    typemap:?["J" = types; count[types]#{"J"$-1 _/: x}; @[$] each types:value schema];
    table:![table; (); 0b; exist!flip (typemap; exist)];

    // If there is no new key, return
    if[0 = count new; :table];

    // Decide type of new keys
    type_and_map:{
      (("J"; {"J"$-1 _/: x}); ("F"; $["F"]); ("S"; $["S"])) first where not null ({$["i" = last x; "J"$-1 _ x; (::)]}; $["F"]; $["S"]) @\: first x where not "" ~/: x
    } each table[new];
    // Update schema
    table_name upsert new!type_and_map[::; 0];

    // Parse new keys and return
    ![table; (); 0b; new!flip (type_and_map[::; 1]; new)]

  } ./: flip (tables_in_data; value table_map)
 }