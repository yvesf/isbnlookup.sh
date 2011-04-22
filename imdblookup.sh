#!/bin/sh

fs_clean() {
    perl -pe 'tr/0-9a-zA-z _ÖÄÜöäü\ls |&?,;//cd'
}

unescape() {
    perl -e 'use HTML::Entities; while (<>) { print decode_entities($_); };'
}

clean_name() {
    echo "$1" | perl -pe 's/(.*?)\.(?:20[0-1][0-9]|19[0-9]{2}|dvd|ac3|R5|unrated|TS|720p|md|ts|ld|bdrip|tvrip|dvdrip|dvdscr|uncut|German|telesync)\..*/\1/i' | 
        perl -pe 's/\./ /g'
}

query() {
    file=$(mktemp)
    wget -q -U "Mozilla" -O - "http://imdb.com/find?s=tt&q=$1" >$file
    list=$(perl -ne 'if (/(tt[0-9]+)\/.{3}>([^<]+)<\/a/g) { print "$1\t$2\n"; }' <$file | 
        sort | 
        uniq )
    if [ "xx$list" = "xx" ]; then
        perl -ne 'if (/href="http:\/\/www.imdb.com\/title\/(tt[0-9]+)/) { print "$1"; }; ' <$file 
        perl -ne 'if (/<title>(.+) \(/) { print "\t$1\n"; }; ' <$file
    else
        echo "$list"
    fi
}

imdb_get_year() {
    id="$1"
    wget -q -U "Mozilla" -O - "http://www.imdb.com/title/$id/" |
        perl -ne 'if (/year\/[0-9]{4}\/">([0-9]{4})<\/a>/) { print "$1\n"; };'
}

name=$(basename "$1")
name=$(clean_name "$name")
echo "Search >$name<"

query "$name" |
    while read line; do
        id=$(echo "$line" | cut -f 1)
        name=$(echo "$line" | cut -f 2 | unescape)
        year=$(imdb_get_year "$id")
        echo "$name ($year) #$id"
    done
