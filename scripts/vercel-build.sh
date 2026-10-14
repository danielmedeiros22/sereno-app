#!/usr/bin/env bash
set -euo pipefail

# Match the SDK used to validate the published app; never follow moving stable.
flutter_version="3.44.9"
flutter_revision="6b182d2c7585eba26d4edce0f97630effd256c33"
sdk_dir="$PWD/.flutter-sdk"

if [[ ! -d "$sdk_dir/.git" ]]; then
  git clone --depth 1 --branch "$flutter_version" \
    https://github.com/flutter/flutter.git "$sdk_dir"
fi
if [[ "$(git -C "$sdk_dir" rev-parse HEAD)" != "$flutter_revision" ]]; then
  echo "Unexpected Flutter revision. Check the pinned SDK before deploying." >&2
  exit 1
fi

export PATH="$sdk_dir/bin:$PATH"
export CI=true
flutter config --no-analytics --enable-web
flutter pub get --enforce-lockfile
flutter test --no-pub test/monthly_limit_service_test.dart test/monthly_limit_sheet_test.dart test/transaction_sync_service_test.dart test/transaction_sync_banner_test.dart test/record_deletion_test.dart test/clear_records_screen_test.dart test/app_locale_test.dart test/app_page_transitions_test.dart test/reports_test.dart test/avatar_service_test.dart test/profile_summary_test.dart test/custom_categories_test.dart test/notification_center_test.dart test/settings_logout_test.dart test/profile_name_test.dart
flutter analyze --no-pub lib/app/app.dart lib/app/theme/app_theme.dart lib/app/theme/app_page_transitions.dart lib/features/auth/presentation lib/app/router/app_router.dart lib/features/reports lib/features/notifications lib/core/services/account_record_store.dart lib/core/services/financial_record_sync_provider.dart lib/features/budget lib/features/recurring lib/features/transactions/presentation/screens/transaction_form_screen.dart lib/features/transactions/presentation/widgets/category_picker.dart lib/features/transactions/presentation/widgets/financial_sync_banner.dart lib/features/dashboard lib/features/settings lib/features/transactions/data lib/features/transactions/presentation/providers lib/features/transactions/presentation/widgets/transaction_sync_banner.dart test/monthly_limit_service_test.dart test/monthly_limit_sheet_test.dart test/transaction_sync_service_test.dart test/transaction_sync_banner_test.dart test/record_deletion_test.dart test/clear_records_screen_test.dart test/app_locale_test.dart test/app_page_transitions_test.dart test/reports_test.dart test/avatar_service_test.dart test/profile_summary_test.dart test/custom_categories_test.dart test/notification_center_test.dart test/settings_logout_test.dart test/profile_name_test.dart
flutter build web --release --no-pub --no-wasm-dry-run

# Flutter distributes this file publicly. Only client parameters belong here.
test -f build/web/assets/.env
grep -q '^MONTHLY_LIMIT_CLOUD_SYNC=true' build/web/assets/.env
grep -q '^TRANSACTION_CLOUD_SYNC=true' build/web/assets/.env
