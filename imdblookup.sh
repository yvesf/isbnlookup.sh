#!/bin/sh

fs_clean() {
    perl -pe 'tr/0-9a-zA-z _ÖÄÜöäü\ls |&?,;//cd'
}

clean_name() {
    echo "$1" | perl -pe 's/(.*?)\.(?:20[0-1][0-9]|19[0-9]{2}|hdtv|extended|dvd|ac3|R2|R5|unrated|TS|720p|md|ts|ld|bdrip|tvrip|dvdrip|dvdscr|uncut|German|telesync)\..*/\1/i' | 
        perl -pe 's/\./ /g'
}

query() {
    file=$(mktemp -t imdblookup.XXX)
    term="$1"
    year=$2
    if [ -n "$year" ]; then
	  term="${term}&year=$year"
    fi
    echo SEARCH: $term >&2
    wget "http://www.deanclatworthy.com/imdb/?q=$term" -O - -q |
    	sed -e 's/",/"\
/g; s/^{//; s/}$//; s/":/	/g; s/"//g' >$file

    if ! grep "\"code\":1," $file >/dev/null; then
        title="`grep -E '^title' $file | cut -f 2 -d '	' | fs_clean`"
        year="`grep -E '^year' $file | cut -f 2 -d '	'`"
        imdbId="`grep -E 'imdbid' $file | cut -f 2 -d '	'`"
        echo "$title ($year) #$imdbId"
        rm $file
    	return 0
    else
        echo "Nothing found"
    rm $file
    	return 1
    fi
}

imdb_get_year() {
    id="$1"
    wget -q -U "Mozilla" -O - "http://www.imdb.com/title/$id/" |
        perl -ne 'if (/year\/[0-9]{4}\/">([0-9]{4})<\/a>/) { print "$1\n"; };'
}

name=$(basename "$1")
name=$(clean_name "$name")
name=$(query "$name" "$2")
if [ "$?" = 0 ] && [ -d "$1" ]; then
  echo "EXECUTE: ?"
  echo "mkdir \"$name\""
  echo "mv \"$1\" \"$name\""
  read foo && ( test -d "$name" || mkdir "$name" ) && mv "$1" "$name"
else
  echo "mkdir \"$name\""
  read foo && ( test -d "$name" && echo "Directory exists" || mkdir "$name" )
fi
