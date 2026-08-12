# Sereno — App Financeiro

Boilerplate Flutter funcional. Roda Android, iOS e Web em uma base.

## 🚀 Setup em 5 passos

### 1. Instale o Flutter

Se ainda não tem: https://docs.flutter.dev/get-started/install
Confirme com:
```bash
flutter --version    # deve ser 3.24+
flutter doctor       # resolva os pontos vermelhos
```

### 2. Extraia este projeto

```bash
unzip sereno_app.zip
cd sereno_app
flutter pub get
```

### 3. Configure o Supabase

Você precisa ter aplicado a migração SQL (`supabase-migration.sql`) num projeto Supabase.

Copie o exemplo e preencha:
```bash
cp .env.example .env
```

Edite `.env`:
```
SUPABASE_URL=https://xxxxx.supabase.co
SUPABASE_ANON_KEY=eyJ...
GOOGLE_WEB_CLIENT_ID=xxx.apps.googleusercontent.com
```

Pegue os valores em: Supabase Dashboard → Project Settings → API.

### 4. Configure OAuth

Siga o `guia-aplicacao-supabase.md` para:
- Habilitar Google no Supabase (Auth → Providers)
- Habilitar Apple no Supabase (opcional, só iOS)
- Configurar deep link `io.sereno.app://login-callback`

### 5. Rode!

```bash
# Web
flutter run -d chrome

# Android (com celular ou emulador conectado)
flutter run -d android

# iOS (macOS necessário)
flutter run -d ios
```

Vai abrir a **Welcome screen** → toque em "Começar" → **Login** → entre com Google ou Apple → cai no **Dashboard**.

## 📁 O que já está funcionando

- ✅ Tema Light + Dark com Material 3 e a paleta oficial
- ✅ Tipografia Inter + Fraunces via Google Fonts
- ✅ Router com auth guard automático (GoRouter + Riverpod)
- ✅ Login Google e Apple via Supabase OAuth
- ✅ Sessão persistida (não desloga ao fechar o app)
- ✅ Dashboard com saudação personalizada + a **orbe do Termômetro** funcionando
- ✅ Bottom sheet de "Meus Limites" com slider animado, toggle de precisão (R$10/R$100), botões ± e input direto
- ✅ Cores da orbe reagem em tempo real ao percentual
- ✅ Logout funcional

## 🚧 O que virá em próximos incrementos

- CRUD de transações (formulário completo com GPS)
- Espaços compartilhados
- Sincronização offline (Drift + fila local)
- Categorias e orçamento
- Cartão de crédito e parcelamento
- Diário financeiro
- Contas recorrentes

## 📂 Estrutura

```
lib/
├── main.dart              # entrypoint
├── app/
│   ├── app.dart           # MaterialApp raiz
│   ├── theme/             # cores, tipografia, tema light/dark
│   └── router/            # GoRouter + auth guard
├── core/
│   ├── constants/         # AppConstants
│   └── network/           # SupabaseService
└── features/
    ├── auth/              # welcome, login, providers
    ├── dashboard/         # tela principal + TermometroOrb widget
    └── settings/          # ajustes e logout
```

## 🐛 Troubleshooting

**"Missing required arguments: url, anonKey"**
→ Você não configurou o `.env`. Volte no passo 3.

**Google sign-in erro "PlatformException(sign_in_failed, ...)"**
→ Você precisa configurar o OAuth Client ID no Google Cloud Console pro seu package name/SHA-1. Veja o guia.

**Apple sign-in erro no Android**
→ Normal — Apple sign-in não funciona nativamente no Android. O botão aparece só em iOS/macOS/Web.

**"MissingPluginException" ao rodar Web**
→ Rode `flutter clean && flutter pub get` e tente de novo.

## 🎨 Testando o Termômetro

Após logar, toque na orbe pequena no canto superior direito do Dashboard. Abre um bottom sheet com o slider. Arraste, use os botões ± ou digite direto no valor. A orbe grande dentro do sheet e a pequena do dashboard reagem em tempo real.

Pra testar visualmente os 5 estados sem gastar de verdade, você pode temporariamente editar `_spent` no `dashboard_screen.dart`:

```dart
double _spent = 500;   // Serena
double _spent = 2500;  // Atenta
double _spent = 3100;  // Alerta
double _spent = 3400;  // Preocupada
double _spent = 4200;  // Estourou
```

E hot reload.
