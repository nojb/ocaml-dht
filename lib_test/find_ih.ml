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

module Dht_lwt (I : sig val id : string end) : sig
  val bootstrap : unit -> unit Lwt.t
  val search : ?port:int -> ?af:Unix.socket_domain -> string -> Unix.sockaddr Lwt_stream.t
  (* val save : Lwt_io.output_channel -> unit Lwt.t *)
  (* val restore : Lwt_io.input_channel -> unit Lwt.t *)
end = struct
  let searches = Hashtbl.create 0
  let inited = ref false

  (* let save oc = *)
  (*   prerr_endline "Saving dht info...\n%!"; *)
  (*   let info = {id = !id; good_nodes = Dht.get_nodes 20 20} in *)
  (*   Marshal.to_channel (open_out ".dht_info") info [] *)

  (* let restore ic = *)
  (*   prerr_endline "Restore dht info...\n"; *)
  (*   let info : restore_info = Marshal.from_channel (open_in ".dht_info") in *)
  (*   List.iter (fun sa -> Dht.ping_node sa) info.good_nodes *)

  let the_cb ev ~id =
    let strm, push = Hashtbl.find searches id in
    match ev with
    | Dht.EVENT_VALUES addrs ->
        Printf.eprintf "\nReceived %d peers for %s\n%!" (List.length addrs) (hex_of_string id);
        List.iter (fun addr -> push (Some addr)) addrs
    | Dht.EVENT_SEARCH_DONE ->
        Printf.eprintf "\nSearching for %s done.\n%!" (hex_of_string id);
        Hashtbl.remove searches id;
        push None

  let the_loop s s6 =
    let buf = Bytes.create 4096 in
    let rec loop sleep =
      Lwt.pick
        [
          (Lwt_unix.sleep sleep >>= fun () -> Lwt.return `Timeout);
          (Lwt_unix.wait_read s >>= fun () -> Lwt.return (`Read s));
          (Lwt_unix.wait_read s6 >>= fun () -> Lwt.return (`Read s6));
        ]
      >>= function
      | `Timeout ->
          Lwt.wrap2 Dht.periodic None the_cb >>=
          loop
      | `Read fd ->
          Lwt_unix.recvfrom fd buf 0 (Bytes.length buf - 1) [] >>= fun (len, sa) ->
          Bytes.set buf len '\000';
          Lwt.wrap2 Dht.periodic (Some (buf, len, sa)) the_cb >>=
          loop
    in
    loop 0.0

  let bootstrap_nodes =
    [
      "dht.transmissionbt.com", 6881;
      "router.utorrent.com", 6881;
    ]

  let rec init () =
    if not !inited then begin
      inited := true;
      prerr_endline "Initializing...";
      let s = Lwt_unix.socket Unix.PF_INET Unix.SOCK_DGRAM 0 in
      let s6 = Lwt_unix.socket Unix.PF_INET6 Unix.SOCK_DGRAM 0 in
      Lwt_unix.bind s (Unix.ADDR_INET (Unix.inet_addr_any, 4567));
      Lwt_unix.bind s6 (Unix.ADDR_INET (Unix.inet6_addr_any, 4568));
      Lwt.async (fun () -> the_loop s s6);
      Dht.init ~ipv4:(Lwt_unix.unix_file_descr s) ~ipv6:(Lwt_unix.unix_file_descr s6) ~id:I.id
    end

  and bootstrap () =
    init ();
    prerr_endline "Bootstrapping...";
    let working, finished = Lwt.wait () in
    let rec loop () =
      let nodes = Dht.nodes Unix.PF_INET in
      if nodes.Dht.good >= 1 then begin
        prerr_endline "Bootstrap done!";
        Lwt.wrap2 Lwt.wakeup finished ()
      end else begin
        let nodes = Dht.nodes Unix.PF_INET in
        Printf.ksprintf prerr_endline "Waiting for bootstrap (good=%d, good+dubious=%d)"
          nodes.Dht.good (nodes.Dht.good + nodes.Dht.dubious);
        Lwt_unix.sleep 1.0 >>= loop
      end
    in
    let (_ : _ Lwt_stream.t) = search I.id in
    Lwt.async (fun () ->
        Lwt_list.iter_p (fun (name, port) ->
            Lwt_unix.gethostbyname name >>= fun he ->
            if Array.length he.Unix.h_addr_list > 0 then begin
              Printf.eprintf "Bootstrap: pinging %s...\n%!" name;
              Lwt.wrap1 Dht.ping_node (Unix.ADDR_INET (he.Unix.h_addr_list.(0), port))
            end else begin
              Printf.eprintf "Bootstrap: node %s not found\n%!" name;
              Lwt.return_unit
            end
          ) bootstrap_nodes >>= loop
      );
    working

  and search ?port ?af id =
    init ();
    Printf.eprintf "Searching for %s..." (hex_of_string id);
    try
      fst (Hashtbl.find searches id)
    with Not_found ->
      let strm, push = Lwt_stream.create () in
      Hashtbl.add searches id (strm, push);
      Dht.search ~id ?port ?af the_cb;
      strm
end

let genid () =
  let s = Bytes.create 20 in
  for i = 0 to 19 do
    Bytes.set s i (char_of_int (Random.int 256))
  done;
  Bytes.unsafe_to_string s

(* let id = genid () *)

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
  let module D = Dht_lwt (struct let id = genid () end) in
  D.bootstrap () >>= fun () ->
  let strm = D.search info_hash in
  let i = ref 0 in
  Lwt_stream.iter (fun addr ->
      incr i;
      if !i mod 5 = 0 then prerr_newline ();
      Printf.eprintf "%23s " (string_of_sockaddr addr)
    ) strm

let () =
  Lwt_main.run (main (string_of_hex Sys.argv.(1)))
