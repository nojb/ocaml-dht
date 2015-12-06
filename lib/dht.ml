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

type event =
  | EVENT_VALUES of Unix.sockaddr list
  | EVENT_SEARCH_DONE

external dht_init : Unix.file_descr -> Unix.file_descr -> string -> unit = "caml_dht_init" "noalloc"
external dht_insert_node : string -> Unix.sockaddr -> unit = "caml_dht_insert_node" "noalloc"
external dht_search : string -> int -> Unix.socket_domain -> (event -> id:string -> unit) -> unit =
  "caml_dht_search"

let init s s6 ~id =
  if String.length id <> 20 then invalid_arg "init";
  dht_init s s6 id

let insert_node ~id sa =
  if String.length id <> 20 then invalid_arg "insert_node";
  dht_insert_node id sa

external ping_node : Unix.sockaddr -> unit =
  "caml_dht_ping_node" "noalloc"

external periodic : (bytes * int * Unix.sockaddr) option -> (event -> id:string -> unit) -> float =
  "caml_dht_periodic"

let dht_callback ev info_hash clos =
  clos ev info_hash

let search ~id ~port af callback =
  if String.length id <> 20 then invalid_arg "Dht.search";
  dht_search id port af callback

let () =
  Callback.register "dht_callback" dht_callback

external get_nodes : int -> int -> Unix.sockaddr list = "caml_dht_get_nodes"

type nodes =
  {
    good : int;
    dubious : int;
    cached : int;
    incoming : int;
  }

external nodes : Unix.socket_domain -> nodes = "caml_dht_nodes"
