OCAMLFIND = ocamlfind
LIB_DIR = lib/
DHT_DIR = dht/
LIBTEST_DIR = lib_test/
STDLIB_DIR = `$(OCAMLFIND) printconf stdlib`
CFLAGS = -Wall
OCAMLFLAGS = -safe-string -g
CC = cc

all: $(LIB_DIR)dht.cma $(LIBTEST_DIR)find_ih $(LIBTEST_DIR)find_ih.opt

%.o: %.c
	$(CC) $(CFLAGS) -I $(DHT_DIR) -I $(STDLIB_DIR) -I $(LIB_DIR) -o $@ -c $<

$(LIB_DIR)libdht.a: $(LIB_DIR)dhtstubs.o $(LIB_DIR)socketaddr.o $(LIB_DIR)unixsupport.o $(DHT_DIR)dht.o
	ar rvs $@ $^

$(LIB_DIR)dht.cmo: $(LIB_DIR)dht.mli $(LIB_DIR)dht.ml
	$(OCAMLFIND) ocamlc $(OCAMLFLAGS) -I $(LIB_DIR) -o $@ -c $^

$(LIB_DIR)dht.cmx: $(LIB_DIR)dht.mli $(LIB_DIR)dht.ml
	$(OCAMLFIND) ocamlopt $(OCAMLFLAGS) -I $(LIB_DIR) -o $@ -c $^

$(LIB_DIR)dht.cma: $(LIB_DIR)dht.cmo $(LIB_DIR)libdht.a
	$(OCAMLFIND) ocamlc $(OCAMLFLAGS) -I $(LIB_DIR) -custom -a -o $@ $< -cclib -ldht

$(LIB_DIR)dht.cmxa: $(LIB_DIR)dht.cmx $(LIB_DIR)libdht.a
	$(OCAMLFIND) ocamlopt $(OCAMLFLAGS) -I $(LIB_DIR) -a -o $@ $< -cclib -ldht

$(LIBTEST_DIR)find_ih.cmo: $(LIBTEST_DIR)find_ih.ml
	$(OCAMLFIND) ocamlc $(OCAMLFLAGS) -package lwt.unix -I $(LIB_DIR) -linkpkg -o $@ -c $^

$(LIBTEST_DIR)find_ih: $(LIBTEST_DIR)find_ih.cmo $(LIB_DIR)dht.cma
	$(OCAMLFIND) ocamlc $(OCAMLFLAGS) -package lwt.unix -I $(LIB_DIR) -linkpkg -o $@ dht.cma $<

$(LIBTEST_DIR)find_ih.opt: $(LIBTEST_DIR)find_ih.ml $(LIB_DIR)dht.cmxa
	$(OCAMLFIND) ocamlopt $(OCAMLFLAGS) -package lwt.unix -I $(LIB_DIR) -linkpkg -o $@ dht.cmxa $<

pull_jech_dht:
	git subtree pull --prefix dht https://github.com/jech/dht master --squash

clean:
	rm -f $(LIB_DIR)*.[oa] $(LIB_DIR)*.cm*
	rm -f $(LIBTEST_DIR)find_ih.cm* $(LIBTEST_DIR)find_ih.o*

.PHONY: clean pull_jech_dht
