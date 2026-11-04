#!/bin/bash

MODNAME='disable-enemies-lib'
VERSION=$1
ZIPFILE="${MODNAME}_${VERSION}.zip"
DIRECTORY=$MODNAME
EXCLUDE="${DIRECTORY}/make-zip.sh ${DIRECTORY}/TODO.md ${DIRECTORY}/.editorconfig ${DIRECTORY}/${MODNAME}_*.zip ${DIRECTORY}/*.ora ${DIRECTORY}/*.ora~"

find . -name "${MODNAME}_*.zip" -delete
cd ..
zip -r $DIRECTORY/$ZIPFILE $DIRECTORY -x $DIRECTORY/.git\* $EXCLUDE
cd $DIRECTORY
