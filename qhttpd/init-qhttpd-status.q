//++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++//
//                            File Description                          //
//++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++//

/
* @file
* init-qhttpd-status.q
* @overview
* Initialize qhttpd status monitoring process.
\

//++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++//
//                    Open Namespace: qhttpd_status                     //
//++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++//

// WARNING!! - NEVER LOAD ANOTHER FILE INSIDE NAMESPACE!!
\d .qhttpd_status

//%% Global Variables %%//vvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvv/

/
* Command line arguments
\
COMMANDLINE_ARGUMENTS:.Q.opt .z.X;

// Display to standard out
-1 "Passed parameters:";
-1 .Q.s COMMANDLINE_ARGUMENTS;

CRDENTIAL:.[get[`:secret/.eggsand]] each (3 0; 7 1);

/
* Connection pool of process-plants. Use credential to access them.
\
PROCESS_PLANT_CONNECTION:hopen each `$/: "::",/: (" " vs first COMMANDLINE_ARGUMENTS[`qhttpds]),\: ":", (raze string -33!CRDENTIAL 0), ":", raze string -33!CRDENTIAL 1;

/
* Connection pool of RDB processes. RDB processes do not have any access restriction.
\
RDB_CONNECTION:hopen each "J"$" " vs first COMMANDLINE_ARGUMENTS[`rdbs];

\d .
//++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++//
//                    Close Namespace: qhttpd_status                    //
//++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++//

//++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++//
//                            System Setting                            //
//++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++//

/
* @brief
* Timer function to collect the number of queued payloads and erroneous payloads from process-plants
*  and collect queued payloads from RDB prcoesses.
\
.z.ts:{
  ppstats:flip {(x)"(count .qhttpd_pp.PAYLOADS; count .qhttpd_pp.ERROR_PAYLOADS)"} each .qhttpd_status.PROCESS_PLANT_CONNECTION;
  ppstats::`time`total_payloads`payloads`total_error_payloads`error_payloads!(.z.p; sum ppstats[0]; ppstats[0]; sum ppstats[1]; ppstats[1]);
  -1 "qhttpds -=- ",raze raze {(string key x),'"=",'(string value x),'" "} ppstats;

  rdbstats:{(x)"(count PAYLOADS)"} each .qhttpd_status.RDB_CONNECTION;
  rdbstats::`time`total_payloads`payloads!(.z.p; sum rdbstats; rdbstats);
  -1 "   rdbs -=- ",raze raze {(string key x),'"=",'(string value x),'" "} rdbstats;
 };

//++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++//
//                            Start Process                             //
//++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++//

// Start timer (1 second)
\t 1000
