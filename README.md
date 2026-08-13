<div align="center">

# 💜 Sereno

**Suas finanças com calma.**

Controle financeiro pessoal e compartilhado — Web, Android e iOS em uma base Flutter.

![Flutter](https://img.shields.io/badge/Flutter-3.24+-02569B?logo=flutter&logoColor=white)
![Dart](https://img.shields.io/badge/Dart-3.4+-0175C2?logo=dart&logoColor=white)
![Supabase](https://img.shields.io/badge/Supabase-Auth%20%2B%20DB-3FCF8E?logo=supabase&logoColor=white)
![License](https://img.shields.io/badge/license-MIT-blue)

🌐 **[Acessar o app](https://sereno-app-beta.vercel.app)**

</div>

---

## Sobre

Sereno é um app de controle financeiro que organiza suas finanças em **Espaços** — Pessoal, Casa, Empresa, Viagem — com sincronização offline, orçamento por categoria e um indicador visual exclusivo chamado **Termômetro Sereno** que mostra em tempo real como seus gastos estão em relação ao teto que você definiu.

## O que já funciona

- **Login com Google e Apple** — autenticação via Supabase OAuth, sem senha
- **Modo visitante** — use sem criar conta, dados ficam salvos no dispositivo
- **Dashboard** — saldo atual, entradas/saídas do mês, orbe do Termômetro
- **Termômetro Sereno** — orbe animada que muda cor e expressão conforme os gastos (5 estados)
- **Formulário de transações** — registre entradas e saídas com valor, categoria, data e descrição
- **22 categorias com emojis** — 15 de despesa (Alimentação, Transporte, etc) e 7 de receita (Salário, Freelance, etc)
- **Lista de movimentações** — agrupada por data (Hoje, Ontem, etc), swipe pra deletar
- **Saldo calculado automaticamente** — entradas − saídas do mês
- **Tema Light + Dark** — Material 3, segue preferência do sistema
- **Auth guard** — redirecionamento automático por estado de autenticação
- **Sessão persistida** — não desloga ao fechar o app
- **Deploy web** — acessível em qualquer navegador via Vercel
- **Banco de dados** — Supabase (Postgres) com Row Level Security
- **GPS automático** — captura localização ao registrar transação (reverse geocoding via Nominatim)
- **Mapa com pin** — ajuste visual da localização no mapa (OpenStreetMap + flutter_map)
- **Edição manual de endereço** — corrija o endereço digitando direto

## Roadmap

| Versão | Status | Features |
|--------|--------|----------|
| **V1** | 🚧 Em desenvolvimento | GPS, cartão de crédito, parcelamento, contas futuras, recorrências, diário financeiro, sync offline |
| **V2** | 📋 Planejado | Compartilhamento de espaços, mapa de gastos, comprovantes/anexos |
| **V3** | 📋 Planejado | OCR de notas, busca avançada, IA financeira |
| **V4** | 📋 Planejado | QR Code, Pix, Open Finance |

## Stack

| Camada | Tecnologia |
|--------|-----------|
| Frontend | Flutter (Web + Android + iOS) |
| State Management | Riverpod |
| Navegação | GoRouter |
| Backend | NestJS + Prisma (planejado) |
| Auth | Supabase OAuth (Google + Apple) |
| Banco de dados | Supabase (Postgres) + SQLite local (Drift) |
| Mapas | OpenStreetMap + flutter_map + Nominatim |
| Tipografia | Inter (UI) + Fraunces (display) via Google Fonts |

## Paleta de Cores

| Cor | Hex | Uso |
|-----|-----|-----|
| 🔵 Primária | `#3B82F6` | Azul confiança — botões, links |
| 🟢 Secundária | `#14B8A6` | Verde-água — entradas, estado calmo |
| 🟠 Alerta | `#F97316` | Âmbar — saídas, alertas |
| 🟣 Acento | `#8B5CF6` | Lilás — destaques, gradientes |

## Estrutura do Projeto

lib/
├── main.dart
├── app/
│ ├── app.dart
│ ├── theme/
│ │ ├── app_colors.dart
│ │ ├── app_typography.dart
│ │ └── app_theme.dart
│ └── router/
│ └── app_router.dart
├── core/
│ ├── constants/app_constants.dart
│ ├── network/supabase_client.dart
│ └── services/guest_service.dart
└── features/
├── auth/
│ └── presentation/
│ ├── providers/auth_provider.dart
│ ├── screens/welcome_screen.dart
│ ├── screens/login_screen.dart
│ └── widgets/oauth_buttons.dart
├── dashboard/
│ └── presentation/
│ ├── screens/dashboard_screen.dart
│ └── widgets/
│ ├── termometro_orb.dart
│ └── guest_banner.dart
├── transactions/
│ ├── data/
│ │ ├── transaction_model.dart
│ │ ├── local_transaction_service.dart
│ │ └── default_categories.dart
│ └── presentation/
│ ├── providers/transaction_provider.dart
│ ├── screens/transaction_form_screen.dart
│ └── widgets/transaction_tile.dart
└── settings/
└── presentation/
└── screens/settings_screen.dart

## Setup

### Pré-requisitos

- [Flutter SDK](https://docs.flutter.dev/get-started/install) 3.24+
- Conta no [Supabase](https://supabase.com)
- Projeto no [Google Cloud Console](https://console.cloud.google.com) com OAuth

### 1. Clone e configure

```bash
git clone https://github.com/danielmedeiros22/sereno-app.git
cd sereno-app
cp .env.example .env
# Preencha .env com suas credenciais
flutter pub get
```

### 2. Configure o Supabase

1. Crie um projeto no Supabase (South America - São Paulo)
2. Aplique a migração SQL em **SQL Editor** (`docs/supabase-migration.sql`)
3. Ative Google em **Authentication > Sign In / Providers**
4. Em **URL Configuration**, adicione seu domínio

### 3. Rode

```bash
flutter run -d chrome --web-port=5000
```

### Deploy (Vercel)

```bash
flutter build web
Copy-Item .env build\web\assets\.env -Force
cd build\web
vercel --prod
```

## Termômetro Sereno

O recurso mais distintivo do app. Uma orbe animada que reage aos seus gastos:

| Estado | Faixa | Cor | Comportamento |
|--------|-------|-----|---------------|
| Serena | 0-50% | `#14B8A6` | Respira devagar |
| Atenta | 50-75% | `#3B82F6` | Respira normal |
| Alerta | 75-90% | `#EAB308` | Respira rápido |
| Preocupada | 90-100% | `#F97316` | Pulsa forte |
| Estourou | >100% | `#EF4444` | Vibra + shake |

Implementado como `CustomPainter` com `AnimationController` — sem dependências externas.

## Licença

MIT

---

<div align="center">
Feito com 💜 para quem quer paz financeira.
</div>