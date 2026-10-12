# Demo signing key (public, not secret)

`demo.keystore` signs **only the demo APK** — the build made from
`preview/main_preview.dart` with the Gradle property `jdDemo=true`
(`ORG_GRADLE_PROJECT_jdDemo=true` in `.github/workflows/build.yml`). Because
every CI run signs the demo with this same key, testers can install a newer
demo APK over an older one instead of uninstalling first.

| | |
|---|---|
| File | `android/app/demo-signing/demo.keystore` (PKCS12) |
| Store password | `jetalpur-demo` |
| Key alias | `jd-demo` |
| Key password | `jetalpur-demo` |
| Certificate | `CN=Jetalpur Dham Demo (not for production)`, valid until 2054 |

**Never use this key for the real app.** It is committed to a public
repository, so anyone can sign an APK with it. The demo build also gets its
own package name (`com.jetalpurdham.app.demo`) and launcher name
("Jetalpur Dham Demo"), so it installs next to the real app and can never
replace it. Production builds are signed with the upload key from
`android/key.properties` (see docs/FIREBASE_SETUP.md, step 14), which must
never be committed.

The key was created with:

```sh
keytool -genkeypair -keystore demo.keystore -storetype PKCS12 \
  -storepass jetalpur-demo -keypass jetalpur-demo -alias jd-demo \
  -keyalg RSA -keysize 2048 -validity 10000 \
  -dname "CN=Jetalpur Dham Demo (not for production), O=Jetalpur Dham demo build"
```
