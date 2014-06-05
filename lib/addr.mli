(* Copyright (C) 2014  Nicolas Ojeda Bar <n.oje.bar@gmail.com>

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

module Ip : sig
  type t

  val any : t
  val loopback : t
  val of_string : string -> t
  val of_string_noblock : string -> t Lwt.t
  val to_string : t -> string
  val of_ints : int -> int -> int -> int -> t
  val to_ints : t -> int * int * int * int
  val of_string_compact : Bitstring.bitstring -> t
end

type t = Ip.t * int

val port : t -> int
  
val ip : t -> Ip.t

val to_string : t -> string
  
val to_string_compact : t -> string

val to_sockaddr : t -> Unix.sockaddr

val of_sockaddr : Unix.sockaddr -> t

val of_string_compact : Bitstring.bitstring -> t

module Set : Set.S with type elt = t
