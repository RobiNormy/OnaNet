# OnaNet

OnaNet is a Wi-Fi discovery marketplace for comparing internet providers,
coverage areas, packages, and installation options. The mobile application is
built with Flutter and the API is built with FastAPI and PostgreSQL/Supabase.

## Project layout

```text
ona_net/
├── lib/
│   ├── core/                 # Shared theme, networking, models and utilities
│   ├── features/             # Feature-first Flutter application modules
│   │   ├── admin/
│   │   ├── auth/
│   │   ├── customer/
│   │   ├── installations/
│   │   ├── provider_dashboard/
│   │   ├── provider_registration/
│   │   └── subscriptions/
│   ├── images/               # Bundled application assets
│   └── main.dart             # Flutter entry point
├── backend/
│   ├── api/                  # FastAPI route modules
│   ├── core/                 # Configuration, Firebase and security
│   ├── db/                   # Database pool, base model and indexes
│   ├── providers/            # Provider domain models, schemas and repositories
│   ├── repositories/         # Shared persistence repositories
│   ├── schemas/              # Shared request/response schemas
│   ├── services/             # Business logic and external integrations
│   └── sql/                  # Explicit SQL migrations and indexes
├── test/                     # Flutter unit and widget tests
├── main.py                   # FastAPI/Railway entry point
├── requirements.txt          # Python dependencies
└── pubspec.yaml              # Flutter dependencies and assets
```

See [docs/ARCHITECTURE.md](docs/ARCHITECTURE.md) for module ownership and
dependency rules.

## Run the API

Copy `.env.example` to `.env`, then add your database, Firebase, Supabase,
SMS, and payment credentials. Never commit `.env`.

```sh
python -m uvicorn main:app --host 0.0.0.0 --port 8000
```

The production API is:

```text
https://onanet-production.up.railway.app
```

Railway forwards this HTTPS address to the backend's internal port. Do not add
`:8080` to the public URL.

## Run Flutter

Install packages and run the default production-backed build:

```sh
flutter pub get
flutter run
```

For an Android emulator using the local API:

```sh
flutter run --dart-define=ONA_NET_API_BASE_URL=http://10.0.2.2:8000
```

For a physical phone, bind FastAPI to `0.0.0.0` and use your computer's LAN
address:

```sh
flutter run \
  --dart-define=ONA_NET_API_BASE_URL=http://192.168.1.23:8000
```

The phone and computer must be on the same network and the firewall must allow
port `8000`. An HTTPS tunnel such as ngrok can also be used for webhook testing.

## Quality checks

```sh
python -m compileall -q backend main.py
flutter analyze
flutter test
```

## Secrets

Keep Firebase service credentials, Supabase service keys, database URLs,
payment-provider secret keys, and webhook secrets in `.env` locally and in
Railway variables for production. Only public client configuration belongs in
Flutter or web source code.
