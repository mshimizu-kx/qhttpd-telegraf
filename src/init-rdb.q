//++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++//
//                            File Description                          //
//++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++//

/
* @file
* init-rdb.q
* @overview
* Intialize demo RDB process which is directly connected to process plants.
\

//++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++//
//                            Gloabl Variables                          //
//++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++//

/
* Statistics of processing messages by process-plant
* # Columns
* - batch_id              | GUID |      : Batch ID of processed payload
* - process_plant         | symbol |    : Name of process-plant process
* - processing_start_time | timestamp | : Timestamp when the process-plant started to process the batch of payloads
* - processing_end_time   | timestamp | : Timestamp when the process-plant finished to process the batch of payloads
* - publish_time          | timestamp | : Timestamp when the process-plant finished to publish this statistics to RDB
\
STATS:flip `batch_id`process_plant`n`processing_start_time`processing_end_time`publish_time!"gsjppp"$\:();

/
* Table to store payloads until they are processed.
* # Columns
* - batch_id  | GUID |                : Batch ID of processed payload
* - info      | dictionary |          : Information including path, IP address etc.
* - payload   | list of dictionary |  : Payload processed by process-plant
\
PAYLOADS:flip `batch_id`info`payload!"g**"$\:();


//++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++//
//                               Functions                              //
//++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++//

/
* @brief
* Update tables in this process. Called by process plants.
* @param
* table: table name
* @type
* - symbol
* @param
* record: new record of the table
* @type
* - dictionary
\
.u.upd:insert;

/
* @brief
* Process payloads stored in `PAYLOADS` table and update `events_*` tables.
* @param
* payload: payload passed from upstreamtype
* - dictionary
\
.rdb.extract_payloads:{[payload]
  table:`$"events_",(string payload `table);
  $[table in tables[];
    // update table with `uj` 
    table set get[table] uj flip enlist each `table _ payload;
    // Create a new table with the data
    [.dbg.t:table; .dbg.x:payload; @[`.; table; :; enlist `table _ payload]]
  ]
 };

//++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++//
//                            System Setting                            //
//++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++//

/
* @brief
* Timer function to update `events_*` tables with stored payloads and delete payloads after processing.
\
.z.ts:{
  .rdb.extract_payloads each raze PAYLOADS[`payload];
  delete from `PAYLOADS;
 };

//++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++//
//                            Start Process                             //
//++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++//

// Start timer (1 second)
\t 1000
