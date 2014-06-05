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

type socket

val create_socket : ?port:int -> unit -> socket
  
val send : socket -> string -> Addr.t -> unit Lwt.t
val send_bitstring : socket -> Bitstring.bitstring -> Addr.t -> unit Lwt.t
val recv : socket -> (string * Addr.t) Lwt.t
val set_timeout : socket -> float -> unit
val close : socket -> unit Lwt.t
