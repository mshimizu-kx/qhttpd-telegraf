// test-handlers-slash-telegraf-slash-influx.q

/
* Test parse function called inside process-plant and extract function called inside RDB.
\

// Define initial schema
schemas:.j.k raze read0 `$":schemas-slash-telegraf-slash-influx.json";
//({[namespace;name;dict] @[`.; name; :;] 1!flip `tag`qtype!(key; {raze value x}) @\: dict}[`.telegraf_influx] .) each  flip (key; value) @\: schemas;
({[namespace;name;dict] @[`.; `$namespace, "_", string name; :;] first each dict}["telegraf_influx"] .) each  flip (key; value) @\: schemas;
//@[`.; `.telegraf.influx.SCHEMAS; :; `diagnostics`readings`system`diskio`process!{first each x} each value schemas];


parse_influx:{[info_unused_;endpoint;payload]

  / FIXME: Possible bug in qhttpd, I think we get the trailing \n at the end of the HTTP body
  payload:-1_payload;
  endpoint:1 _ ssr[string endpoint; "/"; "_"], "_";

  // Processor for Influx Line Protocol formatted events
  //   e.g. readings,name=truck_40,fleet=North,driver=Rodney,... load_capacity=5000,fuel_capacity=300,... 1451606400000000000
  to_dict:{[endpoint_; payload]

    // Split on spaces, handling quoted spaces gracefully (note: cannot use S=* here)
    quotes:2 cut where payload="\"";
    spaces:where payload=" ";
    spacesnotinquotes:spaces where not any each spaces within/:\: quotes;
    splitted:-1 _/: (0,1+spacesnotinquotes) _ payload," ";

    // Extract timestamp and massage into parseable epoch format + rest of the key=values
    timestamp:last splitted;
    properties:raze "time=",(10#timestamp),".",(-9#timestamp),",table=",splitted[0],",",splitted[1];

    // Parse key-value
    properties:(enlist[`]!enlist (::)), (!/)"S=*," 0: properties;
    schema:`$endpoint_, properties `table;

    // Choose appropriate schema based on event type (create a reference)
    propkeys:1 _ key properties;
    
    // New schema is an empty dictionary
    if[`NOT_EXIST ~ @[get; schema; {[err] `NOT_EXIST}]; @[`.; schema; :; enlist[`time]!enlist "P"]];

    // Influx Line Protocol represents integers as e.g. 5i - chop the trailing "i" off any values which are integers, and map to "J" by default
    if[0 < count integerkeys:propkeys inter where get[schema]="J"; properties:@[properties; integerkeys; {"J"$-1 _ x}]];

    // Parse the other keys
    parser:{[schema_; properties_; newkey] 
      $[("i" = last data) and ("J"$-1 _ data:properties_[newkey])<>0N;
        // Integer value - trim "i" and set target type long
        [
          @[schema_; newkey; :; "J"];
          properties_[newkey]:"J"$-1 _ data
        ];
        // Non integer value - set target type timestamp, float or symbol
        [
          if[null targettype:@[schema_; newkey]; 
            @[schema_; newkey; :; targettype:$[newkey ~ `time; "P"; 0n <> "F"$data; "F"; "S"]]
          ];
          properties_[newkey]:targettype$data
        ]
      ];
      properties_
    }[schema];

    1 _ (parser/)[properties; propkeys except integerkeys]
  }[endpoint];

  raze to_dict each "\n" vs payload
 };

influx:read0 `:influx.txt;

payloads:parse_influx[();`$"/telegraf/influx";] each influx;

extract_payloads:{[payload]
  if[payload ~ (); :()];
  table:`$"events_",(string payload `table);
  $[table in tables[];
    table set get[table] uj flip enlist each `table _ payload;
    @[`.; table; :; enlist `table _ payload]
  ]
 };

extract_payloads each payloads;
