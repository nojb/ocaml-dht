(* The MIT License (MIT)

   Copyright (c) 2015-2017 Nicolas Ojeda Bar <n.oje.bar@gmail.com>

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

open Printf

let hex_of_string s =
  let h = Buffer.create (2 * String.length s) in
  for i = 0 to String.length s - 1 do
    Printf.bprintf h "%02x" (int_of_char s.[i]);
  done;
  Buffer.contents h

let string_of_hex h =
  eprintf "string_of_hex: %s (len=%d)\n%!" h (String.length h);
  if String.length h mod 2 <> 0 then invalid_arg "string_of_hex";
  let s = Bytes.create (String.length h / 2) in
  let c = Bytes.create 2 in
  for i = 0 to String.length h / 2 - 1 do
    Bytes.set c 0 h.[2*i];
    Bytes.set c 1 h.[2*i+1];
    Bytes.set s i (Scanf.sscanf (Bytes.unsafe_to_string c) "%x" char_of_int)
  done;
  Bytes.unsafe_to_string s

let string_of_sockaddr = function
  | Unix.ADDR_UNIX s ->
      s
  | Unix.ADDR_INET (ip, port) ->
      Printf.sprintf "%s:%d" (Unix.string_of_inet_addr ip) port

let id =
  let s = Bytes.create 20 in
  for i = 0 to 19 do
    Bytes.set s i (char_of_int (Random.int 256))
  done;
  Bytes.unsafe_to_string s

let port =
  ref 4567

let bootstrap_nodes =
  [
    "dht.transmissionbt.com", 6881;
    "router.utorrent.com", 6881;
  ]

let buf =
  Bytes.create 4096

let fd =
  let fd = Unix.socket Unix.PF_INET Unix.SOCK_DGRAM 0 in
  Unix.bind fd (Unix.ADDR_INET (Unix.inet_addr_any, !port));
  Dht.init ~ipv4:fd ?ipv6:None id;
  fd

let wait_read sleep =
  let rd, _, ed = Unix.select [fd] [] [fd] sleep in
  if ed <> [] then failwith "I/O Error";
  if rd <> [] then begin
    let len, sa = Unix.recvfrom fd buf 0 (Bytes.length buf - 1) [] in
    Printf.eprintf "Received packet\n%!";
    Bytes.set buf len '\000';
    Some (buf, len, sa)
  end else
    None

let search id cb =
  ksprintf print_endline "Searching for %s..." (hex_of_string id);
  let finished = ref false in
  let cb ev id =
    match ev with
    | Dht.EVENT_VALUES addrs ->
        ksprintf print_endline "Received %d peers for %s"
          (List.length addrs) (hex_of_string id);
        List.iter cb addrs
    | Dht.EVENT_SEARCH_DONE ->
        ksprintf print_endline "Searching for %s done"
          (hex_of_string id);
        finished := true
  in
  Dht.search id ~port:!port cb;
  let sleep = ref 0.0 in
  while not !finished do
    sleep := Dht.periodic (wait_read !sleep) cb
  done

let ping (name, port) =
  let he = Unix.gethostbyname name in
  if Array.length he.Unix.h_addr_list > 0 then begin
    ksprintf print_endline "Bootstrap: pinging %s..." name;
    Dht.ping_node (Unix.ADDR_INET (he.Unix.h_addr_list.(0), port))
  end else
    ksprintf print_endline "Bootstrap: node %s not found" name

let check_bootstrapped () =
  let {Dht.good; dubious; _} = Dht.nodes Unix.PF_INET in
  ksprintf print_endline "Waiting: good: %d dubious: %d" good dubious;
  good >= 2 && good + dubious >= 10

let bootstrap () =
  printf "Bootstrapping... %s\n" (hex_of_string id);
  List.iter ping bootstrap_nodes;
  let sleep = ref 0.0 in
  while not (check_bootstrapped ()) do
    sleep := Dht.periodic (wait_read !sleep) (fun _ _ -> ())
  done;
  printf "Bootstrapped!\n%!"

let print_result id sa =
  ksprintf print_endline "Retrieved %s for %s" (string_of_sockaddr sa) (hex_of_string id)

let main ih =
  bootstrap ();
  search ih (print_result ih)

let () =
  try
    main (string_of_hex Sys.argv.(1))
  with e ->
    eprintf ">> Fatal error: %s\n%!" (Printexc.to_string e);
    exit 2
