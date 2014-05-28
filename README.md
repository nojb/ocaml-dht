# ocaml-dht

OCaml-DHT is a small BitTorrent DHT implementation.  It is shamelessly based in the one found in [MLdonkey](http://mldonkey.sourceforge.net), but adapated to work with [Lwt](http://ocsigen.org/lwt/).

This is a preliminary release.

## Installation

The easiest way is to use [OPAM](http://opam.ocaml.org).
```sh
opam install dht
```

Alternatively, clone from git and install manually:
```sh
cd ~/tmp
git clone https://github.com/nojb/ocaml-dht
cd ocaml-dht
make
make install
```

Either way the end-result will be a OCaml library (findlib name: `dht`) and a executable `find_ih`.

### Documentation

Look in `DHT.mli`, `Kademlia.mli`, and `KRPC.mli`.

### Usage

First, one needs to bootstrap using `DHT.auto_bootstrap`. Then one can query for peers using
`DHT.query_peers`.  To see how it works, get a nice info hash
you are interested in (e.g., `4D753474429D817B80FF9E0C441CA660EC5D2450` for Ubuntu 14.04) and execute:

```sh
$ find_ih 4D753474429D817B80FF9E0C441CA660EC5D2450
```

You will see a lot of debug output which explains (if you know what it means) what is going on.

## Comments

Comments, bug reports and feature requests are very welcome: n.oje.bar@gmail.com.
