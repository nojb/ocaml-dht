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

(** KRPC protocol.  This is used to send bencoded messages over UDP. There is no
    retry in case of error.  *)

(** The type of possible messages. *)
type msg =
  | Query of string * (string * Bcode.t) list
  | Response of (string * Bcode.t) list
  | Error of int64 * string

(** The type of possible responses to queries. *)
type rpc =
  | Error
  | Timeout
  | Response of Addr.t * (string * Bcode.t) list

type t
(** The type of KRPC peer. *)

type answer_func = Addr.t -> string -> (string * Bcode.t) list -> msg

val create : answer_func -> int -> t
(** Create a new KRPC server on the given port.  The first argument is the
    function used to reply to incoming queries. *)

val start : t -> unit
(** Start the server loop. *)

val string_of_msg : msg -> string
(** A string describing the given message. *)

val send_msg : t -> msg -> Addr.t -> rpc Lwt.t
(** Send a KRPC message to the given address and return the response (or an
    error, see {!rpc}). *)
