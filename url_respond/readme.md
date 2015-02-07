# Responding to URIs

## TODO

Some of this just ideas... not sure what to do.

* Text above,

* Only allowing initial load blocks a lot. Probably want easy enable/disable.
  + Timelimit?

* Blocking inter-domain.

* Blocking javascript? The `.js` extension indicates.. But false negatives?
  + Blocking javascript by-domain, and by domain-to-domain.

* Actually use the SQL table, and make an interface for it.

  NOTE: a customizable *general* table-reader might help out.

* Is there a clever way to create regular expressions from black/whitelists?
  [Regex golf](http://www.reddit.com/r/programming/comments/1tb0go/regex_golf/)    
  
  Blacklists can be created from:
  + Post-initial loading.
  + Indication.
  
  Whitelists:
  + Indication.
  + Visits.
  
  Indication: how do we do that: 
  + Images, point, and then figure out the element underneath
  + Javascript: lists?
  
* Iterating over elements in javascript, and allowing everything that appears
  to be in-view? (Perhaps appending a 'secret' that is allowed by the filter)

## Bugs?

* It messes with history somehow??
