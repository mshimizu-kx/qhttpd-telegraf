{[info_unused_;endpoint;payload]

  // Remove trailing \n at the end of the HTTP body
  payload:-1 _ payload;
  // /telegraf/influx => telegraf_influx_
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
    timestamp:last line;
    // Parse key-value
    // Note: "\"" is stripped from quoted value. q cannot tell if it was quoted one any more.
    .[!] "S=*," 0: "time=", (-9 _ timestamp), ".", (-9#timestamp), ",table=", line[0], ",", line[1]
  } each lines;

  // Group by table
  table_map:lines group lines[::; `table];
  // Included tables in this chunk of payloads
  tables_in_data:`$/:endpoint,/: key table_map;
  // Create a table if a new one is included.
  @[`.; ; :; `time`table!"PS"] each tables_in_data except .qhttpd_pp.SCHEMAS;

  // Return list of dictionaries by razing list of tables
  {[table_name;dicts]
    table_data:(uj/) enlist each dicts;
    // Existing keys included in this data
    not_new:key[schema:get table_name] inter cols table_data;
    // New keys included in data
    new:cols[table_data] except not_new;
    // Parse existing keys
    
    //* Map from type indicator to converting function used internally in `handler`.
    //*  Currently five types are registered:
    //* - "P": parse [second].[nanosecond]
    //* - "J": parse [digits]i
    //* - "S": parse as symbol
    //* - "F": parse as float
    //* - "*": parse as string (this handler cannot leave "\")
    typemap:("PJFS*"!($["P"]; {"J"$-1 _/: x}; $["F"]; $["S"]; ::)) schema not_new;
    table_data:![table_data; (); 0b; not_new!flip (typemap; not_new)];

    // If there is no new key, return
    if[0 = count new; :(exec first table from table_data; delete table from table_data)];

    // Decide type of new keys
    type_and_map:{[coldata]
      coldata:first coldata where not "" ~/: coldata;
      $[
        // case: long
        (not null["J"$-1 _ coldata]) and "i" = last coldata;
        ("J"; {"J"$-1 _/: x});
        // case: float
        not null "F"$coldata;
        ("F"; $["F"]);
        // default (symbol)
        ("S"; $["S"])
      ]
    } each table_data[new];
    // Update schema
    table_name upsert new!type_and_map[::; 0];

    // Parse new keys
    table_data:![table_data; (); 0b; new!flip (type_and_map[::; 1]; new)];
    // Return tuple of (table name; table)
    (exec first table from table_data; delete table from table_data)

  } ./: flip (tables_in_data; value table_map)
 }