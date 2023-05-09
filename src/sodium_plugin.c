/*###############################################################
#								#
# Copyright (c) 2023 YottaDB LLC and/or its subsidiaries.	#
# All rights reserved.						#
#								#
#	This source code contains the intellectual property	#
#	of its copyright holder(s), and is made available	#
#	under a license.  If you do not know the terms of	#
#	the license, please stop and do not read further.	#
#								#
###############################################################*/
#include <sodium.h>
#include <string.h>
#include "libyottadb.h"

#define YDBSODIUM_ZSTATUS "$ZSTATUS"
#define YDBSODIUM_EINIT   "ydbsodium: Failed to initialize libsodium"
#define YDBSODIUM_OOM     "ydbsodium: Out of memory"
#define YDBSODIUM_INVPARM "ydbsodium: Invalid Parameters passed"

// C99 Structure Initializer
#define YDBBUFF_HDR_INIT(NAME, VALUE)          \
	ydb_buffer_t NAME = {                  \
		.buf_addr = VALUE,             \
		.len_used = sizeof(VALUE) - 1, \
		.len_alloc = sizeof(VALUE) - 1 \
	}

// Create AND initialize global variables of type ydb_buffer_t to mirror the three error messages
YDBBUFF_HDR_INIT(ydbsodium_zstatus, YDBSODIUM_ZSTATUS);
YDBBUFF_HDR_INIT(ydbsodium_einit,   YDBSODIUM_EINIT);
YDBBUFF_HDR_INIT(ydbsodium_oom,     YDBSODIUM_OOM);
YDBBUFF_HDR_INIT(ydbsodium_invparm, YDBSODIUM_INVPARM);

// NB: Throughout, we don't check the error status for ydb_set_s, which sets $ZSTATUS, as we are handling
// errors when we are using it. If we can't succeed, there is nothing that can be done.

// https://doc.libsodium.org/password_hashing/default_phf
//
// Usage:
//	```
// 	set x=$&sodium.pwhash("foo")
// 	if x="" write $zstatus,! quit
// 	else  ; do something with x
// 	```
ydb_char_t* sodium_crypto_pwhash_str(int argc, ydb_string_t* input) {
	char *hashed_password;

	// Check arguments
	if (1 != argc) {
		ydb_set_s(&ydbsodium_zstatus, 0, NULL, &ydbsodium_invparm);
		return NULL;
	}
	
	// Make sure something is passed (not possible in YottaDB, but we are just being safe)
	if (NULL == input) {
		ydb_set_s(&ydbsodium_zstatus, 0, NULL, &ydbsodium_invparm);
		return NULL;
	}

	// Initialize libsodium
	if (0 > sodium_init()) {
		/* panic! the library couldn't be initialized; it is not safe to use */
		ydb_set_s(&ydbsodium_zstatus, 0, NULL, &ydbsodium_einit);
		return NULL;
	}

	// Malloc
	hashed_password = ydb_malloc(crypto_pwhash_STRBYTES);
	if (NULL == hashed_password){
		ydb_set_s(&ydbsodium_zstatus, 0, NULL, &ydbsodium_oom);
		return NULL;
	}

	// Hash
	if (0 != crypto_pwhash_str(hashed_password, input->address, input->length,
	  		          crypto_pwhash_OPSLIMIT_MODERATE, crypto_pwhash_MEMLIMIT_MODERATE)) {
		ydb_set_s(&ydbsodium_zstatus, 0, NULL, &ydbsodium_oom);
	}

	return hashed_password;
}

// https://doc.libsodium.org/password_hashing/default_phf
// Usage:
// 	set hash=$sodium.pwhash("foo")
// 	set verify=$&sodium.pwverify("foo",hash)
// 	if verify=0 write "correct password",!
// 	if verify=-1 write "incorrect password",!
// 	if verify=-99 write $zstatus,!
ydb_int_t sodium_crypto_pwhash_verify(int argc, ydb_string_t* password, ydb_char_t* hashed_password) {
	ydb_int_t status;

	if (2 != argc) {
		ydb_set_s(&ydbsodium_zstatus, 0, NULL, &ydbsodium_invparm);
		return -99;
	}

	// Make sure something is passed (not possible in YottaDB, but we are just being safe)
	if (NULL == password || NULL == hashed_password) {
		ydb_set_s(&ydbsodium_zstatus, 0, NULL, &ydbsodium_invparm);
		return -99;
	}

	if (0 > sodium_init()) {
		/* panic! the library couldn't be initialized; it is not safe to use */
		ydb_set_s(&ydbsodium_zstatus, 0, NULL, &ydbsodium_einit);
		return -99;
	}

	status = crypto_pwhash_str_verify(hashed_password, password->address, password->length);
	return status;
}

// https://doc.libsodium.org/generating_random_data
// Usage:
// 	set x=$&sodium.randombuf(10)
// 	if x="" write $zstatus
// 	else  zwrite x
//
// Usage Warning: The data will not be valid UTF-8 data, so be careful in reading/writing
//                Also, the data may contain embedded NULLs
ydb_string_t* sodium_randombytes_buf(int argc, const size_t size) {
	char		*random_data;
	ydb_string_t 	*return_structure;

	if (1 != argc) {
		ydb_set_s(&ydbsodium_zstatus, 0, NULL, &ydbsodium_invparm);
		return NULL;
	}

	// Mallocs (two, one for the string structure, one for char*)
	return_structure = ydb_malloc(sizeof(ydb_string_t));
	random_data      = ydb_malloc(size);
	if ((NULL == return_structure) || (NULL == random_data)) {
		ydb_set_s(&ydbsodium_zstatus, 0, NULL, &ydbsodium_oom);
		return NULL;
	}

	randombytes_buf(random_data, size);

	return_structure->length = (ydb_long_t)size;
	return_structure->address = random_data;

	return return_structure;
}
