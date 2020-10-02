
## qhttpd-telegraf - Telegraf Output Plugin for forwarding Influx Line Protocol event data to kdb+ via qhttpd

It's just configuration! By virtue of qhttpd/kdb+ accepting Influx Line Protocol formatted events, you can now receive Telegraf metrics into your kdb+ TP/RDB.

Incoming events from Telegraf will be received by qhttpd, and forwarded to a Processing Plant where they will be marshalled into K dicts, and forwarded to your TP/RDB.

Influx Line Protocol formatted events can be dynamic in terms of the key=values presented. The accompanying init-rdb.q shows how to break out, conform and evolve schemas (both for incoming events and the target tables), and shuttle the incoming events into the relevant table.

A typical event like:

```
  system,host=my.host load15=0.3,n_cpus=56i,n_users=0i,load1=0.26,load5=0.48 1601289566000000000
```

Will ultimately land in the 'events_system' table. Any new key=values will cause new columns to be added to that in-memory table.

Note: For smaller installations, you can use the handler without qhttpd and hook it up to kdb+'s native HTTP server. This project is left as an exercise for the reader.

### Demo

Pre-requisites:

1. Obtain a distribution of qhttpd and place it in ./qhttpd/ (a symlink is also fine if you have an existing installation)

2. Install the qhttpd-telegraf handler into your qhttpd:

```
$ make install
<this merely copies the qhttpd-telegraf handlers-slash-telegraf-slash-influx.q into ./qhttpd/>
```

3. Optionally, copy (or merge) the included init-rdb.q into your qhttpd/ directory, or your target TP/RDB.

3. Launch qhttpd (follow the README included with qhttpd if you're unfamiliar!)

```
$ cd qhttpd
$ ./qhttpd console
<once in console>
$ ./qhttpd start
<in another terminal>
```

4. Launch Telegraf

```
$ ./go-telegraf.sh
<this will launch Telegraf via their Docker container, using the telegraf.conf in this directory>
```

Note: The go-telegraf.sh launches the container with --net=host by default, which could conflict with local ports on your system.

5. You will almost immediately start to see Telegraf events in your RDB.

### Integrating to an existing Telegraf/qhttpd deployment

Simply add the following to telegraf.conf:

```
[[outputs.http]]
  url = "http://127.0.0.1:80/telegraf/influx"
  data_format = "influx"
```

Add the Influx Line Protocol handler to your qhttpd/kdb+ installation:

```
  handlers-slash-telegraf-slash-influx.q
```

(this will register the handler on the URL /telegraf/influx)

And either use the provided init-rdb.q or integrate similar into your TP/RDB setup.

Author(s):
  Jay Fenton <jfenton1@kx.com> || <na.nu@na.nu>
  Your Name Here

