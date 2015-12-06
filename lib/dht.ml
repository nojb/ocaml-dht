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

type bigstring =
  Bigarray.Array1.t

type event =
  | EVENT_VALUES of Unix.sockaddr list
  | EVENT_SEARCH_DONE

external dht_init : Unix.file_descr -> Unix.file_descr -> string -> unit = "caml_dht_init" "noalloc"
external dht_periodic : (bytes * int * Unix.sockaddr) option -> (event -> string -> unit) -> float = "caml_dht_periodic"

let init s s6 ~id =
  if String.length id <> 20 then invalid_arg "Dht.init";
  dht_init s s6 id

type dht_event =
  | DHT_EVENT_NONE
  | DHT_EVENT_VALUES
  | DHT_EVENT_VALUES6
  | DHT_SEARCH_DONE
  | DHT_SEARCH_DONE6

let dht_callback ev info_hash clos =
  clos ev info_hash

let periodic pkt cb =
  dht_periodic pkt cb

let () =
  Callback.register "dht_callback" dht_callback
