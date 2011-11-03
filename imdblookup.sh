#!/bin/sh

fs_clean() {
    perl -pe 'tr/0-9a-zA-z _ÖÄÜöäü\ls |&?,;//cd'
}

clean_name() {
    echo "$1" | perl -pe 's/(.*?)\.(?:20[0-1][0-9]|19[0-9]{2}|dvd|ac3|R5|unrated|TS|720p|md|ts|ld|bdrip|tvrip|dvdrip|dvdscr|uncut|German|telesync)\..*/\1/i' | 
        perl -pe 's/\./ /g'
}

query() {
    file=$(mktemp -t imdblookup.XXX)
    wget "http://www.imdbapi.com/?i=&t=$1" -O - -q |
    	sed -e 's/",/"\
/g; s/^{//; s/}$//; s/":/	/g; s/"//g' >$file

    if grep "Response	True" $file >/dev/null; then
        title="`grep -E '^Title' $file | cut -f 2 -d '	' | fs_clean`"
        year="`grep -E '^Year' $file | cut -f 2 -d '	'`"
        imdbId="`grep -E '^ID' $file | cut -f 2 -d '	'`"
        echo "$title ($year) #$imdbId"
    else
        echo "Nothing found"
    fi
    rm $file
}

imdb_get_year() {
    id="$1"
    wget -q -U "Mozilla" -O - "http://www.imdb.com/title/$id/" |
        perl -ne 'if (/year\/[0-9]{4}\/">([0-9]{4})<\/a>/) { print "$1\n"; };'
}

name=$(basename "$1")
name=$(clean_name "$name")

query "$name"
