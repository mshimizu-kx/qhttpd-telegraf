{[i;eps;p]

  schema_diagnostics::enlist `t`table`fleet`model`name`driver`device_version`load_capacity`fuel_capacity`nominal_fuel_consumption`fuel_state`current_load`status!"ZSSSSSSIIIFII";
  schema_readings::enlist `t`table`name`fleet`driver`model`device_version`load_capacity`fuel_capacity`nominal_fuel_consumption`latitude`longitude`elevation`velocity`heading`grade`fuel_consumption!"ZSSSSSSSIIFFIIIII";
  schemas::`diagnostics`readings!(schema_diagnostics;schema_readings);

  / FIXME: Possible bug in qhttpd, I think we get the trailing \n at the end of the HTTP body
  p:-1_p;

  / Processor for Influx Line Protocol formatted events
  /   e.g. readings,name=truck_40,fleet=North,driver=Rodney,... load_capacity=5000,fuel_capacity=300,... 1451606400000000000
  / TODO: ms/s time resolution (currently must be ns)
  / TODO: schema evolution
  es:raze {[i;eps;p]
    r:("**J";" ") 0:p;
    / Extract timestamp and massage into parseable epoch format + rest of the key=values
    t:string r[2];
    e::raze "t=",(10#t),".",(-6#t),",table=",r[0],",",r[1];
    e::enlist (!/)"S=,"0:e;
    t:`$first e`table;

    / Choose appropriate schema based on event type
    schema::schemas[t]; 

    ks:(key meta e)`c;

    / Influx Line Protocol represents integers as e.g. 5i - chop the trailing i off any values which are dest. schema "I"
    integer_keys::asc (key flip schema) where (value schema[0])="I";
    { if[x in integer_keys;
      if[(last (first e[x]))="i";
        e[x]::-1_(first e[x])
      ]; 
    ]} each ks;

    / Build the schema transformation (as functional update list) by looking up the desired schema type for each key found in the event
    s:raze {[x]
      / Return the functional schema transform for this key
      (enlist x[0])!(enlist ($[x[1]=`s; `$; $[(string x[1])[0]]]; x[0]))
    } each {
      (x; `$schema[x])
    } each ks;
    / Apply schema transformation
    te:![e; (); 0b; s];

    / Now revisit the schema, and build a skeleton we can overlay our event onto
    ksc:(key meta schema)`c;
    typednulls:{
      / Select appropriately typed null
      (`P`S`I`F!(0Np;`;0Ni;0n))[`$first schema[x]]
    } each ksc;
    skel:(ksc!(count ksc)#typednulls);

    / Populate each event dict with any missing key/values from schema
    re:flip skel,(flip te);
    re
  }[i;eps;] each "\n" vs p;
  es
}
