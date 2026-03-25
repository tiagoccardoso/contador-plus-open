**Como aplicar**

Copie as pastas `lib/src/features/podcast/` e `lib/src/features/podcast/auth/` deste patch para o seu projeto,
substituindo os arquivos existentes.

**Dependências (obrigatórias):**
  flutter pub add flutter_web_auth_2
  flutter pub add flutter_secure_storage
  flutter pub add url_launcher

**AndroidManifest.xml (Callback do OAuth)**
Dentro de <application> adicione:
  <activity android:name="com.linusu.flutter_web_auth_2.CallbackActivity" android:exported="true">
    <intent-filter android:label="flutter_web_auth_2">
      <action android:name="android.intent.action.VIEW" />
      <category android:name="android.intent.category.DEFAULT" />
      <category android:name="android.intent.category.BROWSABLE" />
      <data android:scheme="seu.esquema.redirect" />
    </intent-filter>
  </activity>

Troque `seu.esquema.redirect` pelo scheme do seu SPOTIFY_REDIRECT_URI (ex.: contadorplus).

**iOS (Info.plist)**
<key>CFBundleURLTypes</key>
<array>
  <dict>
    <key>CFBundleURLSchemes</key>
    <array>
      <string>seu.esquema.redirect</string>
    </array>
  </dict>
</array>

**O que foi consertado**
- `spotify_pkce.dart`: imports dos pacotes, uso de `FlutterSecureStorage` como `final`, remoção de `preferEphemeral`.
- `episodes_tab.dart`: data como String (YYYY-MM-DD), abertura externa via `url_launcher` recebendo `String`.
- `widgets/episodes_tab.dart`: removido `_error`, padronizado para `FutureBuilder` com tratamento de erro; `onTap` envia `String`.


Atualização: spotify_public_api.dart agora usa Client Credentials direto no app, lendo SPOTIFY_CLIENT_ID, SPOTIFY_CLIENT_SECRET e SPOTIFY_SHOW_ID do .env.
