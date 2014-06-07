(* The MIT License (MIT)

   Copyright (c) 2010 ygrek <ygrek@autistici.org>
   Copyright (c) 2014 Nicolas Ojeda Bar <n.oje.bar@gmail.com>

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

(** The Kademlia routing table implementation.  This is a tree that maps SHA1
    keys to known nodes. *)

(** The possible status of a node. *)
type status =
  | Good
  | Bad
  | Unknown
  | Pinged

(** The routing table. *)
type table

type node_info = SHA1.t * Addr.t

val create : SHA1.t -> table
(** Create a new routing table.  The argument is our DHT id. *)
  
type ping_fun = Addr.t -> (node_info option -> unit) -> unit
(** The type of a function used to send a ping to a node at the given address.
    The second argument is invoked with [Some n] if the node replies contact
    information [n] and is invoked with [None] otherwise. *)

val update : table -> ping_fun -> status -> SHA1.t -> Addr.t -> unit
(** [update rt ping st id addr] updates the routing table information for [id].
    If [id] already exists, its address is updated with [addr] and marked fresh,
    status set to [status].  If [addr] is found in the bucket but with a
    different id, then the id is replaced by [id], marked fresh and status set
    to [status].  If [id] or [addr] is not found in the bucket, and if the
    bucket has less than the maximum allowed number of elements, a new fresh
    node with status [status] is inserted in the bucket.  If the bucket is
    already maxed out, then if any ``Bad'' node is found or a node that has been
    ``Pinged'', but who we have not heard back from in a long time, it is thrown
    out and replaced by a new fresh node with id [id] and status [status].  If
    we get to this stage, then any ``Good'' nodes that we have not heard back
    from in a long time get marked as ``Unknown''.  Finally, if no bad nodes or
    expired pinged ones are found, there are two possibilities.  If there are no
    nodes with ``Unknown'' status, we either split the bucket (if the bucket
    contains our own id) or we reject the node.  On the other hand, if there are
    some nodes with ``Unknown'' status, we ping them and wait for the responses.
    As they arrive we either mark the nodes as ``Good'' (if a response was
    received) or ``Bad'' (if no response was received).  Once all the
    ``Unknown'' nodes have been dealt with, the insertion is tried again. *)

val find_node : table -> SHA1.t -> node_info list
(** Find the 8 closest nodes to the given id in the table. *)

val refresh : table -> (SHA1.t * node_info list) list
(** Used to periodically refresh the routing table.  Returns the nodes that need
    to be checked to see if they are still good. *)

val size : table -> int
(** The total number of nodes in the table (good, bad, pinged, unknown). *)

val bucket_nodes : int
(** the number of nodes in a bucket.  Currently 8. *)
