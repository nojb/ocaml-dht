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
  let s = Bytes.create 20 in
  for i = 0 to 19 do
    Bytes.set s i (char_of_int (Random.int 256))
  done;
  Bytes.unsafe_to_string s

open Lwt.Infix

let string_of_sockaddr = function
  | Unix.ADDR_UNIX s ->
      s
  | Unix.ADDR_INET (ip, port) ->
      Printf.sprintf "%s:%d" (Unix.string_of_inet_addr ip) port

let main info_hash =
  let s = Lwt_unix.socket Unix.PF_INET Unix.SOCK_DGRAM 0 in
  let s6 = Lwt_unix.socket Unix.PF_INET6 Unix.SOCK_DGRAM 0 in
  Lwt_unix.bind s (Unix.ADDR_INET (Unix.inet_addr_any, 4567));
  Lwt_unix.bind s6 (Unix.ADDR_INET (Unix.inet_addr_any, 4568));
  Dht.init (Lwt_unix.unix_file_descr s) (Lwt_unix.unix_file_descr s6) ~id;
  let buf = Bytes.create 4096 in
  let finished = ref false in
  let cb ev ~id =
    match ev with
    | Dht.EVENT_VALUES addrs ->
        List.iter (fun addr ->
            Printf.printf "Found address: %s\n%!" (string_of_sockaddr addr)
          ) addrs
    | Dht.EVENT_SEARCH_DONE ->
        Printf.printf "Search done.\n%!";
        finished := true
  in
  let rec loop sleep =
    if not !finished then
      Lwt.pick
        [
          (Lwt_unix.sleep sleep >>= fun () -> Lwt.return `Timeout);
          (Lwt_unix.wait_read s >>= fun () -> Lwt.return (`Read s));
          (Lwt_unix.wait_read s6 >>= fun () -> Lwt.return (`Read s6));
        ]
      >>= function
      | `Timeout ->
          Lwt.wrap2 Dht.periodic None cb >>=
          loop
      | `Read fd ->
          Lwt_unix.recvfrom fd buf 0 (Bytes.length buf) [] >>= fun (len, sa) ->
          Lwt.wrap2 Dht.periodic (Some (buf, len, sa)) cb >>=
          loop
    else
      Lwt.return_unit
  in
  Dht.search ~id ~port:4567 Unix.PF_INET cb;
  loop 0.0

let invalid_arg fmt =
  Printf.ksprintf (fun str -> raise (Invalid_argument str)) fmt

let hexa = "0123456789abcdef"
and hexa1 =
  "0000000000000000111111111111111122222222222222223333333333333333\
   4444444444444444555555555555555566666666666666667777777777777777\
   88888888888888889999999999999999aaaaaaaaaaaaaaaabbbbbbbbbbbbbbbb\
   ccccccccccccccccddddddddddddddddeeeeeeeeeeeeeeeeffffffffffffffff"
and hexa2 =
  "0123456789abcdef0123456789abcdef0123456789abcdef0123456789abcdef\
   0123456789abcdef0123456789abcdef0123456789abcdef0123456789abcdef\
   0123456789abcdef0123456789abcdef0123456789abcdef0123456789abcdef\
   0123456789abcdef0123456789abcdef0123456789abcdef0123456789abcdef"

let of_char c =
  let x = Char.code c in
  hexa.[x lsr 4], hexa.[x land 0xf]

let to_char x y =
  let code c = match c with
    | '0'..'9' -> Char.code c - 48 (* Char.code '0' *)
    | 'A'..'F' -> Char.code c - 55 (* Char.code 'A' + 10 *)
    | 'a'..'f' -> Char.code c - 87 (* Char.code 'a' + 10 *)
    | _ -> invalid_arg "Hex.to_char: %d is an invalid char" (Char.code c)
  in
  Char.chr (code x lsl 4 + code y)

let to_string (`Hex (s : string)) =
  if s = "" then ""
  else
    let n = String.length s in
    let buf = Bytes.create (n/2) in
    let rec aux i j =
      if i >= n then ()
      else if j >= n then invalid_arg "hex conversion: invalid hex string"
      else (
        Bytes.set buf (i/2) (to_char s.[i] s.[j]);
        aux (j+1) (j+2)
      )
    in
    aux 0 1;
    Bytes.unsafe_to_string buf

let () =
  Lwt_main.run (main (to_string (`Hex Sys.argv.(1))))
