.u.upd:insert
stats:([]bid:();from:();n:();prs:();pre:();pus:();pue:())
payloads:([]bid:();info:();payload:())
/ .z.ts:{delete from `payloads; .Q.gc[]}
/ \t 500
h:hopen each 5001 + til 10
.z.ts:{cs:{(x)"count payloads"} each h; 0N!(.z.p;sum cs;cs)}
\t 1000

