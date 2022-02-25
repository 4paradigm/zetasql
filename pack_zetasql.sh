#!/bin/bash

# install zetasql compiled header files and libs

set -eE

#===  FUNCTION  ================================================================
#         NAME:  usage
#  DESCRIPTION:  Display usage information.
#===============================================================================
function usage ()
{
    echo "Usage :  $0 [options] [--]

    Options:
    -h       Display this message
    -d       Linux distribution name, e.g centos, ubuntu, default empty
    -i       Request install to given directory after pack"

}    # ----------  end of function usage  ----------

#-----------------------------------------------------------------------
#  Handle command line arguments
#-----------------------------------------------------------------------

INSTALL_DIR=
# linux distribution name
DISTRO=

while getopts ":hi:d:" opt
do
  case $opt in

    h )  usage; exit 0   ;;

    d ) DISTRO=$OPTARG ;;

    i )
      INSTALL_DIR=$OPTARG
      mkdir -p "$INSTALL_DIR"
      INSTALL_DIR=$(cd "$INSTALL_DIR" 2>/dev/null && pwd)
      ;;

    * )  echo -e "\n  Option does not exist : OPTARG\n"
                usage; exit 1   ;;

  esac    # --- end of case ---
done
shift $((OPTIND-1))

pushd "$(dirname "$0")"
pushd "$(git rev-parse --show-toplevel)"

VERSION=${TAG:-$(git rev-parse --short HEAD)}
ROOT=$(pwd)
export ROOT
export ZETASQL_LIB_NAME="libzetasql-$VERSION"
export PREFIX="$ROOT/${ZETASQL_LIB_NAME}"

# different module of zetasql build different library, we first find all need libraries and copy
# them into tmp-lib(this don't include thirdparty libraries), then repack into single archive
rm -rf tmp-lib libzetasql.mri "${PREFIX}"
mkdir -p tmp-lib
mkdir -p "${PREFIX}"
mkdir -p "${PREFIX}"/lib

install_lib() {
    local file
    file=$1
    local libname
    libname=lib$(echo "$file" | tr '/' '_' | sed -e 's/lib//')

    if [[ "$OSTYPE" == "linux-gnu"* ]]
    then
        INSTALL_BIN="install"
    else
        INSTALL_BIN="ginstall"
    fi
    ${INSTALL_BIN} -D "$file" "$ROOT/tmp-lib/$libname"
}

install_gen_include_file() {
    local file
    file=$1
    local outfile
    outfile=$(echo "$file" | sed -e 's/^.*proto\///')

    if [[ "$OSTYPE" == "linux-gnu"* ]]
    then
        INSTALL_BIN="install"
    else
        INSTALL_BIN="ginstall"
    fi
    ${INSTALL_BIN} -D "$file" "$PREFIX/include/$outfile"
}

install_external_lib() {
    local file
    file=$1
    local libname
    libname=$(basename "$file")
    if [[ "$OSTYPE" == "linux-gnu"* ]]
    then
        INSTALL_BIN="install"
    else
        INSTALL_BIN="ginstall"
    fi
    ${INSTALL_BIN} -D "$file" "$PREFIX/lib/$libname"
}

export -f install_gen_include_file
export -f install_lib
export -f install_external_lib


if [[ "$OSTYPE" == "linux-gnu"* ]]
then
    INSTALL_BIN="install"
else
    INSTALL_BIN="ginstall"
fi

pushd bazel-bin/
find zetasql -type f -iname '*.a' -exec bash -c 'install_lib $0' {} \;

# external lib headers
pushd "$(realpath .)/../../../../../external/com_googlesource_code_re2"
find re2 -iname "*.h" -exec ${INSTALL_BIN} -D {} "$PREFIX"/include/{} \;
popd

pushd "$(realpath .)/../../../../../external/com_googleapis_googleapis"
find google -iname "*.h" -exec ${INSTALL_BIN} -D {} "$PREFIX"/include/{} \;
popd

pushd "$(realpath .)/../../../../../external/com_google_file_based_test_driver"
find file_based_test_driver -iname "*.h" -exec ${INSTALL_BIN} -D {} "$PREFIX"/include/{} \;
popd

# external lib
pushd external

find icu -type f -iname '*.a' -exec bash -c 'install_external_lib $0' {} \;
find com_googlesource_code_re2 -type f -iname '*.a' -exec bash -c 'install_external_lib $0' {} \;
find com_googleapis_googleapis -type f -iname '*.a' -exec bash -c 'install_external_lib $0' {} \;
find com_google_file_based_test_driver -type f -iname '*.a' -exec bash -c 'install_external_lib $0' {} \;

popd

# zetasql generated files: protobuf & template generated files
find zetasql -type f -iname "*.h" -exec ${INSTALL_BIN} -D {} "$PREFIX"/include/{} \;
find zetasql -iregex ".*/_virtual_includes/.*\.h\$" -exec bash -c 'install_gen_include_file $0' {} \;
popd # bazel-bin

# header files from source
find zetasql -type f -iname "*.h" -exec ${INSTALL_BIN} -D {} "$PREFIX"/include/{} \;


if [[ "$OSTYPE" == "linux-gnu"* ]]
then
    echo 'create libzetasql.a' >> libzetasql.mri
    find tmp-lib/ -iname "*.a" -type f -exec bash -c 'echo "addlib $0" >> libzetasql.mri' {} \;
    echo "save" >> libzetasql.mri
    echo "end" >> libzetasql.mri

    ar -M <libzetasql.mri
    ranlib libzetasql.a
    mv libzetasql.a "$PREFIX/lib/"
else
    libtool -static -o libzetasql.a tmp-lib/*.a
    mv libzetasql.a "$PREFIX/lib"
fi

if [[ $OSTYPE = 'darwin'* ]]; then
    OUT_FILE="${ZETASQL_LIB_NAME}-darwin-$(uname -m).tar.gz"
else
    OUT_FILE="${ZETASQL_LIB_NAME}-$OSTYPE-$(uname -m)-$DISTRO.tar.gz"
fi
tar czf "$OUT_FILE" "$ZETASQL_LIB_NAME"/

if [ -n "$INSTALL_DIR" ] ; then
    tar xzf "$OUT_FILE" -C "$INSTALL_DIR" --strip-components=1
fi

popd
popd
