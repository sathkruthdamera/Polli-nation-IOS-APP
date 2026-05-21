# Data Sources

## Government-only source

Polli-Nation uses NOAA/NWS `api.weather.gov` only. For a user coordinate, the app/backend calls:

1. `/points/{latitude},{longitude}` to resolve the local forecast grid.
2. `forecastGridData` from the point response to read live/near-term grid values.

The pollen-risk estimate uses:

- temperature
- relative humidity
- wind speed
- precipitation chance
- quantitative precipitation
- U.S. seasonal pollen timing
- rough regional plant patterns

## Accuracy boundary

This is a pollen-risk estimate, not a measured pollen count. This build intentionally excludes all non-government sources and paid pollen providers.
