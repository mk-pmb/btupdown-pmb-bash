
<!--#echo json="package.json" key="name" underline="=" -->
btupdown-pmb
============
<!--/#echo -->

<!--#echo json="package.json" key="description" -->
Watch bluetooth devices (dis)connecting and run scripts accordingly.
<!--/#echo -->


What about `bluemon-client`?
----------------------------

From reading [its man page][man-bluemon-client],
it seems to be the perfect tool for the job.
However, I couldn't get it to work on Ubuntu focal.

  [man-bluemon-client]: http://manpages.ubuntu.com/manpages/focal/man1/bluemon-client.1.html




<!--#toc stop="scan" -->



Known issues
------------

* Needs more/better tests and docs.




&nbsp;


License
-------
<!--#echo json="package.json" key=".license" -->
ISC
<!--/#echo -->
