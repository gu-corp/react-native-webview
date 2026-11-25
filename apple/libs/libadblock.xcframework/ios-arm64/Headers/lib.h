/* Copyright (c) 2019 The Brave Authors. All rights reserved.
 * This Source Code Form is subject to the terms of the Mozilla Public
 * License, v. 2.0. If a copy of the MPL was not distributed with this file,
 * You can obtain one at http://mozilla.org/MPL/2.0/. */

/* C interface of src/lib.rs. Keep the two in sync; see lib.rs for details. */

#ifndef BRAVE_COMPONENTS_ADBLOCK_RUST_FFI_SRC_LIB_H_
#define BRAVE_COMPONENTS_ADBLOCK_RUST_FFI_SRC_LIB_H_

#include <stdbool.h>
#include <stddef.h>
#include <stdint.h>

#ifdef __cplusplus
extern "C" {
#endif

/* Opaque engine handle. */
typedef struct C_Engine C_Engine;

/* Creates an engine from a filter list in ABP / uBlock Origin syntax. Never
 * returns null. Free with engine_destroy. */
C_Engine *engine_create(const char *rules);

void engine_destroy(C_Engine *engine);

/* Checks a network request. The did_match_* flags are inputs and outputs and
 * are only ever set; did_match_rule means "block". redirect and rewritten_url
 * receive strings to free with c_char_buffer_destroy, or null; either may be
 * null. */
void engine_match(C_Engine *engine,
                  const char *url,
                  const char *host,
                  const char *tab_host,
                  bool third_party,
                  const char *resource_type,
                  bool *did_match_rule,
                  bool *did_match_exception,
                  bool *did_match_important,
                  char **redirect,
                  char **rewritten_url);

/* Loads redirect and scriptlet resources (Brave's resources.json format).
 * Returns false if the JSON could not be parsed. */
bool engine_use_resources(C_Engine *engine, const char *resources);

/* Cosmetic resources for a page, as JSON. Free with c_char_buffer_destroy. */
char *engine_url_cosmetic_resources(C_Engine *engine, const char *url);

/* Generic hide selectors for the given classes and ids, as a JSON array. Free
 * with c_char_buffer_destroy. */
char *engine_hidden_class_id_selectors(C_Engine *engine,
                                       const char *const *classes,
                                       size_t classes_size,
                                       const char *const *ids,
                                       size_t ids_size,
                                       const char *const *exceptions,
                                       size_t exceptions_size);

void c_char_buffer_destroy(char *s);

#ifdef __cplusplus
}  /* extern "C" */
#endif

#endif  /* BRAVE_COMPONENTS_ADBLOCK_RUST_FFI_SRC_LIB_H_ */
