tell application "Pages"
    open POSIX file "/Users/zhengliu/Documents/111.pages"
    set doc to document 1
    set mytext to body text of doc
    close doc
    return mytext
end tell
