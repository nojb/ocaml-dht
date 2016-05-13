(* The MIT License (MIT)

   Copyright (c) 2015 Nicolas Ojeda Bar <n.oje.bar@gmail.com>

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

let hex_of_string s =
  let h = Buffer.create (2 * String.length s) in
  for i = 0 to String.length s - 1 do
    Printf.bprintf h "%02x" (int_of_char s.[i]);
  done;
  Buffer.contents h

let string_of_hex h =
  Printf.eprintf "string_of_hex: %S, len=%d\n%!" h (String.length h);
  if String.length h mod 2 <> 0 then invalid_arg "string_of_hex";
  let s = Bytes.create (String.length h / 2) in
  let c = Bytes.create 2 in
  for i = 0 to String.length h / 2 - 1 do
    Bytes.set c 0 h.[2*i];
    Bytes.set c 1 h.[2*i+1];
    Bytes.set s i (Scanf.sscanf (Bytes.unsafe_to_string c) "%x" char_of_int)
  done;
  Bytes.unsafe_to_string s

open Lwt.Infix

let pr fmt =
  Printf.ksprintf prerr_endline fmt

module Dht_lwt : sig
  type t
  val create: ?port:int -> string -> t
  val search: t -> string -> Unix.sockaddr Lwt_stream.t
end = struct
  type t =
    {
      id: string;
      port: int;
      fd: Lwt_unix.file_descr;
      searches: (string, Unix.sockaddr Lwt_stream.t * (Unix.sockaddr option -> unit)) Hashtbl.t;
      ready: unit Lwt.t;
    }

  let on_progress {searches; _} ev ~id =
    let _, push = Hashtbl.find searches id in
    match ev with
    | Dht.EVENT_VALUES addrs ->
        pr "Received %d peers for %s" (List.length addrs) (hex_of_string id);
        List.iter (fun addr -> push (Some addr)) addrs
    | Dht.EVENT_SEARCH_DONE ->
        pr "Searching for %s done." (hex_of_string id);
        Hashtbl.remove searches id;
        push None

  let the_loop t =
    let buf = Bytes.create 4096 in
    let rec loop sleep =
      Lwt.pick
        [
          (Lwt_unix.sleep sleep >>= fun () -> Lwt.return `Timeout);
          (Lwt_unix.wait_read t.fd >>= fun () -> Lwt.return (`Read t.fd));
        ]
      >>= function
      | `Timeout ->
          pr "Timeout";
          Lwt.wrap2 Dht.periodic None (on_progress t) >>= loop
      | `Read fd ->
          Lwt_unix.recvfrom fd buf 0 (Bytes.length buf - 1) [] >>= fun (len, sa) ->
          Bytes.set buf len '\000';
          Lwt.wrap2 Dht.periodic (Some (buf, len, sa)) (on_progress t) >>= loop
    in
    loop 0.0

  let search t id =
    pr "Searching for %s..." (hex_of_string id);
    let {port; searches; _} = t in
    match Hashtbl.find searches id with
    | strm, _ -> strm
    | exception Not_found ->
        let strm, push = Lwt_stream.create () in
        Hashtbl.add searches id (strm, push);
        let _ = t.ready >|= fun () -> Dht.search ~id ~port (on_progress t) in
        strm

  let bootstrap_nodes =
    [
      "dht.transmissionbt.com", 6881;
      "router.utorrent.com", 6881;
    ]

  let bootstrap t =
    pr "Bootstrapping... %s" (hex_of_string t.id);
    let query (name, port) =
      Lwt_unix.gethostbyname name >>= fun he ->
      if Array.length he.Unix.h_addr_list > 0 then begin
        pr "Bootstrap: pinging %s..." name;
        Lwt.wrap1 Dht.ping_node (Unix.ADDR_INET (he.Unix.h_addr_list.(0), port))
      end else begin
        pr "Bootstrap: node %s not found" name;
        Lwt.return_unit
      end
    in
    let rec wait () =
      let {Dht.good; dubious; _} = Dht.nodes Unix.PF_INET in
      pr "Waiting: good: %d dubious: %d" good dubious;
      if good >= 2 && good + dubious >= 10 then begin
        pr "Bootstrap done!";
        Lwt.return_unit
      end else begin
        Lwt_unix.sleep 1.0 >>= wait
      end
    in
    Lwt_list.iter_p query bootstrap_nodes >>= fun () ->
    let strm = search t t.id in
    Lwt.choose [Lwt_stream.junk_while (fun _ -> true) strm; wait ()]

  let create ?(port = 4567) id =
    let fd = Lwt_unix.socket Unix.PF_INET Unix.SOCK_DGRAM 0 in
    Lwt_unix.bind fd (Unix.ADDR_INET (Unix.inet_addr_any, port));
    let ready, w = Lwt.wait () in
    let t = {id; port; fd; searches = Hashtbl.create 0; ready} in
    Lwt.async (fun () -> the_loop t);
    Dht.init ~ipv4:(Lwt_unix.unix_file_descr fd) ?ipv6:None ~id;
    let _ = bootstrap t >|= Lwt.wakeup w in
    t
end

let genid () =
  let s = Bytes.create 20 in
  for i = 0 to 19 do
    Bytes.set s i (char_of_int (Random.int 256))
  done;
  Bytes.unsafe_to_string s

let string_of_sockaddr = function
  | Unix.ADDR_UNIX s ->
      s
  | Unix.ADDR_INET (ip, port) ->
      Printf.sprintf "%s:%d" (Unix.string_of_inet_addr ip) port

type restore_info =
  {
    id : string;
    good_nodes : Unix.sockaddr list;
  }

let main info_hash =
  let id = genid () in
  let dht = Dht_lwt.create id in
  let strm = Dht_lwt.search dht info_hash in
  Lwt_stream.iter (fun addr -> pr "%s" (string_of_sockaddr addr)) strm

let () =
  Lwt_main.run (main (string_of_hex Sys.argv.(1)))
