(* The MIT License (MIT)

   Copyright (c) 2015 Nicolas Ojeda Bar <n.oje.bar@gmail.com>

   Permission is hereby granted, free of charge, to any person obtaining a copy
   of this software and associated documentation files (the "Software"), to deal
   in the Software without restriction, including without limitation the rights
   to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
   copies of the Software, and to permit persons to whom the Software is
   furnished to do so, subject to the following conditions:

   The above copyright notice and this permission notice shall be included in all
   copies or substantial portions of the Software.

   THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
   IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY, FITNESS
   FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE AUTHORS OR
   COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER LIABILITY, WHETHER
   IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM, OUT OF OR IN
   CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE SOFTWARE. *)

(** This interface implement bindings to Juliusz Chroboczek's
    {{:https://github.com/jech/dht}dht library.}  That library implements the
    variant of the Kademlia Distributed Hash Table (DHT) used in the Bittorrent
    network ({i mainline} variant).

    The following documentation is lightly adapted from the one coming with that
    library. *)

val init : ?ipv4:Unix.file_descr -> ?ipv6:Unix.file_descr -> string -> unit
(** This must be called before using the library.  You pass it a bound IPv4
    datagram socket, a bound IPv6 datagram socket, and your node [id], a
    20-octet array that should be globally unique.

    If you're on a multi-homed host, you should bind the sockets to one of your
    addresses.

    Node ids must be well distributed, so you cannot just use your Bittorrent
    id; you should either generate a truly random value (using plenty of
    entropy), or at least take the SHA-1 of something.  However, it is a good
    idea to keep the id stable, so you may want to store it in stable storage
    at client shutdown. *)

val insert_node : id:string -> Unix.sockaddr -> unit
(** This is a softer bootstrapping method, which doesn't actually send a query
    -- it only stores the node in the routing table for later use.  It is a good
    idea to use that when e.g. restoring your routing table from disk.

    Note that [insert_node] requires that you supply a node id.  If the id turns
    out to be wrong, the DHT will eventually recover; still, inserting massive
    amounts of incorrect information into your routing table is certainly not a
    good idea.

    An additionaly difficulty with [insert_node] is that, for various reasons, a
    Kademlia routing table cannot absorb nodes faster than a certain rate.
    Dumping a large number of nodes into a table using [insert_node] will
    probably cause most of these nodes to be discarded straight away.  (The
    tolerable rate is difficult to estimate; it is probably on the order of one
    node every few seconds per node already in the table divided by 8, for some
    suitable value of 8.) *)

val ping_node : Unix.sockaddr -> unit
(** This is the main bootstrapping primitive.  You pass it an address at which
    you believe that a DHT node may be living, and a query will be sent.  If a node
    replies, and if there is space in the routing table, it will be inserted. *)

type event =
  | EVENT_VALUES of Unix.sockaddr list
  | EVENT_SEARCH_DONE

val periodic : (bytes * int * Unix.sockaddr) option -> (event -> string -> unit) -> float
(** This function should be called by your main loop periodically, and also
    whenever data is available on the socket.  The time after which [periodic]
    should be called if no data is available is returned.  (You do not need to
    be particularly accurate; actually, it is a good idea to be late by a random
    value.)

    The parameters optionally carry a received message [(pkt, len, sa)] where
    the packet is [Bytes.sub pkt 0 len] and [sa] is the origin address, as
    obtained from [Unix.recvfrom] for examples.

    [periodic] also takes a callback, which will be called whenever something
    interesting happens (see below). *)

val search : string -> ?port:int -> ?af:Unix.socket_domain -> (event -> string -> unit) -> unit
(** This schedules a search for information about the info-hash specified in
    [id].  If [port] is given, it specifies the TCP port on which the current
    peer is listening; in that case, when the search is complete it will be
    announced to the network.

    In either case, data is passed to the callback function as soon as it is
    available, possibly in multiple pieces.  The callback function will
    additionally be called when the search is complete.

    Up to [1024] searches can be in progress at a given time; any more, and
    [search] will raise [Failure "dht_search"].  If you specify a new search for
    the same info hash as a search still in progress, the previous search is
    combined with the new one -- you will only receive a completion indication
    once. *)

val get_nodes : ipv4:int -> ipv6:int -> Unix.sockaddr list
(** This retrieves the list of known good nodes, starting with the nodes in our
    own bucket.  It is a good idea to save the list of known good nodes at
    shutdown, and ping them at startup. *)

type nodes =
  {
    good : int;
    dubious : int;
    cached : int;
    incoming : int;
  }

val nodes : Unix.socket_domain -> nodes
(** This returns the number of known good, dubious and cached nodes in our
    routing table.  This can be used to decide whether it's reasonable to start a
    search; a search is likely to be successful as long as we have a few good nodes;
    however, in order to avoid overloading your bootstrap nodes, you may want to
    wait until good is at least 4 and good + doubtful is at least 30 or so.

    It also includes the number of nodes that recently sent us an unsolicited
    request; this can be used to determine if the UDP port used for the DHT is
    firewalled.

    If you want to display a single figure to the user, you should display [good
    + doubtful], which is the total number of nodes in your routing table.  Some
    clients try to estimate the total number of nodes, but this doesn't make
    much sense -- since the result is exponential in the number of nodes in the
    routing table, small variations in the latter cause huge jumps in the
    former. *)
