/* Copyright (C) 2015-2017 Nicolas Ojeda Bar <n.oje.bar@gmail.com>

   This file is part of ocaml-libutp.

   This library is free software; you can redistribute it and/or modify it under
   the terms of the GNU Lesser General Public License as published by the Free
   Software Foundation; either version 2.1 of the License, or (at your option)
   any later version.

   This library is distributed in the hope that it will be useful, but WITHOUT
   ANY WARRANTY; without even the implied warranty of MERCHANTABILITY or FITNESS
   FOR A PARTICULAR PURPOSE.  See the GNU Lesser General Public License for more
   details.

   You should have received a copy of the GNU Lesser General Public License
   along with this library; if not, write to the Free Software Foundation, Inc.,
   51 Franklin Street, Fifth Floor, Boston, MA 02110-1301 USA */

#include <assert.h>
#include <string.h>
#include <stdio.h>
#include <errno.h>
#include <unistd.h>
#include <fcntl.h>

#include <caml/memory.h>
#include <caml/mlvalues.h>
#include <caml/alloc.h>
#include <caml/callback.h>
#include <caml/bigarray.h>
#include <caml/fail.h>
#include <caml/socketaddr.h>

#include "dht.h"

CAMLprim void caml_dht_callback (void *closure, int event, const unsigned char *info_hash, const void *data, size_t data_len)
{
  CAMLparam0 ();
  CAMLlocal5 (ev, ih, lst, cons, addr);
  union sock_addr_union from;
  const unsigned char *p = data;

  lst = Val_emptylist;

  switch (event) {
    case DHT_EVENT_VALUES:
      ev = caml_alloc (1, 0);
      for (int i = data_len - 6; i >= 0; i -= 6) {
        from.s_gen.sa_family = AF_INET;
        memcpy (&from.s_inet.sin_addr, p + i, 4);
        from.s_inet.sin_port = *(unsigned short *) (p + i + 4);
        addr = alloc_sockaddr (&from, sizeof (from.s_inet), 0);
        cons = caml_alloc (2, 0);
        Store_field (cons, 0, addr);
        Store_field (cons, 1, lst);
        lst = cons;
      }
      Store_field (ev, 0, lst);
      break;
    case DHT_EVENT_VALUES6:
      ev = caml_alloc (1, 0);
      for (int i = data_len - 18; i >= 0; i -= 18) {
        from.s_gen.sa_family = AF_INET6;
        memcpy (&from.s_inet6.sin6_addr, data + i, 16);
        from.s_inet6.sin6_port = *(unsigned short *) (data + i + 16);
        addr = alloc_sockaddr (&from, sizeof (from.s_inet6), 0);
        cons = caml_alloc (2, 0);
        Store_field (cons, 0, addr);
        Store_field (cons, 1, lst);
        lst = cons;
      }
      Store_field (ev, 0, lst);
      break;
    case DHT_EVENT_SEARCH_DONE:
    case DHT_EVENT_SEARCH_DONE6:
      ev = Val_int (0);
      break;
    default:
      CAMLreturn0;
  }

  ih = caml_alloc_string (20);
  memcpy (String_val(ih), info_hash, 20);

  caml_callback2 (*(value *)closure, ev, ih);

  CAMLreturn0;
}

CAMLprim value caml_dht_init (value ipv4, value ipv6, value id)
{
  CAMLparam3 (ipv4, ipv6, id);
  int res, s, s6;

  if (ipv4 == Val_int (0)) {
    s = -1;
  } else {
    s = Int_val (Field (ipv4, 0));
  }

  if (ipv6 == Val_int (0)) {
    s6 = -1;
  } else {
    s6 = Int_val (Field (ipv6, 0));
  }

  res = dht_init (s, s6, (unsigned char *) String_val (id), NULL);

  /* dht_debug = stderr; */

  if (res < 0) {
    caml_failwith ("dht_init");
  }

  CAMLreturn (Val_unit);
}

CAMLprim value caml_dht_insert_node (value id, value addr)
{
  CAMLparam2 (id, addr);
  union sock_addr_union sa;
  socklen_param_type salen;

  get_sockaddr (addr, &sa, &salen);
  dht_insert_node ((unsigned char *) String_val (id), &sa.s_gen, salen);

  CAMLreturn (Val_unit);
}

CAMLprim value caml_dht_ping_node (value addr)
{
  CAMLparam1 (addr);
  union sock_addr_union sa;
  socklen_param_type salen;
  int res;

  get_sockaddr (addr, &sa, &salen);
  res = dht_ping_node (&sa.s_gen, salen);

  if (res < 0) {
    caml_failwith ("dht_ping_node");
  }

  CAMLreturn (Val_unit);
}

CAMLprim value caml_dht_periodic (value pkt_opt, value closure)
{
  CAMLparam2 (pkt_opt, closure);
  CAMLlocal4 (pkt, buf, buflen, addr);
  time_t tosleep;
  union sock_addr_union from;
  socklen_param_type fromlen;
  int res;
  value *root = malloc (sizeof (closure));
  *root = closure;
  caml_register_generational_global_root (root);

  if (pkt_opt == Val_int(0)) {
    res = dht_periodic (NULL, 0, NULL, 0, &tosleep, &caml_dht_callback, root);
  } else {
    pkt = Field (pkt_opt, 0);
    buf = Field (pkt, 0);
    buflen = Field (pkt, 1);
    addr = Field (pkt, 2);
    get_sockaddr (addr, &from, &fromlen);
    res = dht_periodic (String_val(buf), Int_val(buflen), &from.s_gen, fromlen, &tosleep, &caml_dht_callback, root);
  }

  caml_remove_generational_global_root (root);
  free (root);

  if (res < 0) {
    caml_failwith ("dht_periodic");
  }

  CAMLreturn (caml_copy_double ((double) tosleep));
}

CAMLprim value caml_dht_search (value id, value port, value dom, value closure)
{
  CAMLparam4 (id, port, dom, closure);
  int res, af;
  value *root;

  switch (Int_val(dom)) {
    case 0:
      af = AF_UNIX;
      break;
    case 1:
      af = AF_INET;
      break;
    case 2:
      af = AF_INET6;
      break;
    default:
      caml_invalid_argument("dht_search");
      break;
  }

  root = malloc (sizeof (value));
  *root = closure;
  caml_register_generational_global_root (root);
  res = dht_search ((unsigned char *) String_val (id), Int_val (port), af, &caml_dht_callback, root);
  caml_remove_generational_global_root (root);
  free (root);
  
  if (res < 0) {
    caml_failwith ("dht_search");
  }

  CAMLreturn (Val_unit);
}

CAMLprim value caml_dht_get_nodes (value num, value num6)
{
  CAMLparam2 (num, num6);
  CAMLlocal3 (lst, sa, cons);
  union sock_addr_union adr [num];
  union sock_addr_union adr6 [num6];
  int res, n, n6;

  lst = Val_emptylist;
  n = Int_val (num);
  n6 = Int_val (num6);

  res = dht_get_nodes (&adr[0].s_inet, &n, &adr6[0].s_inet6, &n6);

  if (res < 0) {
    caml_failwith ("dht_get_nodes");
  }

  for (int i = 0; i < n; i ++) {
    sa = alloc_sockaddr (&adr[i], sizeof (adr[i].s_inet), 0);
    cons = caml_alloc (2, 0);
    Store_field (cons, 0, sa);
    Store_field (cons, 1, lst);
    lst = cons;
  }

  for (int i = 0; i < n6; i ++) {
    sa = alloc_sockaddr (&adr6[i], sizeof (adr6[i].s_inet6), 0);
    cons = caml_alloc (2, 0);
    Store_field (cons, 0, sa);
    Store_field (cons, 1, lst);
    lst = cons;
  }

  CAMLreturn (lst);
}

CAMLprim value caml_dht_nodes (value sdom)
{
  CAMLparam1 (sdom);
  CAMLlocal1 (nodes);
  int af, good, dubious, cached, incoming;

  switch (Int_val (sdom)) {
    case 0:
      af = AF_UNIX;
      break;
    case 1:
      af = AF_INET;
      break;
    case 2:
      af = AF_INET6;
      break;
    default:
      caml_invalid_argument ("caml_dht_nodes");
  }

  dht_nodes (af, &good, &dubious, &cached, &incoming);

  nodes = caml_alloc (4, 0);
  Store_field (nodes, 0, Val_int(good));
  Store_field (nodes, 1, Val_int(dubious));
  Store_field (nodes, 2, Val_int(cached));
  Store_field (nodes, 3, Val_int(incoming));

  CAMLreturn (nodes);
}

/* Functions called by the DHT. */
int dht_blacklisted (const struct sockaddr *sa, int salen)
{
  return 0;
}

void dht_hash(void *hash_return, int hash_size, const void *v1, int len1, const void *v2, int len2, const void *v3, int len3)
{
  CAMLparam0 ();
  CAMLlocal2 (w, r);

  w = caml_alloc_string (len1 + len2 + len3);

  memcpy (String_val (w), v1, len1);
  memcpy (String_val (w) + len1, v2, len2);
  memcpy (String_val (w) + len1 + len2, v3, len3);

  r = caml_callback (*caml_named_value ("dht_hash"), w);

  if (hash_size > 16)
    memset ((char *) hash_return + 16, 0, hash_size - 16);

  memcpy (hash_return, String_val (r), hash_size > 16 ? 16 : hash_size);

  CAMLreturn0;
}

int dht_random_bytes (void *buf, size_t size)
{
  CAMLparam0 ();
  CAMLlocal1 (ba);
  ba = caml_ba_alloc_dims (CAML_BA_UINT8 | CAML_BA_C_LAYOUT, 1, buf, size);
  caml_callback (*caml_named_value ("dht_random_bytes"), ba);
  CAMLreturn (Val_int(size));
}
