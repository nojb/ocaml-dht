OCAMLFIND = ocamlfind
LIB_DIR = lib/
DHT_DIR = dht/

$(LIB_DIR)dhtstubs.o: $(LIB_DIR)dhtstubs.c
	$(OCAMLFIND) ocamlc -I $(DHT_DIR) -o $@ -c $<

$(LIB_DIR)dht.cmo: $(LIB_DIR)dht.mli $(LIB_DIR)dht.ml
	$(OCAMLFIND) ocamlc -I $(LIB_DIR) -o $@ -c $^

update_jech_dht:
	git

clean:
	rm -f $(LIB_DIR)*.[oa] $(LIB_DIR)*.cm[ioxa] $(LIB_DIR)*.cmxa

.PHONY: clean
