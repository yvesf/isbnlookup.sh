#!/usr/bin/env bash

error() {
    echo $1 >&2
    exit 1
}

extract_first_pages() {
    pdftotext -f 1 -l 10 "${1}" -
}

find_first_isbn_number() {
    grep "ISBN" \
    | sed -e '
# Unicode replacements
s/\xef\x99\x81/9/g
s/\xef\x99\x80/8/g
s/\xef\x98\xbf/7/g
s/\xef\x98\xbe/6/g
s/\xef\x98\xbd/5/g
s/\xef\x98\xbc/4/g
s/\xef\x98\xbb/3/g
s/\xef\x98\xba/2/g
s/\xef\x9b\x9c/1/g
s/\xef\x98\xb9/0/g
# isbn-10 isbn-13.. prefix
s/isbn-1[03]//i' \
    | head -n 1 \
    | tr -c -d '0-9\-\ ' \
    | sed -ne '
:isbn13
s/.*\([0-9]\{3\}-\?[0-9]-\?[0-9]\{3,4\}-\?[0-9]\{4\}-\?[0-9]-\?[0-9]\?\).*/isbn13 \1/p ; t finish;
:isbn10
s/.*\([0-9]\{1\}-\?[0-9]\{3,4\}-\?[0-9]\{4,5\}\).*/isbn10 \1/p ; t finish;
:finish'
}

fetch_google_books_info() {
    tempfile=`mktemp`
    wget -O "$tempfile" -q "http://books.google.com/books/feeds/volumes?q=$1&max-results=10"
    echo $tempfile
}

google_books_count_results() {
    tempfile=$1
    xpath -q -e 'count(/feed/entry)' "$tempfile" 2>/dev/null
}

google_books_print_results() {
    tempfile=$1
    count=`google_books_count_results "$tempfile"`
    for i in `seq 1 $count`; do
        echo -n "$i : "
        google_books_authors "$tempfile" "$i" | tr -d '\n'
        echo -n " - "
        google_books_title "$tempfile" "$i" | tr -d '\n'
        echo -n " #isbn_"
        google_books_identifier "$tempfile" "$i" | tr -d '\n'
        echo ".pdf"
    done
}

google_books_authors() {
    tempfile=$1
    entry=$2
    xpath -q -e "/feed/entry[$entry]/dc:creator/text()" "$tempfile" | head -n 1
}

google_books_title() {
    tempfile=$1
    entry=$2
    xpath -q -e "/feed/entry[$entry]/title/text()" "$tempfile"
}

google_books_identifier() {
    tempfile=$1
    entry=$2
    xpath -q -e "/feed/entry[$entry]/dc:identifier/text()" "$tempfile" | sed -n -e 's/ISBN:\(.*\)/\1/p' | sort -r | head -n 1
}

sanitize_filename() {
    echo "${1}" | tr -c -d 'A-Za-z0-9:\ '
}

if [ "$1" = "-r" ]; then
    rename=true
    shift
else
    rename=false
fi
search=$*

if [ -f "$search" ]; then
    echo -n "search file: $search"
    isbn=`extract_first_pages "${search}" | find_first_isbn_number`
    if [ ${#isbn} -eq 0 ]; then
        echo " ... no isbn found"
        exit 1
    fi
    echo " ... $isbn"
    infofile=`fetch_google_books_info "${isbn##* }"`
else
    echo "search term: $search"
    infofile=`fetch_google_books_info "$search"`
fi

#if [ `google_books_count_results "$infofile"` -eq 1 ]; then
#    number=1
#el
if [ `google_books_count_results "$infofile"` -eq 0 ]; then
    error "Nothing found for \"$search\" / $isbn"
else
    google_books_print_results $infofile
    echo -n "Results for >$search< Pick Number: "
    read number
fi

if [ -z "$number" ]; then
    echo "Skip this file"
    exit 0
fi

author=`google_books_authors "$infofile" $number`
title=`google_books_title "$infofile" $number`
identifier=`google_books_identifier "$infofile" $number`
if [ -n "$author" ]; then
    newname="$author - $title #isbn_$identifier.pdf"
else
    newname="$title #isbn_$identifier.pdf"
fi
newname=`echo "$newname" | tr -d -c 'A-Za-z0-9. #_,-'`

if $rename && [ -f "$search" ]; then
    echo "=> => => Rename: (press return or ctrl-c)"
    echo "<=  $search"
    echo " => $newname"
#    read
    mv "$search" "$newname"
    mv "$infofile" "$newname.googlebooks.xml"
else
    echo $newname
    rm $infofile
fi
