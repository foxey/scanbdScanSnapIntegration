#!/bin/bash
# scan.sh - Scanning script to scan a multipage document into a searchable PDF
#             that is emailed to one or more pre-defined addresses.
#
# Copyright (C) 2015 Michiel Fokke <michiel@fokke.org>
# This program is free software: you can redistribute it and/or modify
# it under the terms of the GNU General Public License as publishedby
# the Free Software Foundation, either version 3 of the License, or
# (at your option) any later version.
# 
# This program is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
# GNU General Public License for more details.
# 
# You should have received a copy of the GNU General Public License
# along with this program.  If not,see <http://www.gnu.org/licenses/>.

# CONFIGURATION

# Be elaborate during ORC stage
DEBUG=1

# Languages used by Tessact OCR (use + as separator)
OCR_LANGUAGES="nld+eng"

# Sender address 
FROM="Paperless office <paperless.office@example.com>"

# Errors are mailed to this address
ERRORS_TO="me@example.com"

# Recipient address
DOCUMENT_TO=$ERRORS_TO

# Format of the email subject and the name of the PDF file
SUBJECT="scan-$(date +%Y-%m-%dT%H.%M.%S)"

# Only for sending to Evernote (leave empty for other recipients)
# Add notebook and tags
EVERNOTE_META_INFO="@Archief #inbox"
FILENAME="${SUBJECT}.pdf"

# NO CHANGES AFTER THIS POINT


function wait_for {
    NUM_PROCS=$(jobs|grep -i $1|grep -i running|wc -l)
    while [ $NUM_PROCS -ge $2 ]; do
        [ "$DEBUG" = "0" ] || echo "$NUM_PROCS ocr proces(ses) active, waiting"
        NUM_PROCS=$(jobs|grep -i $1|grep -i running|wc -l)
        sleep 2
    done
}


if [ "$1" != "daemon" ]; then
    nohup $0 daemon > /dev/null 2>&1 &
    sleep 10
    exit
fi

TEMPDIR=$(mktemp -d)
trap "{ cd /tmp; rm -rf $TEMPDIR ; }" EXIT
cd $TEMPDIR

LOG=out.log
echo "Logfile for $FILENAME" > $LOG

scanimage --device 'fujitsu' --batch='out%04d.pnm' -x 210 --page-width 210 \
    -y 355 --page-height 297 --source 'ADF Duplex' --swskip 15 --swdespeck 1 \
    >> $LOG 2>&1

# This service restart is a workaround, because somehow scandb causes a
# segfault in libsane:
# scanbd[6103]: segfault at 0 ip 00007f3e3633e993 sp 00007f3e1cabeca0 error 4
# in libsane.so.1.0.25[7f3e3633a000+7000]

systemctl restart scanbd

NUMPAGES=$(ls out*.pnm 2>/dev/null|wc -l)

if [ $NUMPAGES -gt 0 ]; then
    for IMAGE in out*.pnm; do
        NAME=$(basename $IMAGE .pnm)
        tesseract $IMAGE $NAME -l $OCR_LANGUAGES pdf >> $LOG 2>&1 &
        NUM_CPUS=2
        wait_for tesseract $NUM_CPUS 
    done
    wait_for tesseract 1

    if [ $(ls out*.pdf 2>/dev/null|wc -l) -gt 1 ]; then
        pdfunite out*.pdf $FILENAME >> $LOG 2>&1
    elif [ $(ls out*.pdf 2>/dev/null|wc -l) -eq 1 ]; then
        cp out*.pdf $FILENAME >> $LOG 2>&1
    else
        echo 'No scanned pages found' >> $LOG
        echo 'Existing files:' >> $LOG
        ls -l >> $LOG 1>&2
    fi
else
    echo 'No scanned pages found'  >> $LOG
    echo 'Existing files:' >> $LOG
    ls -l >> $LOG 1>&2
fi

if [ -f $FILENAME ]; then
    BODY=$(basename $FILENAME .pdf).txt
    pdftotext -nopgbrk $FILENAME - > $BODY
    echo >> $BODY

    if [ $NUMPAGES -gt 1 ]; then
        PAGES="pages"
    else
        PAGES="page"
    fi
    mime-construct --header "From: $FROM" --to "$DOCUMENT_TO" \
        --subject "$SUBJECT ($NUMPAGES $PAGES) $EVERNOTE_META_INFO" \
        --attach $FILENAME
else
    mime-construct --header "From: $FROM" --to "$ERRORS_TO" \
        --subject "Failed scan - $SUBJECT" \
        --body $(echo -e "The scanned document with filename $FILENAME was" \
                         "not converted in a valid PDF file. More details" \
                         "are found in the attached logfile.\n") --attach $LOG
fi

# vim: set tw=79 ts=4 sw=4 expandtab si:
