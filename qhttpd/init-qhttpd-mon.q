//++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++//
//                            File Description                          //
//++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++//

/
* @file
* init-qhttpd-mon.q
* @overview
* Initialize qhttpd central monitoring process.
\

//++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++//
//                      Open Namespace: qhttpd_mon                      //
//++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++//

// WARNING!! - NEVER LOAD ANOTHER FILE INSIDE NAMESPACE!!
\d .qhttpd_mon

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
* Handlers to be used for each data feed (e.g. telegraf)
* # Key Columns
* - endpoint    | symbol |    : HTTP request endpoint e.g telegraf
* # Value Columns
* - debug       | bool |      : Debug mode
* - handler     | function |  : Parse function to be called against passed data 
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
* Connections of local monitoring processes
* # Key Columns
* - name    | symbol |  : process name of a local monitoring process
* # Value Columns
* - ip      | int |     : IP address of the local monitoring process
* - handle  | int |     : Handle to the local monitoring process
\
LOCAL_MONITORING_CONNECTION:1!flip `name`ip`handle!"sii"$\:();

/
* Statistics coming from qhttpd process
* # Columns
* - time            | timestamp | : time
* - name            | symbol |    : process name
* - num_connections | long |      : The number of concurrent HTTP connections of qhttpd process
* - hits            | long |      : The number of messages passed to the qhttpd process
* - queued          | long |      : The number of queued messages coming from upstream
* - process_plant   | symbol |    : name of process-plant process which is connected to this qhttpd process
\
QHTTPD_STATS:flip `time`name`num_connections`hits`queued`process_plant!"psjjjs"$\:();

/
* Statistics coming from process-plants
* # Columns
* - batch_id              | GUID |      : Batch ID of processed payload
* - process_plant         | symbol |    : Name of process-plant process
* - queued                | long |      : The number of unprocessed payloads in `.qhttpd.pp.PAYLOADS` table.
* - batch_num             | long |      : The number of payloads included in the batch
* - error_payload         | long |      : The number of payloads which caused error in processing
* - processing_start_time | timestamp | : Timestamp when the process-plant started to process the batch of payloads
* - processing_end_time   | timestamp | : Timestamp when the process-plant finished to process the batch of payloads
* - publish_time          | timestamp | : Timestamp when the process-plant finished to publish this statistics to RDB
\
PROCESS_PLANT_STATS:flip `batch_id`process_plant`queued`batch_num`error_payload`processing_start_time`processing_end_time`publish_time!"gsjjjppp"$\:();

/
* Table listing processes, tied up local monitoring processes and spawn commands
* # Columns
* - component | symbol |  : component name, e.g. mon, lmon, pp etc.
* - lmon      | symbol |  : name of connected local monitoring process
* - id        | symbol |  : unique name among the same kind of components
* - cmd       | string |  : command to launch the component
\
PLAN:("SSS*";enlist ",")0:`:plan.csv

/
* Alert records.
* # Columns
* - trigger_type  | symbol |    : A kind of trigger of the alert
* - payload       | string |    : Contents of the alert
* - update_time   | timestamp | : Timestamp of the alert 
\
ALERTS:flip `trigger_type`payload`update_time!"s*p"$\:();

//%% Functions %%//vvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvv/

/
* @brief
* Ask local monitoring processes to return all IDs of running processes
* @return
* - list of symbols: ID of all running processes
\
get_running_ids:{[]
  (), raze {[h] h "exec name from .qhttpd_lmon.CONNECTION where not null handle"} each exec handle from LOCAL_MONITORING_CONNECTION
 };

/
* @brief
* Register a local monitoring process. Called by local monitoring processes when they start.
* @return
* - table: Registered handlers for each data feed
\
register:{[name;ip]
  `.qhttpd_mon.LOCAL_MONITORING_CONNECTION upsert `name`ip`handle!(name; ip; .z.w);
  HANDLERS
 };

/ processing plants call these (via their lmon) to uplink their qhttpd (relayed) and pp stats
/
* @brief
* Insert a new record into `QHTTPD_STATS` table. Called by process-plants via local monitoring processes.
* @param
* stat: statistics of qhttpd process
\
update_qhttpd_stats:{[stat] `.qhttpd_mon.QHTTPD_STATS insert stat };

/
* @brief
* Insert a new record into `PP_STATS` table. Called by process-plants via local monitoring processes.
* @param
* stat: statistics of process-plant process
\
update_pp_stats:{[stat] `.qhttpd_mon.PROCESS_PLANT_STATS insert stat }

/
* @brief
* Order local monitoring processes to spawn `n` new components.
* @param
* comp: component name e.g. pp.
* @type
* - symbol
* @param
* n: The number of processes to spawn.
* @type
* - long
* @return
* - long: The number of spawned processes.
\
add_n_components:{[comp;n]
  // Get running IDs
  running:get_running_ids[];
  // Gather `n` non-running tasks from the plan
  deploy:n sublist select from PLAN where component=comp, not id in running;
  // Ask the local monitoring processes to spawn them
  {[plan]
    neg[LOCAL_MONITORING_CONNECTION[plan `lmon] `handle] (`.qhttpd_lmon.spawn; plan)
  } each deploy;
  count deploy
 };

/
* @brief
* Ask local monitoring processes to spawn 1 process based on the number of current connection and
*  the connection capacity under current number of processes.
\
autoscaling:{[]
  // Sum `cs` which exists within last 10 seconds by 1 second and then pick up latest sum of the number of connections.
  // If record does not exist it is set 0.
  num_conns:0 ^ exec last num_connections from 0!select sum num_connections by 0D00:00:01 xbar time from QHTTPD_STATS where time > .z.p-0D00:00:10;

  // Get running IDs.
  running:get_running_ids[];
  // connection capacity is 1000 when no process is running.
  conn_capacity:1000 ^ 1000 * count running;
  add:conn_capacity < num_conns;
  if[add=1b;
    if[add_n_components[1] > 0;
      -1 ".qhttpd_mon.autoscaling: current #qhttpds=", string[count running], " aggregated connection capacity=", string[conn_capacity], " aggregated #connection=", string[num_conns], " add=", string add
    ]
  ];
 };

/
* @brief
* Broadcast update of handlers to local monitoring processes.
\
handlers_broadcast:{[]
  {[h] neg[h] (`.qhttpd_lmon.handlers_upd; HANDLERS) } each exec handle from LOCAL_MONITORING_CONNECTION;
 };

/
* @brief
* Broadcast update of schemas to local monitoring processes.
\
schemas_broadcast:{[namespace;newschemas]
  {[ns;schm;h] neg[h] (`.qhttpd_lmon.schemas_upd; ns; schm) }[namespace; newschemas] each exec handle from LOCAL_MONITORING_CONNECTION;
 };


\d .
//++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++//
//                      Close Namespace: qhttpd_mon                     //
//++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++//

//++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++//
//                           Open Namespace: tel                        //
//++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++//

/
* @brief
* Insert a new alert record to `ALERT` table.
* @param
* alert: A new record of alert
* @type
* - dictionary
\
.tel.add_alert:{[alert] `.qhttpd_mon.ALERTS insert alert};

//++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++//
//                          Close Namespace: tel                        //
//++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++//

//++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++//
//                            System Setting                            //
//++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++//

/
* @brief
* Handle request from shell script via web socket.
*  Update of handlers is done in this function.
* @param
* request: Request from shell script.
\
.z.ws:{[request]
  request:.j.k request;
  command:`$request `cmd;
  $[
    // Case: set //----------------------/
    command=`set;
      // Update handlers, propagate the update to local monitoring processes and send back response
      {[request_]
        .Q.trp[
          {[request_]
            // Update handlers
            `.qhttpd_mon.HANDLERS upsert `endpoint`debug`handler!(`$request_ `endpoint; 0b; get request_ `handler); 
            // Propagate handler update to local monitoring processes
            .qhttpd_mon.handlers_broadcast[];
            // Send back response to shell
            neg[.z.w] "{\"response\":\"OK\"}"
          };
          request_;
          // Send back response with error message and stack trace
          {[err;stacktrace] neg[.z.w] "{\"response\":\"BAD\",\"because\":\"",err,"\",\"trace\":\"",(ssr[ssr[.Q.sbt stacktrace;"\\";"\\\\"];"\"";"\\\""]),"\"}" }
        ]
      }[request];
    // Case: set_schema //----------------------/
    command=`set_schema;
      // Update schemas, propagate the update to local monitoring processes and send back response
      {[request_]
        .Q.trp[
          {[request_]
            schemas:.j.k request_ `schema;
            namespace: request_ `namespace;
            // ex.) @[`.; `telegral_influx_disk; :; `time`table!"PS"] 
            ({[namespace;name;dict] @[`.; `$namespace, "_", string name; :; first each dict]}[namespace] .) each  flip (key; value) @\: schemas;
            .qhttpd_mon.schemas_broadcast[namespace; schemas];
            neg[.z.w] "{\"response\":\"OK\"}"
          };
          request_;
          {[err;stacktrace]
            neg[.z.w] "{\"response\":\"BAD\", \"because\":\"", err, "\",\"trace\":\"",(ssr[ssr[.Q.sbt stacktrace;"\\";"\\\\"];"\"";"\\\""]),"\"}"
          }
        ]
      }[request];
    // Case: show //---------------------/
    command=`show;
      // Send back `HANDLERS` table
      neg[.z.w] .j.j .qhttpd_mon.HANDLERS;
    // Case: debug //--------------------/
    command=`debug;
      {[request_]
        ep:`$request_ `endpoint;
        // Turn on debug mode
        update debug:1b from `.qhttpd_mon.HANDLERS where endpoint=ep;
        // Send back response to shell
        neg[.z.w] "{\"response\":\"OK\"}";
        // Propagate update to local monitoring processes
        .qhttpd_mon.handlers_broadcast[]
      }[request];
    // Case: add_n //--------------------/
    command=`add_n;
      {[request_]
        component:`$request_ `component;
        n:"J"$request_ `n;
        // Ask local monitoring processes to spawn `n` components.
        .qhttpd_mon.add_n_components[component; n];
        // Send back response to shell.
        neg[.z.w] "{\"response\":\"OK\"}"
      }[request];
    // Case: default //------------------/
    {}
  ]
 };

/
* @brief
* Display IP address, user and closed handle and update connection pool
\
.z.pc:{[h] 
  -1 "disconnect ",.Q.s (.z.a;.z.u;h);
  update handle:0Ni from `.qhttpd_mon.LOCAL_MONITORING_CONNECTION where handle=h;
 };

/
* @brief
* Timer function to check if scaling is necessary.
\
.z.ts:{
//  .qhttpd.autoscaling[];
 };

//++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++//
//                            Start Process                             //
//++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++//

// Start timer (1 second)
\t 1000
