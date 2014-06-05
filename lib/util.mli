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

val shuffle_array : 'a array -> unit
(** shuffles an array randomly. *)
  
val array_exists : ('a -> bool) -> 'a array -> bool
(** [array_exists f a] returns [true] if [f a.(i)] is true for some [i],
    otherwise it returns [false]. *)
