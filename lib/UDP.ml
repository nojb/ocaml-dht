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
