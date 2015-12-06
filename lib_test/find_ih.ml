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

let id =
  let s = Bytes.make 20 in
  for i = 0 to 19 do
    Bytes.set s i (Char.of_int (Random.int 256))
  done;
  Bytes.unsafe_to_string s

open Lwt.Infix

let string_of_sockaddr = function
  | Unix.ADDR_UNIX s ->
      s
  | Unix.ADDR_INET (ip, port) ->
      Printf.sprintf "%s:%d" (Unix.string_of_inet_addr ip) port

let () =
  let s = Lwt_unix.socket Unix.PF_INET Unix.SOCK_DGRAM 0 in
  let s6 = Lwt_unix.socket Unix.PF_INET6 Unix.SOCK_DGRAM 0 in
  Lwt_unix.bind s (Unix.ADDR_INET (Unix.inet_addr_any, 4567));
  Lwt_unix.bind s6 (Unix.ADDR_INET (Unix.inet_addr_any, 4568));
  Dht.init (Lwt_unix.unix_file_descr s) (Lwt_unix.unix_file_descr s6) ~id;
  let buf = Bytes.create 4096 in
  let cb ev ~id =
    match ev with
    | Dht.EVENT_VALUES addrs ->
        List.iter (fun addr ->
            Printf.printf "Found address: %s\n%!" (string_of_sockaddr addr)
          ) addrs
    | Dht.EVENT_SEARCH_DONE ->
        Printf.printf "Search done.\n%!"
  in
  let rec loop sleep =
    Lwt.pick
      [
        (Lwt_unix.sleep sleep >>= fun () -> Lwt.return `Timeout);
        (Lwt_unix.wait_read s >>= fun () -> Lwt.return (`Read s));
        (Lwt_unix.wait_read s6 >>= fun () -> Lwt.return (`Read s6));
      ]
    >>= function
    | `Timeout ->
        Dht.periodic None cb >>=
        loop
    | `Read fd ->
        Lwt_unix.recvfrom fd buf 0 (Bytes.length buf) [] >>= fun (len, sa) ->
        Dht.periodic (Some (buf, len, sa)) cb >>=
        loop
  in
  loop 0.0
