
.PHONY: all deps qhttpd

all:
	( cd ../qhttpd0/ && make && cp qhttpd.so ../qhome/ ) 

debug:
	( cd ../qhttpd0/ && make debug && cp qhttpd.so ../qhome/ ) 

pkgs:
	yum install golang

deps:
	( cd deps/ws && GOPATH=. go build . && cp ws ../../bin/ )

