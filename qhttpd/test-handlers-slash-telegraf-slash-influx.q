// test-handlers-slash-telegraf-slash-influx.q

/
* Test parse function called inside process-plant and extract function called inside RDB.
\


parse_influx:{[i;eps;payload]

  schema_diagnostics::`t`table`fleet`model`name`driver`device_version`load_capacity`fuel_capacity`nominal_fuel_consumption`fuel_state`current_load`status!"PSSSSSSJJIFJJ";
  schema_readings::`t`table`name`fleet`driver`model`device_version`load_capacity`fuel_capacity`nominal_fuel_consumption`latitude`longitude`elevation`velocity`heading`grade`fuel_consumption!"PSSSSSSSJJFFJJJJJ";
  schema_system::`t`table`host`uptime`uptime_format!"PSSJS";
  schema_diskio::`t`table`host!"PSS";
  schema_processes::`t`table`host`running`sleeping`dead`paging`blocked`zombies`stopped`total`unknown`total_threads`idle!"PSSJJJJJJJJJJJ";

  schemas::`diagnostics`readings`system`processes`diskio!(schema_diagnostics;schema_readings;schema_system;schema_processes;schema_diskio);

  / FIXME: Possible bug in qhttpd, I think we get the trailing \n at the end of the HTTP body
  payload:-1_payload;

  // Processor for Influx Line Protocol formatted events
  //   e.g. readings,name=truck_40,fleet=North,driver=Rodney,... load_capacity=5000,fuel_capacity=300,... 1451606400000000000
  // TODO: schema evolution
  to_dict:{[payload]

    // Split on spaces, handling quoted spaces gracefully (note: cannot use S=* here)
    quotes:2 cut where payload="\"";
    spaces:where payload=" ";
    spacesnotinquotes:spaces where not any each spaces within/:\: quotes;
    splitted:-1 _/: (0,1+spacesnotinquotes) _ payload," ";

    // splitted:("**J";" ") 0: payload; - doesn't work for spaces in quotes

    // Extract timestamp and massage into parseable epoch format + rest of the key=values
    timestamp:last splitted;
    properties::raze "t=",(10#timestamp),".",(-9#timestamp),",table=",splitted[0],",",splitted[1];

    // Parse key-value
    properties::(enlist[`]!enlist (::)), (!/)"S=*," 0: properties;
    table:`$properties `table;

    // Choose appropriate schema based on event type
    propkeys:1 _ key properties;
    schema::schemas[table]; 
    // New schema is an empty dictionary
    if[newschema:0=count schema;schema::enlist[`t]!enlist "P"];

    / Influx Line Protocol represents integers as e.g. 5i - chop the trailing "i" off any values which are integers, and map to "J" by default
    if[0 < count integerkeys:propkeys inter where schema="J"; properties::@[properties; integerkeys; {"J"$-1 _ x}]];
    
    // Parse the other keys
    {[newkey] 
      $[("i" = last data) and ("J"$-1 _ data:properties[newkey])<>0N;
        // Integer value - trim "i" and set target type long
        [properties[newkey]::"J"$-1 _ data; schema[newkey]::"J"];
        // Non integer value - set target type timestamp, float or symbol
        [
          if[null targettype:schema[newkey]; 
            schema[newkey]::targettype:$[newkey ~ `t; "P"; 0n <> "F"$data; "F"; "S"]
          ];
          properties[newkey]::targettype$data
        ]
      ]
    } each propkeys except integerkeys;

    1 _ properties
  };
  raze to_dict each "\n" vs payload
 };

influx:read0 `:influx.txt;

payloads:parse_influx[();enlist `$"/";] each influx;

extract_payloads:{[payload]
  table:`$"events_",(string payload `table);
  $[table in tables[];
    table set get[table] uj flip enlist each `table _ payload;
    @[`.; table; :; enlist `table _ payload]
  ]
 };

extract_payloads each payloads;
