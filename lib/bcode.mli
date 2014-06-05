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

type t =
  | Int of int64
  | String of string
  | List of t list
  | Dict of (string * t) list

val find : string -> t -> t
val to_list : t -> t list
val to_int64 : t -> int64
val to_int : t -> int
val to_string : t -> string
val to_dict : t -> (string * t) list

val decode : string -> t
val decode_partial : string -> t * int
val encode : t -> string

(* val from_file : string -> t *)
(* val from_string : string -> t *)

val sprint : t -> string
