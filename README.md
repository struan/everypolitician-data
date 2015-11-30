# everypolitician-data

This repo contains the data powering [EveryPolitician.org](http://everypolitician.org/), and other sites such as [Gender-Balance.org](http://www.gender-balance.org/).

Information on how to _use_ the data can be found at http://everypolitician.org/technical.html, and high-level information about how to contribute is at http://everypolitician.org/contribute.html

This document is for developers actively working _on_ the project, rather than consuming data from it.

## Adding a new country

1. Make a new subdirectory in `data` named for the Country

    If this is for a legislature that does not map cleanly to an ISO 3166-1 country code (e.g. Wales, Kosovo), or you name the directly differently from what the Ruby [iso_country_codes gem understands](https://github.com/alexrabarts/iso_country_codes/blob/master/lib/iso_country_codes/iso_3166_1.rb) (e.g. Congo-Brazzaville), you will also need to supply a `meta.json` (see those examples for details)

2. Make a separate subdirectory within the Country for each distinct legislature or chamber

    i.e. both the upper and lower houses of a bicameral legislature should have separate directories, as should successor bodies (e.g. in Libya, the National Transitional Council, General National Congress, and Council of Deputies are all distinct).

3. Add a `meta.json` for the legislature. This *must* include fields for the legislature `name`, and how many `seats` it currently has. It *should* also contain a `wikidata` reference code. See, for example, [Poland](https://github.com/everypolitician/everypolitician-data/blob/master/data/Poland/Sejm/meta.json)

4. Provide a `Rakefile.rb` that knows how to build the data. In the vast majority of cases this should simply follow the standard workflow we use everywhere. The basic concept is that you provide instructions on how to generate or download some CSV files (at a mimimum a single file of Membership information and a file of Legislative Period / Term information), and these are them combined, turned into a consistent JSON format (based on Popolo), and then split up again into a series of period-based CSVs. This requires:

    1. A single line `Rakefile.rb`

      ```require_relative '../../../rakefile_common.rb'```

    2. A `sources/instructions.json` file listing the data sources, and how to combine them. Proper documentation on this will follow later, but [the Australian House of Representatives](https://github.com/everypolitician/everypolitician-data/blob/master/data/Australia/Representatives/sources/instructions.json) is a reasonably good example to work from. 

## Building the data for a legislature

1. From within the directory for the legislature it should usually be enough to run `rake clean && bundle exec rake`. If you want to fetch fresh data from the source(s) (e.g. Morph.io), then use `rake clobber && bundle exec rake` instead. If you're fetching any data from Morph, you'll also need to specify your [morph.io API key](https://morph.io/documentation/api) in the environment variable `MORPH_API_KEY`, e.g. `MORPH_API_KEY=my_secret_key bundle exec rake`

2. Make sure that the changes look sensible, and then commit the new/refreshed data.

3. From the root directory of the *project* (not the legislature) run `bundle exec rake countries.json`, and commit the resulting change. This updates the master list of country data with the information you’ve just added. (It includes the sha of the commit from stage 2, so needs to be run separately *after* it)

