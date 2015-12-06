# ocaml-dht

OCaml bindings for [jech/dht](https://github.com/jech/dht), a tiny and efficient
C library used to access the BitTorrent DHT.  This project used to contain a
pure OCaml implementation of the DHT extracted from MLdonkey, but it was too
unstable for heavy-duty use so it has been replaced by these bindings.  The pure
OCaml implementation might return if I can fix it.

## Installation

```bash
make
make install
```

More docs to come once this is more stable.

### Documentation

See [online](https://nojb.github.io/ocaml-dht).

### Usage

See
[find_ih.ml](https://github.com/nojb/ocaml-dht/blob/master/lib_test/find_ih.ml)
for a very simple example of how to use the library.

### LICENSE

MIT.

## Contact

Nicolas Ojeda Bar at n.oje.bar@gmail.com.
