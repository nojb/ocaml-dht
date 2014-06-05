(* Copyright (C) 2001-2014 ygrek, mldonkey

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
