# ona_net

Ona Net wifi discovery

## Running With A Local API On A Physical Phone

Start FastAPI so other devices on your Wi-Fi can reach it:

```sh
python -m uvicorn main:app --host 0.0.0.0 --port 8000
```

Find your computer's LAN IP address:

```sh
hostname -I
```

Then run Flutter with that IP address. Do not use `localhost` or `127.0.0.1`
on a physical phone, because those point back to the phone itself:

```sh
flutter run --dart-define=ONA_NET_API_BASE_URL=http://192.168.1.23:8000
```

Replace `192.168.1.23` with your computer's actual Wi-Fi IP. The phone and
computer must be on the same network, and your firewall must allow port `8000`.

## Getting Started

This project is a starting point for a Flutter application.

A few resources to get you started if this is your first Flutter project:

- [Learn Flutter](https://docs.flutter.dev/get-started/learn-flutter)
- [Write your first Flutter app](https://docs.flutter.dev/get-started/codelab)
- [Flutter learning resources](https://docs.flutter.dev/reference/learning-resources)

For help getting started with Flutter development, view the
[online documentation](https://docs.flutter.dev/), which offers tutorials,
samples, guidance on mobile development, and a full API reference.
