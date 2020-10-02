{[i;eps;p]

  schema_diagnostics::`t`table`fleet`model`name`driver`device_version`load_capacity`fuel_capacity`nominal_fuel_consumption`fuel_state`current_load`status!"ZSSSSSSIIIFII";
  schema_readings::`t`table`name`fleet`driver`model`device_version`load_capacity`fuel_capacity`nominal_fuel_consumption`latitude`longitude`elevation`velocity`heading`grade`fuel_consumption!"ZSSSSSSSIIFFIIIII";
  schema_system::`t`table`host`uptime`uptime_format!"SSSIS";
  schema_diskio::`t`table`host!"SSS";
  schema_processes::`t`table`host`running`sleeping`dead`paging`blocked`zombies`stopped`total`unknown`total_threads`idle!"SSSIIIIIIIIIII";

  schemas::`diagnostics`readings`system`processes`diskio!(schema_diagnostics;schema_readings,;schema_system;schema_processes;schema_diskio);

  / Processor for Influx Line Protocol formatted events
  /   e.g. readings,name=truck_40,fleet=North,driver=Rodney,... load_capacity=5000,fuel_capacity=300,... 1451606400000000000
  / TODO: ms/s time resolution (currently must be ns)
  / TODO: schema evolution
  es:raze {[i;eps;p]

    / Split on spaces, handling quoted spaces gracefully (note: cannot use S=* here)
    quotes:0N 2#where p="\"";
    spaces:where p=" ";
    spacesinquotes:quotes {any y within/: x}/: spaces;
    spacesnotinquotes:spaces where not spacesinquotes;
    r:{-1_x} each (0,1+spacesnotinquotes) _ p," ";

    / r:("**J";" ") 0:p; - doesn't work for spaces in quotes

    / Extract timestamp and massage into parseable epoch format + rest of the key=values
    t:last r;
    e::raze "t=",(10#t),".",(-6#t),",table=",r[0],",",r[1];

    e::(!/)"S=*,"0:e;
    t:`$e`table;

    / Choose appropriate schema based on event type
    ks:key e;
    schema::schemas[t]; 
    if[(count schemas[t])=0;schema::ks!(count ks)#"S"];

    / Influx Line Protocol represents integers as e.g. 5i - chop the trailing i off any values which are integers, and map to "J" by default
    integer_keys::(key schema) where (value schema)="I";
    { if[x in integer_keys;
        if[(last (first e[x]))="i";
          e[x]::-1_(first e[x])
        ]; 
      ]
    } each ks;
    / Do another pass, this time looking for integers (trailing "i") which are not in the schema. Trim and force schema to "J" for those.
    { if[((last e[x])="i")&("J"$-1_e[x])<>0Ni; e[x]::-1_e[x]; schema[x]::"J"; ]} each ks;

    / Build the schema transformation (as functional update list) by looking up the desired schema type for each key found in the event
    s:raze {[x]
      / Return the functional schema transform for this key
      (enlist x[0])!(enlist ($[x[1]=`S; `$; $[(string x[1])[0]]]; x[0]))
    } each {
      t:`$schema[x];
      t:$[t=`$" ";`$"S";t];
      (x;t)
    } each ks;
    / Apply schema transformation
    te:![e; (); 0b; s];

    / Now revisit the schema, and build a skeleton we can overlay our event onto
    ksc:key schema;
    typednulls:{
      / Select appropriately typed null
      (`P`S`I`F!(0Np;`;0Ni;0n))[`$schema[x]]
    } each ksc;
    skel:(ksc!(count ksc)#typednulls);

    / Populate each event dict with any missing key/values from schema
    re:skel,te;
    re
  }[i;eps;] each "\n" vs p;
  es
}
