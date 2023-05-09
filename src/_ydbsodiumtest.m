%ydbsodiumtest ; YDB to libsodium Tests
 ;
 ; We run this test twice, once with unlimited memory and once with ulimit -v 32000
 ;#################################################################
 ;#								#
 ;# Copyright (c) 2023 YottaDB LLC and/or its subsidiaries.	#
 ;# All rights reserved.					#
 ;#								#
 ;#	This source code contains the intellectual property	#
 ;#	of its copyright holder(s), and is made available	#
 ;#	under a license.  If you do not know the terms of	#
 ;#	the license, please stop and do not read further.	#
 ;#								#
 ;#################################################################
 ;
test if $text(^%ut)="" quit
 do en^%ut($t(+0),3)
 quit
 ;
STARTUP ;
 open "p":(shell="/bin/bash":command="ulimit -v")::"pipe"
 use "p"
 read vmem
 close "p"
 quit
 ;
SHUTDOWN ;
 kill vmem
 quit
 ;
pwhash ; @TEST test password hashing
 if vmem="unlimited" do
 . do tf^%ut($&sodium.pwhash("foo")["$argon2id")
 . do eq^%ut($zstatus,"")
 . do tf^%ut($&sodium.pwhash("")["$argon2id")
 . do eq^%ut($zstatus,"")
 else  do
 . do eq^%ut($&sodium.pwhash("foo"),"")
 . do eq^%ut($zstatus,"ydbsodium: Out of memory")
 . set $zstatus=""
 . do eq^%ut($&sodium.pwhash(""),"")
 . do eq^%ut($zstatus,"ydbsodium: Out of memory")
 . set $zstatus=""
 ;
 ; No arguments
 do eq^%ut($&sodium.pwhash(),"")
 do eq^%ut($zstatus,"ydbsodium: Invalid Parameters passed")
 set $zstatus=""
 quit
 ;
pwverify ; @TEST test password verify
 ; A possible hash for foo
 new hash set hash="$argon2id$v=19$m=1048576,t=4,p=1$pgCAkFWpUpVTRNsMDrY5sg$4FvCuBxtvdwzdfvnMehFRcA7HEYJE6E4NghYwhsANZ4"
 if vmem="unlimited" do
 . new v  set v=$&sodium.pwverify("foo",hash)
 . do eq^%ut(v,0)
 . do eq^%ut($zstatus,"")
 . kill v set v=$&sodium.pwverify("boo",hash)
 . do eq^%ut(v,-1)
 . do eq^%ut($zstatus,"")
 else  do
 . ; libsodium API does not tell us why a verify failed.
 . ; In this case, the verify fails due to limited memory
 . ; That's why we don't return an error message in $zstatus
 . new v set v=$&sodium.pwverify("foo",hash)
 . do eq^%ut(v,-1)
 . do eq^%ut($zstatus,"")
 ;
 do eq^%ut($&sodium.pwverify(),-99)
 do eq^%ut($zstatus,"ydbsodium: Invalid Parameters passed")
 set $zstatus=""
 do eq^%ut($&sodium.pwverify("foo"),-99)
 do eq^%ut($zstatus,"ydbsodium: Invalid Parameters passed")
 set $zstatus=""
 quit
 ;
zero ; @TEST test password hash/verify with embedded zeros
 set $zstatus=""
 if vmem'="unlimited" quit
 new pw1 set pw1=$char(0)_"q"
 new pw2 set pw2=$char(0)_"r"
 new hash1 set hash1=$&sodium.pwhash(pw1)
 new hash2 set hash2=$&sodium.pwhash(pw2)
 do eq^%ut($&sodium.pwverify(pw1,hash1),0,1)
 do eq^%ut($zstatus,"")
 do eq^%ut($&sodium.pwverify(pw2,hash2),0,2)
 do eq^%ut($zstatus,"")
 do eq^%ut($&sodium.pwverify(pw1,hash2),-1,3)
 do eq^%ut($zstatus,"")
 do eq^%ut($&sodium.pwverify(pw2,hash1),-1,4)
 do eq^%ut($zstatus,"")
 quit
 ;
randombuf ; @TEST test random data
 new r set r=$&sodium.randombuf(10)
 do eq^%ut($zlength(r),10)
 do eq^%ut($zstatus,"")
 ;
 do eq^%ut($&sodium.randombuf(),"")
 do eq^%ut($zstatus,"ydbsodium: Invalid Parameters passed")
 set $zstatus=""
 quit
 ;
integtest ; @TEST Integration test
 if vmem'="unlimited" quit
 new i,len,password,password2,hash,verify
 for i=1:1:10 do
 . set len=$random(2**(1+$random(20)))
 . write "--> Testing string of length ",len,!
 . set password=$&sodium.randombuf(len)
 . do eq^%ut($zlength(password),len,1)
 . do eq^%ut($zstatus,"",$zstatus)
 . ;
 . set hash=$&sodium.pwhash(password)
 . do tf^%ut(hash["$argon2id",hash)
 . do eq^%ut($zstatus,"",$zstatus)
 . set verify=$&sodium.pwverify(password,hash)
 . do eq^%ut(verify,0)
 . new replacechar set replacechar="b"
 . if $extract(password,len)="b" set replacechar="c"
 . set password2=$extract(password,1,len-1)_replacechar
 . set verify=$&sodium.pwverify(password2,hash)
 . do eq^%ut(verify,-1)
 quit
