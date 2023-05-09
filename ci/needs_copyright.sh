#!/bin/sh
#################################################################
#								#
# Copyright (c) 2023 YottaDB LLC and/or its subsidiaries.	#
# All rights reserved.						#
#								#
#	This source code contains the intellectual property	#
#	of its copyright holder(s), and is made available	#
#	under a license.  If you do not know the terms of	#
#	the license, please stop and do not read further.	#
#								#
#################################################################

set -eu

if ! [ $# = 1 ]; then
	echo "usage: $0 <filename>"
	exit 2
fi

file="$1"

# Don't require deleted files to have a copyright
if ! [ -e "$file" ]; then
       exit 1
fi

skipextensions=""	# List of extensions that cannot have copyrights.
if echo "$skipextensions" | grep -q -w "$(echo "$file" | awk -F . '{print $NF}')"; then
	exit 1
fi

# Determines whether a file should need a copyright by its name
# Returns 0 if it needs a copyright and 1 otherwise.
skiplist="LICENSE
	README.md
	src/_ut.m
	src/_ut1.m
	"
    for skipfile in $skiplist; do
	if [ "$file" = "$skipfile" ]; then
		exit 1
	fi
done
