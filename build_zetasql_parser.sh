#!/bin/bash

# build zetasql parser into static library
# Copyright 2021 4Paradigm
#
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
#
#     http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.
#

set -eE

pushd "$(dirname "$0")"
pushd "$(git rev-parse --show-toplevel)"

echo "build with python: $(python -V), python3: $(python3 -V)"

#===  FUNCTION  ================================================================
#         NAME:  usage
#  DESCRIPTION:  Display usage information.
#===============================================================================
function usage ()
{
    echo "Usage :  $0 [options] [--]

    Options:
    -c            Build profile. static|release|release-static, default static
    -h|help       Display this message"

}    # ----------  end of function usage  ----------

#-----------------------------------------------------------------------
#  Handle command line arguments
#-----------------------------------------------------------------------

# NOTE: default to static profile: compile all as archive but not define `NDEBUG`
# since pre-compiled lib may used in Release/Debug profile in OpenMLDB
#
# acceptable values:
# - release: `-O2 -DNDEBUG`, shared libs
# - static:  static libs
# - release-static: `-O2 -DNDEBUG`, static libs
PROFILE=static
ACCEPT_PROFILES=(static release release-static)

while getopts ":hc:" opt
do
  case $opt in

    c ) PROFILE=$OPTARG ;;

    h|help     )  usage; exit 0   ;;

    * )  echo -e "\n  Option does not exist : $OPTARG\n"
          usage; exit 1   ;;

  esac    # --- end of case ---
done
shift $((OPTIND-1))

if [[ ! " ${ACCEPT_PROFILES[*]} " =~ " ${PROFILE} " ]] ; then
    echo "profile named $PROFILE not found in accept profile list: ${ACCEPT_PROFILES[*]}"
    exit 1
fi

TARGET='//zetasql/parser/...'
BUILD_ARGV=(--config="$PROFILE")

bazel build "$TARGET" "${BUILD_ARGV[@]}"
bazel test "$TARGET" "${BUILD_ARGV[@]}"

# explicitly build dependencies into static library
# bazel clean
bazel query "deps(//zetasql/parser:parser)" | grep //zetasql | xargs bazel build "${BUILD_ARGV[@]}"
bazel build "@com_googleapis_googleapis//:all" "${BUILD_ARGV[@]}"
bazel query "@com_google_file_based_test_driver//..." | xargs bazel build "${BUILD_ARGV[@]}"
bazel build "@com_googlesource_code_re2//:re2" "${BUILD_ARGV[@]}"

popd
popd
