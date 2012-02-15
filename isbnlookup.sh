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
    | tr -c -d 'A-Za-z0-9\-\ ' \
    | head -n 1 \
    | tr -c -d '0-9\-X'
}
#  | grep -o -E "ISBN *.{0,10} *([0-9\-]{13,17}|[0-9]{10,13})" \
#  | grep -o -E "([0-9\-]{13,17}|[0-9]{10,13})" \

fetch_google_books_info() {
    isbn=$1
    tempfile=`mktemp`
    wget -O "$tempfile" -q "http://books.google.com/books/feeds/volumes?q=$1&start-index=11&max-results=10"
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
    echo "${1}" | tr -c -d 'A-Za-z0-9\ '
}


if [ "$1" = "-r" ]; then
    rename=true
    shift
else
    rename=false
fi
search=$*

if [ -f "$search" ]; then
    isbn=`extract_first_pages "${search}" | find_first_isbn_number`
    if [ ${#isbn} -eq 0 ]; then
        error "No ISBN found in ${search}"
    fi
    infofile=`fetch_google_books_info "isbn:$isbn"`
else
    echo "search term: $search"
    infofile=`fetch_google_books_info "$search"`
fi

if [ `google_books_count_results "$infofile"` -eq 1 ]; then
    number=1
elif [ `google_books_count_results "$infofile"` -eq 0 ]; then
    error "Nothing found for \"$search\" / $isbn"
else
    google_books_print_results $infofile
    echo -n "Pick Number: "
    read number
fi
author=`google_books_authors "$infofile" $number`
title=`google_books_title "$infofile" $number`
identifier=`google_books_identifier "$infofile" $number`
if [ -n "$author" ]; then
    newname="$author - $title #isbn_$identifier.pdf"
else
    newname="$title #isbn_$identifier.pdf"
fi
newname=`echo "$newname" | tr -d -c 'A-Za-z0-9. #_,:-'`

if $rename && [ -f "$search" ]; then
    mv -v "$search" "$newname"
else
    echo $newname
fi
rm $infofile
