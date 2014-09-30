Pomal
=====

Personal Offline Manga/Anime List

-------

This project is intended to be an offline anime and manga tracker to provide an alternative or supplement to online trackers, that is less exposed to attacks by disgruntled parties with some grudge against those Web sites.

If possible, this project will provide the capability to update the status of shows on those sites, so that the data will be present in multiple locations.

However, this software does not require an account with any online tracking service.

-------

To run this program under Windows, you will need to install:
perl (e.g., Strawberry Perl)
Prima (cpan Prima under Strawberry Perl)

cpan modules:

History of Release Criteria and Changes

Version reset to v0.01-prealpha: Sep 29, 2014
Owing to a difficulty in getting GTK perl libraries to install properly on my Windows test machine, I have decided to change the underlying GUI library to something I can get working there.
Consequently, I have decided to reset the version number, since I will be essentially starting over with the GUI code.
No further functionality will be added to the project until the existing GUI functions have been re-written. Thank you for your patience.

v0.2: Released Sep 25, 2014
-----
Met 14/09/19: I can click and have an episode I've watched recorded.
Met 14/09/20: createMainWin should generate the tables fillPage will use, so that menu items, etc., can fill/append to them.
Met 14/09/22: Finish coding import (specifically, tags handling) so that the limiter can be removed from the loop, allowing the loop to return the proper error code, which cascades to other functions
Met 14/09/22: Import should (using fillPage?) update the display when it finishes.
Met 14/09/22: Import should display a sayBox with the count of successfully imported/updated titles.
FIXED 14/09/22: SQLite can't recognize tables already exist, right now. That took an ugly hack.
Met 14/09/22: Make sure all SQL update functions use prepareFromHash (for uniformity and easier debugging)
Met 14/09/23: When building title rows, put in button(s) for moving to another status
Met 14/09/25: Options dialog box
Met 14/09/25: Changing options immediately updates all tabs (link to confirmation button, not individual options)
