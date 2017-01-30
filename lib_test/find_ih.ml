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

let color n oc s =
  if Unix.isatty (Unix.descr_of_out_channel oc) then
    fprintf oc "\x1b[%d;1m%s\x1b[0m" n s
  else
    output_string oc s

let red = color 31

let green = color 32

let yellow = color 33

let magenta = color 35

let cyan = color 36

let logf c s fmt =
  eprintf ("[%a] " ^^ fmt ^^ "\n%!") c s

let errorf fmt =
  logf red "ERROR" fmt

let warnf fmt =
  logf yellow "WARNING" fmt

let infof fmt =
  logf green "INFO" fmt

let hex_of_string s =
  let h = Buffer.create (2 * String.length s) in
  for i = 0 to String.length s - 1 do
    bprintf h "%02x" (int_of_char s.[i]);
  done;
  Buffer.contents h

let short_hex_of_string s =
  String.sub (hex_of_string s) 0 6

let string_of_hex h =
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
      sprintf "%s:%d" (Unix.string_of_inet_addr ip) port

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

let timer () =
  let t0 = Unix.gettimeofday () in
  fun () -> Unix.gettimeofday () -. t0

let buf =
  Bytes.create 4096

let fd =
  let fd = Unix.socket Unix.PF_INET Unix.SOCK_DGRAM 0 in
  Unix.bind fd (Unix.ADDR_INET (Unix.inet_addr_any, !port));
  Dht.init ~ipv4:fd ?ipv6:None id;
  fd

let wait_read sleep =
  let rd, _, ed = Unix.select [fd] [] [fd] sleep in
  if ed <> [] then failwith "Read error";
  if rd <> [] then begin
    let len, sa = Unix.recvfrom fd buf 0 (Bytes.length buf - 1) [] in
    Bytes.set buf len '\000';
    Some (buf, len, sa)
  end else
    None

let search_all l =
  let n = ref (List.length l) in
  let t = timer () in
  let cb ev ih =
    match ev with
    | Dht.EVENT_VALUES addrs ->
        let aux sa =
          logf magenta (sprintf "%.2f" (t ())) "%s: %s"
            (short_hex_of_string ih) (string_of_sockaddr sa)
        in
        List.iter aux addrs
    | Dht.EVENT_SEARCH_DONE ->
        decr n
  in
  let logf fmt = logf red "SEARCH" fmt in
  List.iter (fun ih ->
      Dht.search ih ~port:!port cb;
      logf "START %s" (hex_of_string ih)
    ) l;
  let sleep = ref 0.0 in
  while !n > 0 do
    logf "Waiting... (%.2fs, n=%d)" !sleep !n;
    sleep := Dht.periodic (wait_read !sleep) cb
  done

let ping (name, port) =
  infof "Pinging %s:%d..." name port;
  try
    match Unix.getaddrinfo name (string_of_int port) [] with
    | [] ->
        raise Exit
    | {Unix.ai_addr; _} :: _ ->
        Dht.ping_node ai_addr
  with _ ->
    warnf "Server %s could not be contacted" name

let bootstrap () =
  let logf fmt = logf yellow "BOOTSTRAP" fmt in
  let nodes =
    if Sys.file_exists "dht.dat" then begin
      let ic = open_in_bin "dht.dat" in
      let nodes = Marshal.from_channel ic in
      close_in ic;
      nodes
    end else
      bootstrap_nodes
  in
  List.iter ping nodes;
  let rec loop sleep =
    let {Dht.good; dubious; _} = Dht.nodes Unix.PF_INET in
    let check = good >= 2 && good + dubious >= 10 in
    if not check then begin
      logf "Waiting... (%.2fs, good=%d, dubious=%d)" sleep good dubious;
      loop (Dht.periodic (wait_read sleep) (fun _ _ -> ()))
    end else
      logf "OK"
  in
  loop 0.0

let save () =
  let nodes = Dht.get_nodes ~ipv4:1024 ~ipv6:1024 in
  let oc = open_out_bin "dht.dat" in
  Marshal.to_channel oc nodes [];
  close_out oc

let spec =
  [
    "-p", Arg.Set_int port, " Port to use to communicate";
  ]

let usage_msg =
  sprintf "%s [-v] INFOHASH INFOHASH ..." Sys.executable_name

let tosearch = ref []

let () =
  try
    Arg.parse (Arg.align spec) (fun s -> tosearch := s :: !tosearch) usage_msg;
    bootstrap ();
    search_all (List.map string_of_hex (List.sort_uniq compare !tosearch));
    save ()
  with e ->
    errorf "Fatal: %s" (Printexc.to_string e);
    exit 2
