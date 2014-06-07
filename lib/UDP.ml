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

let debug ?exn fmt = Log.lprintlf ?exn ("UDP: " ^^ fmt)

let max_udp_packet_size = 4096

type socket = {
  fd : Lwt_unix.file_descr;
  buf : string
}

let (>>=) = Lwt.(>>=)
let (>|=) = Lwt.(>|=)
    
let create_socket ?(port = 0) () =
  let fd = Lwt_unix.socket Unix.PF_INET Unix.SOCK_DGRAM 0 in
  Lwt_unix.bind fd (Unix.ADDR_INET (Unix.inet_addr_any, port));
  { fd; buf = String.create max_udp_packet_size }

let write sock s pos len addr =
  Lwt_unix.sendto sock.fd s pos len [] (Addr.to_sockaddr addr) >|= fun n ->
  if n < len then debug "write: sent %d bytes, should have sent %d" n len

let send sock s addr =
  write sock s 0 (String.length s) addr

let send_bitstring sock (s, off, len) addr =
  assert (off land 7 = 0 && len land 7 = 0);
  write sock s (off lsr 3) (len lsr 3) addr

let recv sock =
  Lwt_unix.recvfrom sock.fd sock.buf 0 (String.length sock.buf) [] >|= fun (n, iaddr) ->
  String.sub sock.buf 0 n, Addr.of_sockaddr iaddr

let set_timeout sock t =
  Lwt_unix.setsockopt_float sock.fd Lwt_unix.SO_RCVTIMEO t

let close sock =
  Lwt_unix.close sock.fd
