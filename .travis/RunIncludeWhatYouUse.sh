#!/bin/bash

# Distributed under the MIT License.
# See LICENSE.txt for details.

# A bash array of regular expressions/files not to be check with IWYU.
# Note that IWYU only runs over cpp files so if you encounter a very
# large amount of false suggestions in an hpp you should whitelist
# the associated cpp file AFTER having corrected valid suggestions.
whitelist=("src/Evolution/Systems/GeneralizedHarmonic/Equations.cpp")

# Utility function for checks that returns false if the first argument
# matches any of the shell regexes passed as subsequent arguments.
check_whitelist() {
    local check pattern
    check=$1
    shift
    for pattern in "$@" ; do
        [[ ${check} =~ ${pattern} ]] && return 1
    done
    return 0
}

# Setup lmod and spack to load dependencies
. /etc/profile.d/lmod.sh
export PATH=$PATH:/work/spack/bin
. /work/spack/share/spack/setup-env.sh
spack load benchmark
spack load blaze
spack load brigand
spack load catch
spack load gsl
spack load libxsmm
spack load pkg-config
spack load yaml-cpp

SOURCE_DIR="/work/spectre/"
BUILD_DIR=`pwd`
git clone ${UPSTREAM_REPO} /work/spectre_upstream
cd /work/spectre_upstream
git checkout ${UPSTREAM_BRANCH}
COMMITS_ON_UPSTREAM=`git rev-list HEAD`
cd /work/spectre

# For each upstream commit we check if the commit is on this branch, once we
# find a match we save that hash and exit. This allows us to check only files
# currently being committed.
UPSTREAM_COMMIT_HASH=''

for HASH in ${COMMITS_ON_UPSTREAM}
do
    if git cat-file -e $HASH^{commit} 2> /dev/null
    then
       UPSTREAM_COMMIT_HASH=$HASH
       break
    fi
done

if [ -z $UPSTREAM_COMMIT_HASH ];
then
   echo "The branch is not branched from ${UPSTREAM_REPO}/${UPSTREAM_BRANCH}"
   exit 1
fi

echo "Using upstream commit hash: ${UPSTREAM_COMMIT_HASH}"

###############################################################################
# Get list of non-deleted files
MODIFIED_FILES=()

for FILENAME in `git diff --name-only ${UPSTREAM_COMMIT_HASH} HEAD`
do
    if [ -f $FILENAME ] \
           && [ ${FILENAME: -4} == ".cpp" ] \
           && ! grep -q "FILE_IS_COMPILATION_TEST" $FILENAME \
           && check_whitelist "${FILENAME}" $whitelist; then
        MODIFIED_FILES+=("$SOURCE_DIR$FILENAME")
    fi
done

# Go to build directory and then run iwyu, writing output to file
cd ${BUILD_DIR}
IWYU_OUTPUT="./.iwyu_output"
rm -f ${IWYU_OUTPUT}

if [ ! -z "$MODIFIED_FILES" ]; then
    printf "Invoking IWYU as:\n \
iwyu_tool.py -j 2 -p . $MODIFIED_FILES -- --mapping_file=$SOURCE_DIR/tools/Iwyu/iwyu.imp\n"

    # We loop over two files at a time since we can run IWYU
    # in parallel and TravisCI has 2 cores.
    for (( i=0; i<${#MODIFIED_FILES[@]} ; i+=2 )) ; do
        # need to output something so TravisCI knows we're not stalled
        printf '.'
        iwyu_tool.py -p . ${MODIFIED_FILES[i]} ${MODIFIED_FILES[i+1]} \
                     -- --mapping_file=${SOURCE_DIR}/tools/Iwyu/iwyu.imp \
                     >> ${IWYU_OUTPUT} 2>&1
    done
    echo ''

    if [ -f "${IWYU_OUTPUT}" ] \
           && ( grep 'should add these lines:' ${IWYU_OUTPUT} > /dev/null ||
                    grep 'error:' ${IWYU_OUTPUT} > /dev/null )
    then
        printf "\nIWYU found problems!\n\
 #     # ####### ####### #######  #\n\
 ##    # #     #    #    #       ###\n\
 # #   # #     #    #    #        #\n\
 #  #  # #     #    #    #####\n\
 #   # # #     #    #    #        #\n\
 #    ## #     #    #    #       ###\n\
 #     # #######    #    #######  #\n\
IWYU is still not yet fully mature and  provides incorrect suggestions\n\
sometimes. Known problematic cases are:\n\
- Removing headers required for explicit instantiations. Consider a function\n\
  that takes an Index<Dim> as its only argument. You can instantiate it for\n\
  various dimensions, say up to Dim=4, quite easily in a cpp file. Thus, the\n\
  header only has a forward declaration and the function definition and\n\
  instantiations are in the cpp file. IWYU will tell you that you do not\n\
  need to include DataStructures/Index.hpp in the cpp file, which is\n\
  incorrect. You can tell IWYU that it is wrong and you must include the\n\
  header file by including it as:\n
  #include \"DataStructures/Index.hpp\"  // IWYU pragma: keep\n\
- Class template declarations with default template parameters are not\n\
  handled correctly. See issue #530 on IWYU GitHub. Specifically, say you\n\
  have a header TagsDeclarations.hpp that declares\n\
  'template <size_t Dim, class Frame = Frame::Inertial> MyTag;' and another\n\
  header file Tags.hpp that defines the class. Then it suffices and is\n\
  optimal to include TagsDeclarations.hpp in other header files that do not\n\
  need the definition of the Tags. However, IWYU will tell you to provide the\n\
  forward declaration with the defaulted template parameters in the header\n\
  file that you'd include TagsDeclarations.hpp in. This means you are\n\
  including the default template parameters in more than one place, which is\n'
  not allowed.\n\
  There are two ways to deal with this issue:\n\
  - Use // IWYU pragma: no_forward_declare MyTag\n\
  - Have the associated cpp file to not be checked by TravisCI by adding it\n\
    to the whitelist in $SPECTRE_HOME/.travis/RunIncludeWhatYouUse.sh AFTER\n\
    having corrected all valid suggestions. You can run IWYU from the Docker\n\
    container to test locally.\n\
IWYU Output:\n"
        more ${IWYU_OUTPUT}
        exit 1
    fi
fi

exit 0
