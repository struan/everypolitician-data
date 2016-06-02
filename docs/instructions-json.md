# instructions.json

Each legislature has a `sources/instructions.json` file which describes where the data for building the legislature comes from.

## Basics

TODO: Describe basics of adding a new source etc.

## Types

### `ocd`

If you provide an [OCD Division Identifier](http://opencivicdata.readthedocs.io/en/latest/proposals/0002.html) CSV as a source file then that can either be used to populate the `area` column based on the `area_id` column, or it can go the other way and try to populate the `area_id` column based on what's on the `area` column.

The default behaviour is to try and populate the `area_id` column based on the `area` column.

#### Populate `area` based on `area_id`

If you include the `"generate": "area"` option in the source then it will add an `area` column based on the existing `area_id` of the row, rather than the default behaviour.
