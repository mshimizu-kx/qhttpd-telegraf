//++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++//
//                            File Description                          //
//++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++//

/
* @file
* init-qhttpd-pp.q
* @overview
* Initialize process-plant process.
\

//++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++//
//                           External Library                           //
//++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++//

/
* Shared library of JSON parser.
\
// qsimdjson_init:((`$":qsimdjson_l64") 2:(`qsimdjson_init;1));
// qsimdjson:((`$":qsimdjson_l64") 2:(`qsimdjson;3));
// pqsimdjson:((`$":qsimdjson_l64") 2:(`pqsimdjson;4));
// qsimdjson_init[];

//++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++//
//                       Open Namespace: qhttpd_pp                      //
//++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++//

// WARNING!! - NEVER LOAD ANOTHER FILE INSIDE NAMESPACE!!
\d .qhttpd_pp

//%% Global Variables %%//vvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvv/

/
* Table to store payloads temporarily
* # Columns
* - receive_time  | timestamp |   : Timestamp when this process-plant received the payload
* - info          | dictionary |  : Information including path, IP address etc.
* - payload       | string |      : payload
\
PAYLOADS:flip `receive_time`info`payload!"p**"$\:();

/
* Table to store erroneous payloads. This table might be moved somewhere.
* # Columns
* - receive_time  | timestamp |   : Timestamp when this process-plant received the payload
* - info          | dictionary |  : Information including path, IP address etc.
* - error         | string |      : error message
* - payload       | string |      : payload
\
ERROR_PAYLOADS:flip `receive_time`info`error`payload!"p***"$\:();

/
* Handlers to be used for each data feed (e.g. telegraf)
* # Key Columns
* - endpoint  | symbol |    : HTTP request endpoint e.g telegraf
* # Value Columns
* - debug     | bool |      : Debug mode
* - handler   | function |  : Parse function to be called against passed data 
\
HANDLERS:1!flip `endpoint`debug`handler!"sb*"$\:();

/
* Schemas to be used for each data feed (e.g. telegraf)
* # Keys
* Endpoints like `$"/telegraf/influx" will be contained.
* # Values
* Dictionary of schemas for tables for teh endpoint will be contained.
\
SCHEMAS:()!();

/
* Command line arguments
\
COMMANDLINE_ARGUMENTS:.Q.opt .z.X;

// Display to standard out
-1 "Passed parameters:";
-1 .Q.s COMMANDLINE_ARGUMENTS;

/
* Name of this process-plant
\
PROCESS_NAME:`$first COMMANDLINE_ARGUMENTS[`name];

// WHAT IS THIS???
MTCP_CORE:"J"$first COMMANDLINE_ARGUMENTS[`mtcp_core];
// WHAT IS THIS???
QHTTPDPES:"J"$first COMMANDLINE_ARGUMENTS[`qhttpdpes];

/
* Connection handle to RDB process.
\
RDB_CONNECTION:hopen first COMMANDLINE_ARGUMENTS[`rdb];

/
* Connection handle to the local monitoring process.
\
LOCAL_MONITORING_CONNECTION:hopen first COMMANDLINE_ARGUMENTS[`lmon];

/
* Process at most this size of payload each iteration. Set 10MB by default.
\
PUSH_BYTES:10000000;

/
* Counter of passed messages from qhttpd process.
\
HITS:0;

//%% Functions %%//vvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvv/

/
* @brief
* Update request handlers with passed ones. Called by the local monitoring process.
* @param
* newhandlers: Table of requst handlers with the same form as 'HANDLERS'
\
handlers_upd:{[newhandlers]
  // Update local handlers
  `.qhttpd_pp.HANDLERS upsert newhandlers;
 };

/
* @brief
* Update schemas with passed ones. Called by the local monitoring process.
* @param
* newschemas: Dictionary of schemas
\
schemas_upd:{[namespace;newschemas]
  // Update local schemas
  ({[namespace;name;dict] @[`.; `$namespace, "_", string name; :; first each dict]}[namespace] .) each  flip (key; value) @\: newschemas;
 };

/
* @brief
* Process stats information and send it to the central monitoring process and then stores it in `PAYLOADS` table.
* @param
* stat: statistics
* @type
* - dictionary
\
receive_payload:{[stat;info;payload]
  // Increment counter of processed messages
  HITS+::1;
  timestamp:string stat `time;
  stat[`time]:"P"$(10#timestamp), ".", -9#timestamp;
  // Add new key
  stat[`process_plant]:PROCESS_NAME;
  // Send qhttpd stat to the central monitoring process via the local monitoring process
  // Send data as list
  // keys are:
  //  `time`name`num_connections`hits`queued`process_plant
  neg[LOCAL_MONITORING_CONNECTION](`.qhttpd_lmon.relay2mon; `.qhttpd_mon.update_qhttpd_stats; value stat);
  // Update the `PAYLOADS` table with receive_time, info and payload
  // Note: `info` is flipped to store as dictionary
  // `payload` is taken `first` as it is sent as `enlist`
  `.qhttpd_pp.PAYLOADS insert (.z.p; first each flip info; first payload);
 };

/
* @brief
* Process payload with an appropriate handler based on information. Then returns
*  the information and result as a table with the parse status.
* @param
* info: Information to retrieve a proper handler
* @type
* - dictionary
* @param
* payload: bunch of command line protocol message passed from qhttpd process. ex.) system,host=my.host load15=0.3,n_cpus=56i,n_users=0i,load1=0.26,load5=0.48 1601289566000000000
* @type
* list of string
* @return
* table: contains parse status (`Ok or `Err), error message and parsed result (list of dictionary)
\
handle:{[info;payload]
  // given enlist "/customer/abc/1234" returns (`$"/customer/abc/1234"; `$"/customer/abc"; `$"/customer"; `$"/")
  endpoints:`$/:("/" sv/: -2 _ ({-1 _ x}\) "/" vs info `path), "/";
  // find first longest-matching handler
  // qhttpd script assures that the endpoints in `HANDLER` are sorted in lexicographic order as displayed in `ls -1`
  handler:last 0!select from HANDLERS where endpoint in endpoints;
  $[count handler;
    // Found matching handler
    [
      // Retrieve as dictionary
      handlerfunc:handler `handler;
      $[not handler `debug;
        // Non debug mode
        .Q.trp[
          { ([]status:enlist `Ok; error:enlist ""; result:enlist x[0][x[1]; x[2]; x[3]]) }; 
          (handlerfunc; info; handler `endpoint; payload);
          {[err;stacktrace] ([]status:enlist `Err; error:enlist err,"\n",.Q.sbt stacktrace; result:enlist ()) }
        ];
        // Debug mode (don't process payload)
        ([]status:enlist `Ok; error:enlist ""; result:enlist handlerfunc[info; endpoints; payload])
      ]
    ];
    // Could not find matching handler
    ([]status:enlist `Ok; error:enlist ""; result:enlist payload)
  ]
 };

process:{[]
  // ID of this batch payloads
  batch_id:first 1?0Ng;
  // Timestamp when it started to process this batch of payloads
  processing_start_time:.z.p;

  // Retrieve a series of payloads measuring in aggregate up to `PUSH_BYTES` (1 char = 1 byte).
  // Note: `PUSH_BYTES` should be sized to a reasonable JSON megabytes decode per second value.
  batch_num:exec count i from PAYLOADS where sums[count each payload] < .qhttpd_pp.PUSH_BYTES;
  to_be_processed:batch_num # PAYLOADS;
  
  // Remove payloads to be processed from the table.
  PAYLOADS::batch_num _ PAYLOADS;

  // Process payloads and get result in table format 
  results:raze {[data]
    / qsimdjson is ~25% faster than .j.k
    / handle[p`info;] .qsimdjson.k[;0N;0N] p`payload
    handle[data `info; data `payload]
  } each to_be_processed;

  results:to_be_processed ,' results;

  // Record erroneous payloads 
  `.qhttpd_pp.ERROR_PAYLOADS insert select receive_time, info, error, payload from results where status=`Err;

  // Filter out erroneous payloads
  results:select from results where status=`Ok;

  // Timestamp when it finished to process this batch of payloads.
  processing_end_time:.z.p;

  // Publish result to RDB using remote `.u.upd` function
  // keys are:
  //  `batch_id`info`payload
  if[count results; neg[RDB_CONNECTION](`.u.upd; `PAYLOADS; (batch_num # batch_id; results `info; results `result))];

  // Timestamp when it finished to publish this batch to RDB
  publish_time:.z.p;

  // Publish processing statistics to the central monitoring process via the local monitoring process
  // keys are:
  //  `batch_id`process_plant`queued`batch_num`error_payload`processing_start_time`processing_end_time`publish_time
  neg[LOCAL_MONITORING_CONNECTION](`.qhttpd_lmon.relay2mon; `.qhttpd_mon.update_pp_stats; (batch_id; PROCESS_NAME; count PAYLOADS; batch_num; count ERROR_PAYLOADS; processing_start_time; processing_end_time; publish_time));
  
 };


\d .
//++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++//
//                       Close Namespace: qhttpd_pp                     //
//++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++//

//++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++//
//                            System Setting                            //
//++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++//

/
* @brief
* Timer function to process stored payloads and send the result to RDB
*  and statistics to the central monitoring process.
\
.z.ts:{[]
  n:count .qhttpd_pp.PAYLOADS;
  if[n > 0; .qhttpd_pp.process[]];
 };

//++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++//
//                            Start Process                             //
//++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++//

// Register this process-plant to the local monitoring process
.qhttpd_pp.LOCAL_MONITORING_CONNECTION (`.qhttpd_lmon.register; .qhttpd_pp.PROCESS_NAME; .z.a);

// Start timer (500 miiliseconds)
\t 500
