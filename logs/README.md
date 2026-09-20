# Raw logs

One directory per backlog item, `logs/b-NN/`, each holding the raw output of the runs that item
produced and a `README.md` saying what to read it for.

**These are the deliverable, not an appendix.** Every figure in a document has a path into here,
and a figure without one does not go into a document. A retraction is appended to the file that
carried the original; the original is not edited away.

Logs are captured on the Mac and never written on the Linux box: the mutagen replica deletes
anything the Linux side creates on its next cycle. Every measurement therefore runs as
`wsl-run '<script>' > logs/<item>/<date>.log`, with the script printing to stdout and writing no
file it wants to keep.
