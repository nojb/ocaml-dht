(* Copyright (C) 2001-2013 ygrek, mldonkey

   This program is free software; you can redistribute it and/or modify
   it under the terms of the GNU General Public License as published by
   the Free Software Foundation; either version 2 of the License, or
   (at your option) any later version.

   This program is distributed in the hope that it will be useful,
   but WITHOUT ANY WARRANTY; without even the implied warranty of
   MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
   GNU General Public License for more details.

   You should have received a copy of the GNU General Public License along
   with this program; if not, write to the Free Software Foundation, Inc.,
   51 Franklin Street, Fifth Floor, Boston, MA 02110-1301 USA. *)

(** Distributed Hash Table (DHT).  Shamelessly based on MLdonkey's
    implementation <http://mldonkey.sourceforge.net>. *)

type node_info = SHA1.t * Addr.t

type t

val ping : t -> Addr.t -> node_info option Lwt.t
(** [ping dht addr] send a [ping] message to [addr].  Returns None if an error
    occurs or if no answer is received for too long.  Otherwise it returns the
    contact information for the responding node.  This function never fails. *)
    
val find_node : t -> Addr.t -> SHA1.t -> (node_info * node_info list) Lwt.t
(** [find_node dht addr id] sends a [find_node] message to [addr].  It can fail,
    or return the contact information of the responding node, and the contact
    information of the node with id [id] (if known) or the 8 closest nodes to
    [id] in the routing table of the responding node. *)
    
val get_peers : t -> Addr.t -> SHA1.t -> (node_info * string * Addr.t list * node_info list) Lwt.t
(** [get_peers dht addr ih] sends a [get_peers] message to [addr].  It can fail,
    or return a tuple [(n, t, values, nodes)], where [n] is the contact
    information for the responding node, [t] is a secret token to be used with
    {!announce}, [values] are the peers that are sharing the torrent with
    info-hash [ih], and [nodes] are the 8 closest nodes to [ih] in the routing
    table of the responding node.  Either [values] or [nodes] can potentially be
    empty. *)
    
val announce : t -> Addr.t -> int -> string -> SHA1.t -> node_info Lwt.t
(** [announce dht addr port token ih] announces to [addr] that we are sharing
    the torrent with info-hash [ih], [port] is our dht port, [t] is the secret token
    received from a previous call to [get_peers].  This call can fail, or it can
    return the contact information of the responding node. *)
    
val query_peers : t -> SHA1.t -> (node_info -> string -> Addr.t list -> unit) -> unit Lwt.t
(** [query_peers dht ih k] tries to find peers that are sharing the info-hash
    [ih].  For each set of received peers, [k] is called with the contact
    information of the responding node, the token received from the corresponding
    call to [get_peers], and the list of received peers.  This function cannot fail. *)
    
val create : int -> t
(** Create a new DHT node listening on the given port. *)
  
val start : t -> unit
(** Start the event loop. *)
  
val update : t -> Kademlia.status -> SHA1.t -> Addr.t -> unit
(** [update dht st id addr] updates the status of the DHT node with contact
    information [(id, addr)] to be [st].  If the node does not exist, it is added. *)
  
val auto_bootstrap : t -> (string * int) list -> unit Lwt.t
(** Bootstrap the DHT node from a list of pairs [(host, port)].  These nodes
    will not be added to the routing table. *)
  
val bootstrap_nodes : (string * int) list
(** A list of predefined bootstrap nodes. *)
