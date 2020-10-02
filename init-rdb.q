
.u.upd:insert

stats:([]bid:();qhttpd:();n:();has:();hae:();pus:();pue:())
payloads:([]bid:();info:();payload:())

lcj:0;
.z.ts:{
  o:lcj;
  lcj::count payloads;
  d:lcj-o;
  if[d>0;0N!"rdb received ",(string d),"/payloads/sec"];
  / {td::{`et`ed!(x`table;x)} each x; { es:exec ed from td where et=x; if[(count es)>0;x insert es];} each `diagnostics`readings} each payloads`payload;
  {
    t:`$"events_",(string x`table);
    if[not null x`table;
      / Mutate target table to conform with new columns
      if[t in key `.[];
        ks:asc distinct (key meta t)`c;
        tks:asc distinct key x;
        deltak:tks where not tks in ks;
        if[(count deltak)>0;
          typednulls:{[x;k]
            enlist (enlist x[k])[-1]
          }[x] each deltak;
          ![t;();0b;deltak!typednulls]
        ];
  
        / Mutate event to conform to any missing columns from target table
        typednulls:{[x;k]
          x[k][-1]
        }[`.[t]] each ks;
        skel:ks!typednulls;
      ];
      x:skel,x;
      .[t;();,;enlist x]
    ];
  } each payloads`payload;
  delete from `payloads;
  };

\t 1000

