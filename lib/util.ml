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

(** based on
 * http://stackoverflow.com/questions/3758606/how-to-convert-byte-size-into-human-readable-format-in-java *)
let string_of_file_size (b : int64) : string =
  let step = 1024.0 in
  let round d = floor (d +. 0.5) in
  let b' = Int64.to_float b in
  if b' < step then Printf.sprintf "%Ld B" b
  else
    let exp = int_of_float (log b' /. log step) in
    let b'' = round (10.0 *. b' /. step ** (float exp)) /. 10.0 in
    Printf.sprintf "%g %ciB" b'' ("KMGTPE".[exp-1])
(*     Printf.sprintf "%.1f %ciB" *)
(*       (b' /. step ** (float exp)) ("KMGTPE".[exp-1]) *)

let string_of_sockaddr = function
  | Unix.ADDR_INET (a, p) -> Printf.sprintf "%s:%u" (Unix.string_of_inet_addr a) p
  | Unix.ADDR_UNIX s -> s

let shuffle_array a =
  for i = Array.length a - 1 downto 1 do
    let j = Random.int (i+1) in
    let t = a.(i) in
    a.(i) <- a.(j);
    a.(j) <- t
  done

let array_exists f a =
  let rec loop i =
    if i >= Array.length a then false else
    if f a.(i) then true
    else loop (i+1)
  in
  loop 0

let safe_int64_to_int n =
  let m = Int64.to_int n in
  assert (Int64.(compare (of_int m) n) = 0);
  m
