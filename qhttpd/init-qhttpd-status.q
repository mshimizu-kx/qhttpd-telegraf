
params:.Q.opt .z.X;
0N!params;
qhttpds:"J"$" " vs first params[`qhttpds];
rdbs:"J"$" " vs first params[`rdbs];
hqhttpds:hopen each qhttpds;
hrdbs:hopen each rdbs;
.z.ts:{
  cs:flip {(x)"(ready[]; count payloads; count dlq)"} each hqhttpds;
  qhttpdstats::`t`sumready`ready`sumpayloads`payloads`sumdlq`dlq!(.z.p;sum cs[0];cs[0];sum cs[1];cs[1];sum cs[2];cs[2]);
  0N!"qhttpds -=- ",raze raze {(string key x),'"=",'(string value x),'" "}qhttpdstats;

  cs:{(x)"(count payloads)"} each hrdbs;
  rdbstats::`t`sumpayloads`payloads!(.z.p;sum cs;cs);
  0N!"   rdbs -=- ",raze raze {(string key x),'"=",'(string value x),'" "}rdbstats;
  }
\t 1000
