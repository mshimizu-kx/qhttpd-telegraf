// test-handlers-slash-telegraf-slash-influx.q

/
* Test parse function called inside process-plant and extract function called inside RDB.
\

/
* Table to store payloads until they are processed.
* # Columns
* - batch_id  | GUID |        : Batch ID of processed payload
* - info      | dictionary |  : Information including path, IP address etc.
* - payload   | list of dictionary |  : Payload processed by process-plant
\
PAYLOADS:flip `batch_id`info`payload!"g**"$\:();

// Define initial schema
schemas:.j.k raze read0 `$":../src/schemas-slash-telegraf-slash-influx.json";
//({[namespace;name;dict] @[`.; name; :;] 1!flip `tag`qtype!(key; {raze value x}) @\: dict}[`.telegraf_influx] .) each  flip (key; value) @\: schemas;
({[namespace;name;dict] @[`.; `$namespace, "_", string name; :;] first each dict}["telegraf_influx"] .) each  flip (key; value) @\: schemas;
//@[`.; `.telegraf.influx.SCHEMAS; :; `diagnostics`readings`system`diskio`process!{first each x} each value schemas];


parse_influx:{[info_unused_;endpoint;payload]

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
  
 };

// Read test data separated by empty line. Add "\n" to each chunk so that it is consistent with
//  current data format
influx:("\n\n" vs "\n" sv read0 `:influx.txt),\: "\n";

// Parse each chunk of payloads
payloads:parse_influx[();`$"/telegraf/influx";] each influx;

// Insert results
`PAYLOADS insert (count[payloads]?0Ng; count[payloads]#(::); payloads);

extract_payloads:{[payload]
  table:`$"events_",(string payload `table);
  $[table in tables[];
    table set get[table] uj flip enlist each `table _ payload;
    @[`.; table; :; enlist `table _ payload]
  ]
 };

extract_payloads each raze PAYLOADS[`payload];
