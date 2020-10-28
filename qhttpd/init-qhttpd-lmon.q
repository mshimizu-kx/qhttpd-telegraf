//++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++//
//                            File Description                          //
//++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++//

/
* @file
* init-qhttpd-lmon.q
* @overview
* Initialize local monitoring process.
\

//++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++//
//                     Open Namespace: qhttpd_lmon                      //
//++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++//

// WARNING!! - NEVER LOAD ANOTHER FILE INSIDE NAMESPACE!!
\d .qhttpd_lmon

//%% Global Variables %%//vvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvv/

/
* Command line arguments
\
COMMANDLINE_ARGUMENTS:.Q.opt .z.X;

// Display to standard out
-1 "Passed parameters:";
-1 .Q.s COMMANDLINE_ARGUMENTS;

/
* Name of this monitoring process
\
PROCESS_NAME:`$first COMMANDLINE_ARGUMENTS[`name];

/
* Connection handle to the central monitoring process
\
MONITORING_CONNECTION:hopen first COMMANDLINE_ARGUMENTS[`mon];

/
* Handlers to be used for each data feed (e.g. telegraf)
* # Key Columns
* - endpoint  | symbol |    : HTTP request endpoint e.g telegraf
* # Value Columns
* - debug     | bool |      : Debug mode
* - handler   | function |  : Parse function to be called against passed data 
\
HANDLERS:MONITORING_CONNECTION (`.qhttpd_mon.register; PROCESS_NAME; .z.a);

/
* Connections of local process plants and qhttpd processes
* # Key Columns
* - name    | symbol |  : name of process-plant and qhttpd process
* # Value Columns
* - ip      | int |     : IP address of the process plant and qhttpd process
* - handle  | int |     : Connection handle to the process-plant and qhttpd process
\
CONNECTION:1!flip `name`ip`handle!"sii"$\:();

/
* Table to track the message sequence number.
* # Key Columns
* - endpoint  | symbol |  : endpoint
* # Value Columns
* - seq       | long |    : sequence number
\
SEQ_TRACK:1!flip `endpoint`seq!"sj"$\:();

/
* Interval (nanoseconds) to push data to process plants(?).
* Set as 10 milliseconds by default.
\
PUSH_INTERVAL:10000000;
/
* Data volume (bytes) to send to process-plants(?).
* Set as 10MB by default.
\
PUSH_BYTES:10000000;

//%% Functions %%//vvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvv/

/
* @brief
* Get configured push interval. Called by qhttpd process.
* @return
* - long: push interval (nanoseconds)
\
retrieve_push_interval:{[] PUSH_INTERVAL};

/
* @brief
* Get configured push bytes. Called by qhttpd process.
* @return
* - long: push bytes (bytes)
\
retrieve_push_bytes:{[] PUSH_BYTES};

/
* @brief
* Register a process-plant and a qhttod process onto connection pool and propagate request handlers to the process-plant.
*  Called by process plants and qhttpd process.
* @param
* name: process name of the process-plant and qhttpd process
* @type
* - symbol
* @param
* ip: IP address of the process-plant and the qhttpd process
\
register:{[name;ip]
  `.qhttpd_lmon.CONNECTION upsert `name`ip`handle!(name; ip; .z.w);
  if[name like "pp-*"; neg[.z.w](`.qhttpd_pp.handlers_upd; HANDLERS)];
 };

/
* @brief
* Broadcast update of handlers to process-plants.
\
handlers_broadcast:{[]
  {[h] neg[h] (`.qhttpd_pp.handlers_upd; HANDLERS)} each exec handle from CONNECTION;
 };

/
* @brief
* Update request handlers with passed ones and then propagate them to process-plants.
*  Called by the central monitoring process.
* @param
* newhandlers: Table of requst handlers with the same form as `HANDLERS`
\
handlers_upd:{[newhandlers]
  // Update local handlers
  `.qhttpd_lmon.HANDLERS upsert newhandlers;
  // Propagate to process-plants
  handlers_broadcast[];
 };

/
* @brief
* Spawn specified component in the `plan`. Called by the central monitoring process.
* @param
* plan: set fo configurations, i.e. component, ID and spawn command
* @type
* - dictionary
* @return
* - bool: 1b indicates successs
\
spawn:{[plan]
  res:@[system; "./qhttpd ", string[plan `component], " ", string[plan `id], " ", plan `cmd; {[err] `SPAWN_FAILURE}];
  $[res ~ `SPAWN_FAILURE; 0b; 1b]
 };

/
* @brief
* Pass a tuple of a function and arguments which came from process-plant to the central monitoring process.
* @param
* func: Function
* @type
* - function
* @param
* args: Arguments of the function
* @type
* - any type
\
relay2mon:{[func;args] neg[MONITORING_CONNECTION](func; args) };


\d .
//++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++//
//                      Close Namespace: qhttpd_lmon                    //
//++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++//

//++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++//
//                           Open Namespace: tel                        //
//++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++//

/
* @brief
* Set new sequence number for given `ep` and return previoud sequence number for it.
* @param
* ep_and_seq: tuple of endpoint and sequence number
* @type
* compound list
* @return
* - long: previous sequence number
\
.tel.seqgetandset:{[ep_and_seq]
  endpoint:ep_and_seq[0];
  seq:ep_and_seq[1];
  prevseq:.qhttpd_lmon.SEQ_TRACK[endpoint; `seq];
  // If the previous sequence is not known, fake that it was `seq`-1
  if[null prevseq; prevseq:seq-1];
  .qhttpd_lmon.SEQ_TRACK[endpoint; `seq]::seq;
  prevseq
 };

//++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++//
//                          Close Namespace: tel                        //
//++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++//

//++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++//
//                            System Setting                            //
//++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++//

/
* @brief
* Display IP address, user and closed handle and update connection pool
\
.z.pc:{[h]
  -1 "disconnect ", .Q.s (.z.a; .z.u; h);
  update handle:0Ni from `.qhttpd_lmon.CONNECTION where handle=h;
 };
