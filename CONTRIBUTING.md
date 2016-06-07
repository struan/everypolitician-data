# Contributing

## Contributing data to EveryPolitician

If you want to contribute *data* to the 
[EveryPolitician](http://everypolitician.org/) project, great! And thanks!

Furthermore, if you're looking at this file (`CONTRIBUTING.md`) then
you're probably familiar with GitHub and pull requests.

So please, if you want to help: don't send us data in a pull request
for [everypolitician-data](https://github.com/everypolitician/everypolitician-data).
Instead, please read
[our "contributing" page](http://docs.everypolitician.org/contribute.html)
which is our appeal for data *sources*.

### This data repo is updated with data *from upstream sources*

(or *Why it's futile to add data directly to the datafiles in this repo*)

If you have a look at the pull requests coming into this repo, updating the
data, you'll see there have been a *lot* -- and nearly all of them are coming
from
[the EveryPoliticianBot account](https://github.com/everypolitician/everypolitician-data/pulls/everypoliticianbot).

So although this repo does indeed contain all the lovely EveryPolitician data,
we populate it by adding sources to
[the automatic process that builds the data by combining them](https://medium.com/@everypolitician/getting-busy-with-scraper-data-957a2ddd9963). That process, running as EveryPolitician bot, then submits the data
it's built as pull requests to this repo. Human members of the EveryPolitician
team then
[merge those pull requests](https://medium.com/@everypolitician/i-let-humans-have-the-final-word-45ca8efc807f).

The practical consequence of this is that if we make any changes to data 
directly in the repo here, those changes will be lost. They will be overridden
by the next update, because we 
[rebuild the data from scratch](https://medium.com/@everypolitician/sometimes-i-work-hard-to-produce-nothing-400762d252ff).

Instead, the data must be added upstream, so that it is included in those
updates.

### If you have data for us, get in touch!

So if you have data for us, please read 
[this guidance](http://docs.everypolitician.org/contribute.html) and then
get in touch with us at team@everypolitician.org so we can add the source.

If you only have static data, that's fine; but get in touch so we can
find a way to make it available to [our bot](http://doc.everypolitician.org/bot.html)
upstream.

## Contributing code

There's a growing collection of repos that contain code used by the
EveryPolitician project team: see the
[everypolitician/everypolitician](https://github.com/everypolitician/everypolitician) repo for a jumping-off point. That's got a README linking/explaining some
of the core repos.

— EveryPolitician team