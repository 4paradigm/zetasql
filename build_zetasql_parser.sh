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

if grep -q centos /etc/os-release ; then
    # for thoese using rhel devtoolset
    export BAZEL_LINKOPTS='-static-libstdc++:-lm'
    export BAZEL_LINKLIBS='-l%:libstdc++.a'
fi

if [[ $(arch) = 'aarch64' ]]; then
    git checkout .
    # need upgrade abseil and bazel to compile on aarch64
    git apply --verbose aarch64.patch
fi

echo "build with python: $(python -V), python3: $(python3 -V)"

TARGET='//zetasql/parser/...'
BUILD_ARGV=(--features=-supports_dynamic_linker --sandbox_debug)

bazel build "$TARGET" "${BUILD_ARGV[@]}"
bazel test "$TARGET" "${BUILD_ARGV[@]}"

# explicitly build dependencies into static library
bazel clean
bazel query "deps(//zetasql/parser:parser)" | grep //zetasql | xargs bazel build "${BUILD_ARGV[@]}"
bazel build "@com_googleapis_googleapis//:all" "${BUILD_ARGV[@]}"
bazel query "@com_google_file_based_test_driver//..." | xargs bazel build "${BUILD_ARGV[@]}"
bazel build "@com_googlesource_code_re2//:re2" "${BUILD_ARGV[@]}"

unset BAZEL_LINKLIBS
unset BAZEL_LINKOPTS

popd
popd
