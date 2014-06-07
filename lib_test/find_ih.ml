(* The MIT License (MIT)

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
