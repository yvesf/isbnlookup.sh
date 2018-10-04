isbnlookup.sh
Bash-Script for organizing of pdf ebooks

`isbn_lookup` uses pdftotext to extract the book ISBN number and
query google-books with this. It may also use custom search terms instead.

gitHub Repository: http://github.com/yvesf/isbnlookup.sh

## Invocation

Try to figure out isbn number as search term: `isbnlookup.sh -r filename.pdf`

Use custom search term 'blah blah': `isbnlookup.sh -r filename.pdf blah blah`

