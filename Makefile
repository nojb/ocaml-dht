OCAMLFIND = ocamlfind
LIB_DIR = lib/
DHT_DIR = dht/
CFLAGS = -Wall
STDLIB_DIR = `$(OCAMLFIND) printconf stdlib`
LIBTEST_DIR = lib_test/
CC = cc

%.o: %.c
	$(CC) $(CFLAGS) -I $(DHT_DIR) -I $(STDLIB_DIR) -I $(LIB_DIR) -o $@ -c $<

$(LIB_DIR)libdht.a: $(LIB_DIR)dhtstubs.o $(LIB_DIR)socketaddr.o $(LIB_DIR)unixsupport.o $(DHT_DIR)dht.o
	ar rvs $@ $^

$(LIB_DIR)dht.cmo: $(LIB_DIR)dht.mli $(LIB_DIR)dht.ml
	$(OCAMLFIND) ocamlc -I $(LIB_DIR) -o $@ -c $^

$(LIB_DIR)dht.cma: $(LIB_DIR)dht.cmo $(LIB_DIR)/libdht.a
	$(OCAMLFIND) ocamlc -a -I $(LIB_DIR) -o $@ $< -cclib -ldht

$(LIBTEST_DIR)find_ih: $(LIB_DIR)dht.cma $(LIBTEST_DIR)find_ih.ml
	$(OCAMLFIND) ocamlc -package lwt.unix -I $(LIB_DIR) -o $@ $<

pull_jech_dht:
	git subtree pull --prefix dht https://github.com/jech/dht master --squash

clean:
	rm -f $(LIB_DIR)*.[oa] $(LIB_DIR)*.cm[ioxa] $(LIB_DIR)*.cmxa

.PHONY: clean pull_jech_dht
