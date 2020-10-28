{[info_unused_;endpoints_unused_;payload]

  schema_diagnostics::`time`table`fleet`model`name`driver`device_version`load_capacity`fuel_capacity`nominal_fuel_consumption`fuel_state`current_load`status!"PSSSSSSJJIFJJ";
  schema_readings::`time`table`name`fleet`driver`model`device_version`load_capacity`fuel_capacity`nominal_fuel_consumption`latitude`longitude`elevation`velocity`heading`grade`fuel_consumption!"PSSSSSSSJJFFJJJJJ";
  schema_system::`time`table`host`uptime`uptime_format!"PSSJS";
  schema_diskio::`time`table`host!"PSS";
  schema_processes::`time`table`host`running`sleeping`dead`paging`blocked`zombies`stopped`total`unknown`total_threads`idle!"PSSJJJJJJJJJJJ";

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
    properties::raze "time=",(10#timestamp),".",(-9#timestamp),",table=",splitted[0],",",splitted[1];

    // Parse key-value
    properties::(enlist[`]!enlist (::)), (!/)"S=*," 0: properties;
    table:`$properties `table;

    // Choose appropriate schema based on event type
    propkeys:1 _ key properties;
    schema::schemas[table]; 
    // New schema is an empty dictionary
    if[newschema:0=count schema;schema::enlist[`time]!enlist "P"];

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
            schema[newkey]::targettype:$[newkey ~ `time; "P"; 0n <> "F"$data; "F"; "S"]
          ];
          properties[newkey]::targettype$data
        ]
      ]
    } each propkeys except integerkeys;

    1 _ properties
  };
  raze to_dict each "\n" vs payload
 }