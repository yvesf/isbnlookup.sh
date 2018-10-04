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
s/.*\([0-9]\{3\}-\?[0-9]-\?[0-9]\{2,4\}-\?[0-9]\{4,6\}-\?[0-9]-\?[0-9]\?\).*/isbn13 \1/p ; t finish;
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
    xpath -q -e 'count(/feed/entry)' "$1" 2>/dev/null
}

google_books_print_results() {
    tempfile=$1
    count=`google_books_count_results "$tempfile"`
    for i in `seq 1 $count`; do
        echo -n "$i : "
        google_books_entry_field "$tempfile" "$i" dc:creator
        echo -n " - "
        google_books_entry_field "$tempfile" "$i" title
        echo -n " #isbn_"
        google_books_entry_isbn "$tempfile" "$i"
        echo ".pdf"
    done
}

google_books_entry_field() {
    tempfile=$1
    entryno=$2
    fieldname=$3
    xpath -q -e "/feed/entry[$entryno]/$fieldname/text()" "$tempfile" | head -n 1 | tr -d '\n'
}

google_books_entry_isbn() {
    tempfile=$1
    entryno=$2
    xpath -q -e "/feed/entry[$entryno]/dc:identifier/text()" "$tempfile" | sed -n -e 's/ISBN:\(.*\)/\1/p' | sort -r | head -n 1 | tr -d '\n'
}

sanitize_filename() {
    echo "$1" | tr -d -c 'A-Za-z0-9. #_,-'
}

if [ "$1" = "-r" ]; then
    rename=true
    shift
else
    rename=false
fi

if [ -f "$1" ]; then
    filename=$1
    shift
else
    if $rename; then
        echo "No filename given but rename (-r) requested"
    fi
fi

search=$*

# Find search term and issue google-search
if [ -z "$search" ] && [ -n "$filename" ]; then
    echo -n "search ISBN in file: $filename"
    isbn=`extract_first_pages "${filename}" | find_first_isbn_number`
    if [ ${#isbn} -eq 0 ]; then
        error " ... no isbn found"
    fi
    echo " ... $isbn"
    infofile=`fetch_google_books_info "${isbn##* }"`
else
    echo "search term: $search"
    infofile=`fetch_google_books_info "$search"`
fi

# Print search result. Exit when none
# Select a result by typing number
if [ `google_books_count_results "$infofile"` -eq 0 ]; then
    error "Nothing found for \"$search\" / $isbn"
else
    google_books_print_results $infofile
    while true; do
        echo -n "Pick Number ('o' for open file, or nothing to skip): "
        read number
        if [ "$number" != "o" ]; then
            break
        fi
        xdg-open "$filename"
    done
fi

# Exit when no input
if [ -z "$number" ]; then
    echo "Skip this file"
    exit 0
fi

# Rename file. Copy google-books xml.
author=`google_books_entry_field "$tempfile" "$number" dc:creator`
title=`google_books_entry_field "$tempfile" "$number" title`
isbn=`google_books_entry_isbn "$tempfile" "$number"`
if [ -n "$author" ]; then
    newname="$author - $title #isbn_$isbn.pdf"
else
    newname="$title #isbn_$isbn.pdf"
fi
newname=`sanitize_filename "$newname"`

if $rename; then
    echo "=> => => Rename: (press return or ctrl-c)"
    echo "<=  $filename"
    echo " => $newname"
    xpath -q -e "/feed/entry[$number]" < "$infofile" | xmllint --valid --format - > "$newname.googlebooks.xml" 2>/dev/null
    mv "$filename" "$newname"
    rm "$infofile"
else
    echo "New Filename: $newname"
    rm $infofile
fi
