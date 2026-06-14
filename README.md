# v2rayN Flutter

This is a Flutter conversion scaffold for the customized WPF project at:

`D:\v2ray\v2rayN\v2rayN\v2rayN`

The original WPF code is not modified.

## Current Scope

Converted active flow:

- Login / register / reset password
- Main shell
- Lines list
- Personal center
- Settings
- About
- Share gift / activity
- Trade manager
- DNS settings dialog
- Change password dialog

The original v2rayN core control is represented by a service interface placeholder. The WPF project depends on `ServiceLib`; a production Flutter conversion still needs a native bridge or a backend API for starting/stopping proxy cores and applying system proxy settings.

## Run

Flutter SDK is not installed on this machine yet. After installing Flutter:

```powershell
cd D:\v2ray\v2rayn_flutter
flutter create --platforms=windows .
flutter run -d windows
```

Backend API default:

```text
http://127.0.0.1:8080
```
