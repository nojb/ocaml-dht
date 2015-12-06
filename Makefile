OCAMLFIND = ocamlfind
LIB_DIR = lib/
DHT_DIR = dht/
LIBTEST_DIR = lib_test/
STDLIB_DIR = `$(OCAMLFIND) printconf stdlib`
CFLAGS = -Wall
OCAMLFLAGS = -safe-string -g
CC = cc

all: lib test_lib

$(DHT_LIB)dht.o: $(DHT_LIB)dht.h $(DHT_LIB)dht.c
	$(MAKE) -C dht

$(LIB_DIR)dhtstubs.o: $(LIB_DIR)dhtstubs.c
	$(CC) $(CFLAGS) -I $(DHT_DIR) -I $(STDLIB_DIR) -I $(LIB_DIR) -o $@ -c $<

$(LIB_DIR)dht.cmo: $(LIB_DIR)dht.mli $(LIB_DIR)dht.ml
	$(OCAMLFIND) ocamlc $(OCAMLFLAGS) -I $(LIB_DIR) -o $@ -c $^

$(LIB_DIR)dht.cmx: $(LIB_DIR)dht.mli $(LIB_DIR)dht.ml
	$(OCAMLFIND) ocamlopt $(OCAMLFLAGS) -I $(LIB_DIR) -o $@ -c $^

$(LIBTEST_DIR)find_ih: $(LIBTEST_DIR)find_ih.ml $(LIB_DIR)dht.cma
	$(OCAMLFIND) ocamlc $(OCAMLFLAGS) -package lwt.unix -I $(LIB_DIR) -linkpkg -o $@ dht.cma $<

$(LIBTEST_DIR)find_ih.opt: $(LIBTEST_DIR)find_ih.ml $(LIB_DIR)dht.cmxa
	$(OCAMLFIND) ocamlopt $(OCAMLFLAGS) -package lwt.unix -I $(LIB_DIR) -linkpkg -o $@ dht.cmxa $<

lib: $(LIB_DIR)dhtstubs.o $(DHT_DIR)dht.o $(LIB_DIR)dht.cmo $(LIB_DIR)dht.cmx
	ocamlmklib -custom -o $(LIB_DIR)dht $^

test_lib: $(LIBTEST_DIR)find_ih $(LIBTEST_DIR)find_ih.opt

find_ih: $(LIBTEST_DIR)find_ih
	LD_LIBRARY_PATH=$(LIB_DIR):$LD_LIBRARY_PATH $^

pull_jech_dht:
	git subtree pull --prefix dht https://github.com/jech/dht master --squash

clean:
	rm -f $(LIB_DIR)*.[oa] $(LIB_DIR)*.cm* $(LIB_DIR)*.so $(DHT_DIR)*.o
	rm -f $(LIBTEST_DIR)find_ih.cm* $(LIBTEST_DIR)find_ih.o*

.PHONY: clean pull_jech_dht
