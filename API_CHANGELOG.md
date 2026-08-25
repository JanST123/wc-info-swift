# WC-Info API v2 Changelog

This document is intended for the frontend/mobile client team migrating from the legacy v1 API to the new Laravel 11 v2 API.

## Base URL

v2 is deployed to `https://api.wc-info.de` (root path, no `/api` prefix).

Legacy v1 remains available at its existing URL for a transition period, but new clients should target v2.

## Authentication and CORS

No authentication is required. CORS is configured for the production frontend origin and `localhost:8000` for development.

## Endpoint changes

| Change | v1 path | v2 path | Notes |
|---|---|---|---|
| Renamed | `POST /places/cache/{placeId}` | `POST /places/{placeId}` | Stores place details. URL no longer contains `/cache`. |
| Renamed | `GET /places/cache/{placeId}` | `GET /places/{placeId}` | Retrieves cached place details. |
| Removed | `POST /places/add_unknown` | — | Unknown-place registration is no longer supported. |
| Unchanged | `GET /toilets/place/{placeId}` | `GET /toilets/place/{placeId}` | Toilets for a given Google `place_id`. |
| Changed | `GET /toilets/bounds/{south}/{west}/{north}/{east}` | `GET /toilets/bounds/{south}/{west}/{north}/{east}` | Now returns the full toilet list resource (was a reduced object). |
| Unchanged | `GET /toilets/nearby/{lat}/{lon}` | `GET /toilets/nearby/{lat}/{lon}` | See behaviour change below. |
| Unchanged | `GET /toilet/{id}` | `GET /toilet/{id}` | Single toilet details. |
| Unchanged | `PATCH /toilet/{id}/update` | `PATCH /toilet/{id}/update` | Update a toilet. |
| Unchanged | `POST /toilet/add` | `POST /toilet/add` | Add a toilet manually. |
| Unchanged | `POST /toilet/add-properties/{toiletId}` | `POST /toilet/add-properties/{toiletId}` | Add key/value properties. |
| Unchanged | `POST /upload` | `POST /upload` | Upload photos. |
| Unchanged | `POST /uploadSubmit/{toiletId}` | `POST /uploadSubmit/{toiletId}` | Submit uploaded photos and activate toilet. |
| Unchanged | `DELETE /deletePhoto/{toiletId}/{filename}` | `DELETE /deletePhoto/{toiletId}/{filename}` | Delete a photo. |
| Unchanged | `GET /sitemap` | `GET /sitemap` | XML sitemap. |
| Unchanged | `GET /health` | `GET /health` | Health check. |

## Toilet object changes

### Removed fields

| v1 field | v2 replacement | Notes |
|---|---|---|
| `type` | `status` + property flags | The rigid `type` enum is gone. |
| `nr` | `id` | The separate numeric counter is gone; use the auto-increment `id`. |

### New / changed fields

| Field | Type | Description |
|---|---|---|
| `id` | integer | Primary key. |
| `status` | string | One of `active`, `hidden`, `deleted`. |
| `is_qualified` | boolean | Whether the entry has been verified. |
| `has_wheelchair_access` | boolean | Wheelchair accessible. |
| `has_changing_table` | boolean | Baby changing table available. |
| `lat` | float | Decimal degrees, e.g. `52.5200`. |
| `lon` | float | Decimal degrees, e.g. `13.4050`. |
| `place_id` | string | Google Places `place_id`. |
| `address` | string | Formatted address. |
| `website` | string | Website URL. |
| `place_opening_hours` | object | Parsed Google Places `periods` (see below). |
| `is_open` | boolean | Whether the place is currently open (only when `place_opening_hours` is present). |
| `open_timestamp` | string | ISO timestamp when the current open period started. |
| `close_timestamp` | string | ISO timestamp when the current open period ends. |
| `distance` | float | Distance in kilometers (included on nearby-search results). |

### Coordinate scaling

v1 stored coordinates as integers scaled by 10000 (`525200` meant `52.5200`). v2 returns raw decimal floats. The legacy integer scaling is removed on both input and output.

## Nearby search behaviour

`GET /toilets/nearby/{lat}/{lon}` first queries the local database. If no active toilets are found, the server performs a synchronous Google Places Nearby Search and returns any discovered places. This removes the need for the frontend to call Google directly.

The endpoint accepts optional query parameters:

| Parameter | Type | Description |
|---|---|---|
| `distance` | float | Search radius in kilometers. Defaults to **40 km**. |
| `filter` | string | Comma-separated list of filters, e.g. `is_open:true`. Currently only `is_open` is supported. |

`GET /toilets/bounds/{south}/{west}/{north}/{east}` accepts the same `?filter=` parameter.

When `filter=is_open:true` is set, only toilets that are currently open according to `place_opening_hours` are returned.

Results are ordered by distance (lowest first) and each item includes a `distance` field with the distance in kilometers from the requested coordinates.

## Background place discovery

The daily `app:discover-places` cronjob now focuses on places that are actually being used by API clients. Every toilet returned by `GET /toilets/nearby/{lat}/{lon}`, `GET /toilets/bounds/...`, `GET /toilets/place/{placeId}`, or `GET /toilet/{id}` updates an internal `last_included` timestamp. The cronjob only fetches fresh Google Places details for toilets whose `last_included` is newer than their `last_discovered` timestamp, and then marks them as discovered. This avoids wasting Google Places API quota on unused areas.

When the cronjob updates an existing toilet it re-crawls the website and refreshes owner, coordinates, status, opening hours, address, website and the boolean property flags. Values that a user has manually edited through `POST /toilet/add`, `PATCH /toilet/{id}/update` or `POST /toilet/add-properties/{toiletId}` are protected and will not be overwritten.

## Opening hours

v1 returned opening hours as a plain text block (newline-separated weekday strings). v2 parses and returns Google Places `periods`:

```json
{
  "opening_hours": {
    "periods": [
      {"open": {"day": 1, "time": "0900"}, "close": {"day": 1, "time": "1800"}}
    ]
  }
}
```

`open_timestamp` and `close_timestamp` are calculated from these periods on the server.

## Place object changes

The `Place` resource now returns the stored Google Places data plus a few helper fields. The `place_id` is the unique key. The endpoint paths dropped `/cache` because this is now the authoritative place store, not a stale cache.

## Property types

When posting properties via `POST /toilet/add-properties/{toiletId}`, use the following type names:

| Type | Value format |
|---|---|
| `place_opening_hours` | JSON-encoded Google `periods` array |
| `website` | URL string |
| `address` | Address string |

Legacy type name `opening_times` is no longer used.

## Upload flow

The upload flow is unchanged, but a photo upload no longer sets `type = 'forall'`. Instead, calling `POST /uploadSubmit/{toiletId}` transitions the toilet to `status = 'active'`.

## Error responses

Validation errors return `422 Unprocessable Entity` with a JSON body containing the failed fields. All other errors return `400 Bad Request` or the appropriate HTTP status with a JSON body:

```json
{
  "error": "Human-readable message"
}
```

The legacy plain-text error responses are replaced by JSON.

## Admin qualify / delete links

Admin links remain functionally unchanged and still use the legacy MD5 hash mechanism. Frontend clients do not normally interact with these endpoints directly.

## Removed features

- `POST /places/add_unknown` — unknown-place registration is removed.
- OpenAI-based opening-hours text parsing — opening hours now rely exclusively on Google Places `periods` data.
