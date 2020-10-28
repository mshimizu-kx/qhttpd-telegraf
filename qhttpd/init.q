gather:((`$":qhttpd") 2:(`gather;1));
qhttpd:((`$":qhttpd") 2:(`qhttpd;2));
stats:((`$":qhttpd") 2:(`stats;1));
payloads:([]ret_sat:();info:();payload:());
done:([]bid:();info:();payload:();result:());
dlq:([]ret_sat:();info:();error:();result:();payload:());
handlers:([endpoint:`$()];handler:())

qsimdjson_init:((`$":qsimdjson_l64") 2:(`qsimdjson_init;1));
qsimdjson:((`$":qsimdjson_l64") 2:(`qsimdjson;3));
pqsimdjson:((`$":qsimdjson_l64") 2:(`pqsimdjson;4));
qsimdjson_init[];

payloads:([]payload:())

/ httpd[18]
/ batch:10000000
/ .z.ts:{[]payloads::payloads,([]json:raze {.j.k -35!x} peach gather[batch])}
/ .z.ts:{[]payloads::payloads,([]json:gather[batch])}
/ \t 1
