Pomal
=====

Personal Offline Manga/Anime List

-------

This project is intended to be an offline anime and manga tracker to provide an alternative or supplement to online trackers, that is less exposed to attacks by disgruntled parties with some grudge against those Web sites.

If possible, this project will provide the capability to update the status of shows on those sites, so that the data will be present in multiple locations.

However, this software does not require an account with any online tracking service.

-------

History of Release Criteria and Changes

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
