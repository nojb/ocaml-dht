OCAMLFIND = ocamlfind
LIB_DIR = lib/
DHT_DIR = dht/
CFLAGS = -Wall
STDLIB_DIR = `$(OCAMLFIND) printconf stdlib`
CC = cc

%.o: %.c
	$(CC) $(CFLAGS) -I $(DHT_DIR) -I $(STDLIB_DIR) -I $(LIB_DIR) -o $@ -c $<

$(LIB_DIR)libdhtstubs.a: $(LIB_DIR)dhtstubs.o $(LIB_DIR)socketaddr.o $(LIB_DIR)unixsupport.o
	ar rvs $@ $^

$(LIB_DIR)dht.cmo: $(LIB_DIR)dht.mli $(LIB_DIR)dht.ml
	$(OCAMLFIND) ocamlc -I $(LIB_DIR) -o $@ -c $^

pull_jech_dht:
	git subtree pull --prefix dht https://github.com/jech/dht master --squash

clean:
	rm -f $(LIB_DIR)*.[oa] $(LIB_DIR)*.cm[ioxa] $(LIB_DIR)*.cmxa

.PHONY: clean pull_jech_dht
