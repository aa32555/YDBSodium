YottaDB libsodium Plugin
------------------------
This is documentation for using [libsodium](https://doc.libsodium.org/) as a
YottaDB plugin.

The use of libsodium was motivated by the need to provide strong password
hashing in the [YottaDB Web Server](https://gitlab.com/YottaDB/Util/YDB-Web-Server).

The libsodium functionality exposed is limited, and parameters are hardcoded to
reasonable values for a "Desktop" Application with a limited rate of logins
(< 1/second). Aragon2, the algorithm used, is memory limited to disallow
cracking passwords via brute force GPUs. So having multiple logins will result
in running out of memory.

## Installing
First ensure that `libsodium-dev` (Debian, Ubuntu) or `libsodium-devel` (SUSE,
RHEL, Rocky) is installed. You can also install libsodium from source. On
RHEL/Rocky, `libsodium-devel` is available on the
[EPEL](https://docs.fedoraproject.org/en-US/epel/) repository.

After this, from a build directory anywhere on your file system, the install is
a standard `cmake <SOURCE DIR>`, `make`, `make install`. Tests can be run using
either `ctest` or `make test`. For example:

```
$ mkdir /tmp/builds/YDBSodium
$ cd !$
$ cmake /tmp/gitlab/YDBSodium
-- YDBCMake Source Directory: /tmp/builds/YDBSodium/_deps/ydbcmake-src
-- Build type: RelWithDebInfo
-- The C compiler identification is GNU 7.5.0
-- Setting locale to C.utf8
-- Detecting C compiler ABI info
-- Detecting C compiler ABI info - done
-- Check for working C compiler: /usr/bin/cc - skipped
-- Detecting C compile features
-- Detecting C compile features - done
-- Found YOTTADB: /usr/local/lib/yottadb/r138/libyottadb.so
-- Configuring done
-- Generating done
-- Build files have been written to: /tmp/builds/YDBSodium
$ make
[ 50%] Building C object CMakeFiles/sodium.dir/src/sodium_plugin.c.o
[100%] Linking C shared library libsodium.so
[100%] Built target sodium
$ sudo make install
[sudo] password for user:
Consolidate compiler generated dependencies of target sodium
[100%] Built target sodium
Install the project...
-- Install configuration: "RelWithDebInfo"
-- Installing: /usr/local/lib/yottadb/r138/plugin/libsodium.so
-- Installing: /usr/local/lib/yottadb/r138/plugin/sodium.xc
```

## Set-up for Usage
Prior to using the library, the only thing that needs to be done is to set
environment variable `ydb_xc_sodium` to `$ydb_dist/plugin/sodium.xc`. If you
use `ydb_env_set`, it will be set automatically for you.

## Warning on Usage
While the plugin itself does its best to clear plaintext passwords from memory,
YottaDB will retain the password in its heap space. It is therefore
theoretically possible for a user who is able to access process memory to view
plaintext passwords.

## Exposed libsodium API
| YottaDB Call                       | libsodium API            | Output              | Parameter 1            | Parameter 2              |
|------------------------------------|--------------------------|---------------------|------------------------|--------------------------|
| `$&sodium.pwhash(password)`        | `crypto_pwhash_str()`    | output hash         | input password         |                          |
| `$&sodium.pwverify(password,hash)` | `crypto_pwhash_verify()` | 0/-1/-99            | input password         | previously computed hash |
| `$&sodium.randombuf(n)`            | `randombytes_buf()`      | random bytes n long | length of random bytes |                          |

## Usage
Calls return data in the function output. Error mechanisms differ by call, but
`$ZSTATUS` will always return the actual error. The following is the list of
all possible errors:

- `ydbsodium: Failed to initialize libsodium`
- `ydbsodium: Out of memory`
- `ydbsodium: Invalid Parameters passed`

### `pwhash`
If you get back an empty string, you have an error.
```
 set x=$&sodium.pwhash("foo")
 if x="" write $zstatus,! quit
 else  ; do something with x
```

### `pwverify`
If you get back -99, you have an error.
```
 set hash=$sodium.pwhash("foo")
 set verify=$&sodium.pwverify("foo",hash)
 if verify=0 write "correct password",!
 if verify=-1 write "incorrect password",! ; can also happen if you are out of memory... library doesn't tell you which is the cause of the failure
 if verify=-99 write $zstatus,!
```

### `randombuf`
Usage Warning: The data will not be valid UTF-8 data, so be careful in
reading/writing. Also, the data may contain embedded NULLs.

If you get back an empty string, you have an error.
```
 set x=$&sodium.randombuf(10)
 if x="" write $zstatus
 else  zwrite x
```
