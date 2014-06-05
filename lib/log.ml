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

let active = ref true

let render template ?exn msg =
  let now = Unix.gettimeofday () in
  let msecs, now = modf now in
  let tm = Unix.localtime now in
  let b = Buffer.create 10 in
  Buffer.add_substitute b begin
    function
    | "message" ->
      msg
    | "date" ->
      Printf.sprintf "%04d-%02d-%02d"
        (tm.Unix.tm_year+1900) (tm.Unix.tm_mon+1) tm.Unix.tm_mday
    | "time" ->
      Printf.sprintf "%02d:%02d:%02d.%03d"
        tm.Unix.tm_hour tm.Unix.tm_min tm.Unix.tm_sec (truncate (msecs *. 1000.0))
    | "exn" ->
      begin match exn with
      | None -> ""
      | Some exn -> ": " ^ Printexc.to_string exn
      end
    | _ ->
      ""
  end template;
  Buffer.contents b

let lprintlf ?exn fmt =
  let template = "[$(date) $(time)] $(message)$(exn)" in
  Printf.ksprintf
    (fun msg -> if !active then prerr_endline (render template ?exn msg))
    fmt
