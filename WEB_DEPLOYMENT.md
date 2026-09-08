# Web deployment

Build with an explicit API URL when the API is not served through the same
origin as the Flutter app:

```powershell
flutter build web --release --dart-define=API_BASE_URL=https://api.example.gov/api
```

For browser reverse geocoding, optionally configure a same-origin or CORS-safe
HTTPS endpoint:

```powershell
--dart-define=REVERSE_GEOCODING_URL=https://api.example.gov/api/reverse-geocode
```

The endpoint receives `lat` and `lng` query parameters and must return JSON
with `road`, `districtCity`, and `province`. When it is omitted or unavailable,
the timestamp retains the browser coordinates and labels the address as a
fallback; location capture itself remains usable.

## Backend contract

- Serve the Web app and API over HTTPS. Browser camera and geolocation are not
  available from an insecure deployed origin.
- If API and Web origins differ, allow the exact Web origin (not `*` in
  production), `Authorization`, `Content-Type`, and `Idempotency-Key` request
  headers, and `GET`, `POST`, `PUT`, `DELETE`, and `OPTIONS` methods.
- Accept `multipart/form-data` on the lembur create/update endpoints and keep
  bearer authentication on preflighted requests. This client does not use
  cookies or `withCredentials`.
- Make remote evidence-image URLs HTTPS and browser-readable from the Web
  origin. A protected image route needs a URL/authentication approach that a
  browser image element can use; do not weaken browser security to load it.
- Configure upload size limits to at least 10 MB per photo. The app limits
  selected/processed photos to 10 MB.

The Laravel source found in the sibling `SWP_SIMDATUK` workspace is not the
LemburNakIT API: it has no `lembur` route or photo fields. Its current CORS
configuration is permissive (`allowed_origins = ['*']`) and should be replaced
with the deployed Web origins for a production API rather than copied blindly.
