/* Copyright (C) 2015 Nicolas Ojeda Bar <n.oje.bar@gmail.com>

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

static void
caml_dht_callback(void *closure, int event,
             const unsigned char *info_hash,
             const void *data, size_t data_len)
{
  value clos = (value)closure;
  CAMLparam1(clos);
  CAMLlocal5(ev, ih, lst, cons, addr);

  union sock_addr_union from;

  lst = Val_emptylist;

  switch(event) {
  case DHT_EVENT_VALUES:
    ev = caml_alloc(1, 0);
    for (int i = data_len; i - 6 >= 0; i -= 6) {
      from.s_gen.sa_family = AF_INET;
      memcpy(&from.s_inet.sin_addr, data + i, 4);
      from.s_inet.sin_port = *(unsigned short *)(data + i + 4);
      addr = alloc_sockaddr(&from, sizeof(from.s_inet), 0);
      cons = caml_alloc(2, 0);
      Store_field(cons, 0, addr);
      Store_field(cons, 1, lst);
      lst = cons;
    }
    Store_field(ev, 0, lst);
    break;
  case DHT_EVENT_VALUES6:
    ev = caml_alloc(1, 0);
    for (int i = data_len; i - 18 >= 0; i -= 18) {
      from.s_gen.sa_family = AF_INET6;
      memcpy(&from.s_inet6.sin6_addr, data + i, 16);
      from.s_inet6.sin6_port = *(unsigned short *)(data + i + 16);
      addr = alloc_sockaddr(&from, sizeof(from.s_inet6), 0);
      cons = caml_alloc(2, 0);
      Store_field(cons, 0, addr);
      Store_field(cons, 1, lst);
      lst = cons;
    }
    Store_field(ev, 0, lst);
    break;
  case DHT_EVENT_SEARCH_DONE:
  case DHT_EVENT_SEARCH_DONE6:
    ev = Val_int(0);
    break;
  default:
    CAMLreturn0;
  }

  ih = caml_alloc_string(20);
  memcpy(String_val(ih), info_hash, 20);

  caml_callback3(*caml_named_value("dht_callback"), ev, ih, (value)closure);

  CAMLreturn0;
}

CAMLprim value
caml_dht_init(value s, value s6, value id)
{
  int res;

  res = dht_init(Int_val(s), Int_val(s6), (unsigned char *) String_val(id), NULL);

  if (res < 0) {
    caml_failwith("dht_init");
  }

  return Val_unit;
}

CAMLprim value
caml_dht_insert_node(value id, value addr)
{
  union sock_addr_union sa;
  socklen_param_type salen;

  get_sockaddr(addr, &sa, &salen);
  dht_insert_node((unsigned char *) String_val(id), &sa.s_gen, salen);

  return Val_unit;
}

CAMLprim value
caml_dht_ping_node(value addr)
{
  union sock_addr_union sa;
  socklen_param_type salen;
  int res;

  get_sockaddr(addr, &sa, &salen);
  res = dht_ping_node(&sa.s_gen, salen);

  if (res < 0) {
    caml_failwith("dht_ping_node");
  }

  return Val_unit;
}

CAMLprim value
caml_dht_periodic(value pkt_opt, value closure)
{
  CAMLparam2(pkt_opt, closure);
  CAMLlocal4(pkt, buf, buflen, addr);

  time_t tosleep;
  union sock_addr_union from;
  socklen_param_type fromlen;

  int res;

  if (pkt_opt == Val_int(0)) {
    res = dht_periodic(NULL, 0, NULL, 0, &tosleep, &caml_dht_callback, (void *) closure);
  } else {
    pkt = Field(pkt_opt, 0);
    buf = Field(pkt, 0);
    buflen = Field(pkt, 1);
    addr = Field(pkt, 2);
    get_sockaddr(addr, &from, &fromlen);
    res = dht_periodic(String_val(buf), Int_val(buflen), &from.s_gen, fromlen,
                       &tosleep, &caml_dht_callback, (void *) closure);
  }

  if (res < 0) {
    caml_failwith("dht_periodic");
  }

  CAMLreturn(caml_copy_double((double)tosleep));
}

CAMLprim value
caml_dht_search(value id, value port, value dom, value closure)
{
  CAMLparam2(id, closure);
  int res;
  int af;

  switch(Int_val(dom)) {
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
    caml_failwith("dht_search");
    break;
  }

  res = dht_search((unsigned char *) String_val(id), Int_val(port), af, &caml_dht_callback, (void *)closure);

  if (res < 0) {
    caml_failwith("dht_search");
  }

  CAMLreturn(Val_unit);
}


/* Functions called by the DHT. */

int
dht_blacklisted(const struct sockaddr *sa, int salen)
{
    return 0;
}

/* But for this example, we might as well use something weaker. */
void
dht_hash(void *hash_return, int hash_size,
         const void *v1, int len1,
         const void *v2, int len2,
         const void *v3, int len3)
{
    const char *c1 = v1, *c2 = v2, *c3 = v3;
    char key[9];                /* crypt is limited to 8 characters */
    int i;

    memset(key, 0, 9);
#define CRYPT_HAPPY(c) ((c % 0x60) + 0x20)

    for(i = 0; i < 2 && i < len1; i++)
        key[i] = CRYPT_HAPPY(c1[i]);
    for(i = 0; i < 4 && i < len1; i++)
        key[2 + i] = CRYPT_HAPPY(c2[i]);
    for(i = 0; i < 2 && i < len1; i++)
        key[6 + i] = CRYPT_HAPPY(c3[i]);
    strncpy(hash_return, crypt(key, "jc"), hash_size);
}

int
dht_random_bytes(void *buf, size_t size)
{
    int fd, rc, save;

    fd = open("/dev/urandom", O_RDONLY);
    if(fd < 0)
        return -1;

    rc = read(fd, buf, size);

    save = errno;
    close(fd);
    errno = save;

    return rc;
}
