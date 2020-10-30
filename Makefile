install:
	cp src/handlers-slash-telegraf-slash-influx.q qhttpd/
	cp src/handlers-slash-tsbs-slash-influx.q qhttpd/
	cp src/init-rdb.q qhttpd/
	cp src/schemas-slash-telegraf-slash-influx.json qhttpd/
	cp src/schemas-slash-tsbs-slash-influx.json qhttpd/
