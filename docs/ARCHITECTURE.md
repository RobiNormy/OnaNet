# OnaNet architecture

## Flutter

Flutter uses a feature-first structure. A feature owns its screens, state,
services, and domain objects instead of placing every screen or service in a
global folder.

### `lib/core`

Code that can be used by multiple features:

- `models/` — application-wide value objects
- `navigation/` — stable navigation identifiers
- `network/` — shared API client configuration
- `theme/` — OnaNet theme tokens and persisted theme state
- `utils/` — platform and formatting helpers
- `widgets/` — genuinely reusable UI components

Core must not import a feature.

### `lib/features`

- `admin/` — platform control panel
- `auth/` — authentication data and presentation
- `customer/` — discovery, search, saved providers and customer account
- `installations/` — installation request data and screens
- `provider_dashboard/` — provider operations and analytics
- `provider_registration/` — provider onboarding wizard
- `subscriptions/` — billing and subscription client operations

A feature may import `core` and another feature's public screen or service when
there is a real workflow dependency. New code should remain inside the feature
that owns it.

## FastAPI

The backend keeps HTTP, business logic, and persistence separate:

- `backend/api` authenticates requests, validates inputs and shapes responses.
- `backend/services` owns workflows and third-party integrations.
- `backend/repositories` and `backend/providers/repos` own persistence queries.
- `backend/schemas` and `backend/providers/schema` own API/domain schemas.
- `backend/core` owns environment configuration and security infrastructure.
- `backend/db` owns connection lifecycle and database infrastructure.

Route handlers should not contain payment secrets or trust client-provided
prices. Webhooks must be authenticated and fulfillment must be idempotent.

## Naming

- Dart files use `snake_case.dart`.
- Screens end in `_screen.dart`.
- API clients and persistence classes end in `_service.dart` or `_store.dart`.
- Python modules use `snake_case.py`.
- Environment variables use uppercase names and never enter version control.
