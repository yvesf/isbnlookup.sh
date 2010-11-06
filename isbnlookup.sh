#!/bin/bash
# USAGE EXAMPLES
# for file in *pdf; do newname=`isbnlookup.sh "${file}"` && echo -e "success\t${file}\n\t${newname}" || echo "failed ${file}"; done

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
    | grep -o -E "ISBN.{0,10}([0-9\-]{13,17}|[0-9]{10,13})" \
    | grep -o -E "([0-9\-]{13,17}|[0-9]{10,13})" \
    | head -n 1 \
    | tr -c -d '0-9\-'
}

fetch_amazon_searchlinks() {
    search_url="http://www.amazon.com/s/url=search-alias%3Daps&field-keywords=${1}"
    wget -U "Mozilla/5.0 (X11; U; Linux x86_64; en-US) AppleWebKit/540.0 (KHTML, like Gecko) Ubuntu/10.10 Chrome/8.1.0.0 Safari/540.0" \
            -q -O - ${search_url} \
        | grep -E -o 'http://www.amazon.com[^"]*/dp/[0-9]*'
}

fetch_amazon_titleinfo() {
    wget -q -O - "${url}" \
        | iconv -f latin1 -t utf-8 \
        | sed -n -r 's/<title>[^:]*: ?(.*) ?\(.*/\1/p'
}

sanitize_filename() {
    echo "${1}" | tr -c -d 'A-Za-z0-9\ '
}

file="${1}"

test -f "${file}" || error "No file given"
isbn=`extract_first_pages "${file}" | find_first_isbn_number`

if [ ${#isbn} -eq 0 ]; then
    error "No ISBN found in ${file}"
fi

url=`fetch_amazon_searchlinks "${isbn}" | head -n 1`

if [ ${#url} -eq 0 ]; then
    error "No Amazon Record for ISBN ${isbn}"
fi

title=`fetch_amazon_titleinfo "${url}"`

if [ ${#title} -eq 0 ]; then
    error "No title for ISBN ${isbn} at ${url} found"
fi

echo "`sanitize_filename \"${title}\"` #isbn_${isbn}.pdf"
