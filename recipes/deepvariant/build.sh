#!/bin/bash
set -eu -o pipefail

# ## Binary install with wrappers

SHAREDIR="share/$PKG_NAME-$PKG_VERSION-$PKG_BUILDNUM"
TGT="$PREFIX/$SHAREDIR"
[ -d "$TGT" ] || mkdir -p "$TGT"
[ -d "${PREFIX}/bin" ] || mkdir -p "${PREFIX}/bin"

# mv binaries $TGT
# mv models $TGT
# 
# cd $PREFIX
# BINARY_DIR=`ls -d $SHAREDIR/binaries/DeepVariant/*/DeepVariant*`
# WGS_MODEL_DIR=`ls -d $SHAREDIR/models/DeepVariant/*/DeepVariant*wgs_standard`
# WES_MODEL_DIR=`ls -d $SHAREDIR/models/DeepVariant/*/DeepVariant*wes_standard`
# cd $SRC_DIR
# 
# # models installed in post-link script
# rm -rf $TGT/models
# 
# # Fix hardcoded python inside binary directories
# for ZIPBIN in make_examples call_variants postprocess_variants
# do
# 	unzip -d $ZIPBIN $PREFIX/$BINARY_DIR/$ZIPBIN.zip
# 	sed -i.bak "s|PYTHON_BINARY = '/usr/bin/python'|PYTHON_BINARY = sys.executable|" $ZIPBIN/__main__.py
# 	rm -f $ZIPBIN/*.bak
# 	cd $ZIPBIN
# 	zip -r ../$ZIPBIN.zip *
# 	cd ..
# 	mv $ZIPBIN.zip $PREFIX/$BINARY_DIR
# done

# # Copy wrapper scripts, pointing to internal binary and model directories
# cp ${RECIPE_DIR}/dv_make_examples.py $PREFIX/bin
# sed -i.bak "s|BINARYSUB|${BINARY_DIR}|" $PREFIX/bin/dv_make_examples.py
# cp ${RECIPE_DIR}/dv_call_variants.py $PREFIX/bin
# sed -i.bak "s|BINARYSUB|${BINARY_DIR}|" $PREFIX/bin/dv_call_variants.py
# sed -i.bak "s|WGSMODELSUB|${WGS_MODEL_DIR}|" $PREFIX/bin/dv_call_variants.py
# sed -i.bak "s|WESMODELSUB|${WES_MODEL_DIR}|" $PREFIX/bin/dv_call_variants.py
# cp ${RECIPE_DIR}/dv_postprocess_variants.py $PREFIX/bin
# sed -i.bak "s|BINARYSUB|${BINARY_DIR}|" $PREFIX/bin/dv_postprocess_variants.py
# rm -f $PREFIX/bin/*.bak

# ## Work in progress to build from source
# Trouble using pre-built clif so use binaries
# Left here as bread crumbs for future work

# Need tensorflow bazel GitHub definitions for building
git clone https://github.com/tensorflow/tensorflow
sed -i.bak 's|%workspace%/../tensorflow|%workspace%/tensorflow|g' ${SRC_DIR}/tools/bazel.rc
sed -i.bak "s|\.\./tensorflow|${SRC_DIR}/tensorflow|g" ${SRC_DIR}/WORKSPACE
cd tensorflow
git checkout v1.7.0
echo | ./configure
cd ..

# clif for building
gsutil -m cp gs://deepvariant/packages/oss_clif/oss_clif.centos-6.9.latest.tgz .
tar -xzpf oss_clif*.tgz
mv ${SRC_DIR}/usr/local/clif ${PREFIX}
# point build at new location instead of /usr/local
sed -i.bak "s|/usr/local|${PREFIX}|" WORKSPACE

# Create less long link to python so that we can insert at top of clif python scripts
# Default link is too long for a bang hash
ln -s ${PREFIX}/bin/python ${SRC_DIR}/python
# Fix pyclif to point at conda python + pyclif site-packages
sed -i.bak "s|#!/usr/local/clif/bin/python|#!${SRC_DIR}/python|" ${PREFIX}/clif/bin/pyclif
sed -i.bak "s|import sys|import sys; sys.path.append('${PREFIX}/clif/lib/python2.7/site-packages')|" ${PREFIX}/clif/bin/pyclif
sed -i.bak "s|#!/usr/local/clif/bin/python|#!${SRC_DIR}/python|" ${PREFIX}/clif/bin/pyclif_proto
sed -i.bak "s|import sys|import sys; sys.path.append('${PREFIX}/clif/lib/python2.7/site-packages')|" ${PREFIX}/clif/bin/pyclif_proto

# Includes for htslib
# Won't work because bazel detects linking outside the project
#sed -i.bak "s|\"-Wno-error\",|\"-Wno-error\", \"-I${PREFIX}/include\",|" third_party/htslib.BUILD

source settings.sh
bazel build -c opt ${DV_COPT_FLAGS} deepvariant:binaries
bazel build :licenses_zip
