(* Copyright (C) 2001-2013  Nicolas Ojeda Bar <n.oje.bar@gmail.com>

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

let (>>=) = Lwt.(>>=)
    
let num_target = 50
let dht_port = 4567
  
let main _ =
  if Array.length Sys.argv <> 2 then begin
    Printf.printf "Usage: %s <info-hash>\n%!" Sys.argv.(0);
    exit 2
  end;
  let ih = SHA1.of_hex Sys.argv.(1) in
  let dht = DHT.create dht_port in
  DHT.start dht;
  Printf.printf "=========================== DHT\n";
  Printf.printf "Note that there are many bad nodes that reply to anything you ask.\n";
  Printf.printf "Peers found:\n";
  let count = ref 0 in
  let handle_peers _ token peers =
    List.iter (fun addr ->
      incr count;
      Printf.printf "%d: %s\n%!" !count (Addr.to_string addr)
      (* if !count >= num_target then DHT.stop dht *)) peers
  in
  let rec loop () =
    DHT.query_peers dht ih handle_peers >>= fun () ->
    Lwt_unix.sleep 5.0 >>=
    loop
  in
  Lwt_main.run (DHT.auto_bootstrap dht DHT.bootstrap_nodes >>= loop)

let _ =
  main ()
