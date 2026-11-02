# ending_flutter

A new Flutter project.

## Book download freshness

Book entries in `books.json` can include a freshness field such as `version`,
`content_version`, `etag`, `last_modified`, `updated_at`, `file_size`, or
`size`. The app stores that value with each downloaded book and downloads the
book again when the catalog value changes. Catalog publishers should update
this field whenever the corresponding book file changes. Entries without a
freshness field retain the existing cache behavior.
