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

FROM yottadb/yottadb-base:latest-master

ARG DEBIAN_FRONTEND=noninteractive
RUN apt-get update && apt-get install -y git make cmake pkg-config gcc libsodium-dev libicu70 libicu-dev

# Download YDBCMake
RUN git clone https://gitlab.com/YottaDB/Tools/YDBCMake.git

# Install libsodium
COPY src/ src/
COPY CMakeLists.txt .
RUN mkdir build && cd build && cmake -D FETCHCONTENT_SOURCE_DIR_YDBCMAKE=../YDBCMake .. && make
WORKDIR /data/build

ENTRYPOINT ["ctest", "--verbose"]
