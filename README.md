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

## Teto mensal — atualização de 09/10/2026

- Aceita valores **a partir de R$ 1**, incluindo R$ 50, centavos e valores acima de R$ 50.000. O limite anterior de R$ 50.000 foi removido do aplicativo e do banco. Exemplo: **75.000,00**.
- Para alterar: abra **Meus limites**, digite o valor, selecione **Salvar alteração** e confirme. A caixa mostra o teto atual e o novo; digitar ou cancelar não salva.
- O valor confirmado permanece após fechar e reabrir o navegador. Visitantes salvam neste navegador; contas autenticadas sincronizam com o Supabase e mantêm alterações pendentes quando estão offline.
- Sem teto salvo, a tela inicia em **R$ 0,00** (teto ainda não definido). Esse estado não é enviado à nuvem. Tetos já salvos, inclusive R$ 3.500, são preservados; para definir um teto, informe um valor a partir de R$ 1, salve e confirme. A legenda em Meus limites explica sua finalidade.
- Em **Ajustes**, use **Sair da conta**, logo abaixo do perfil, para encerrar a sessão neste dispositivo sem apagar registros nem sair dos outros aparelhos. Falhas de saída mostram uma mensagem para tentar novamente.

A correção está publicada em [sereno-app-beta.vercel.app](https://sereno-app-beta.vercel.app/). Se a versão anterior continuar aparecendo, recarregue com **Ctrl + F5**.

**Validação:** 18 testes direcionados aprovados, análise dos arquivos alterados sem problemas, build Web release concluído e código compilado do site comparado com o build local. O teste real no Supabase aprovou R$ 1 e R$ 50 e recusou R$ 0,99; os valores de teste foram revertidos. A conferência manual da mesma conta em dois dispositivos ainda está pendente.

A branch `main` reúne o código e a documentação integrados pelo [PR #1](https://github.com/danielmedeiros22/sereno-app/pull/1). A Vercel compila, testa e publica automaticamente os commits enviados à `main`; outras branches geram prévias. Consulte [a documentação técnica do teto mensal](docs/monthly-limit-sync.md) para migrações, sincronização, testes e referência do deploy.

## Categorias personalizadas e sincronização — 10/10/2026

Use **Adicionar categoria** nos formulários de orçamento, movimentação e conta recorrente. Escolha o emoji pelo teclado do Android/iOS, cole na Web ou use as sugestões. A categoria é compartilhada entre os seletores do mesmo tipo, e nome/emoji acompanham os registros.

Contas autenticadas sincronizam **categorias, lançamentos, orçamentos e recorrências**, incluindo pagamentos das recorrências. Alterações offline ficam pendentes; visitantes continuam locais. Orçamentos/recorrências antigos do dispositivo podem ser copiados para a conta com **Importar dados antigos**, após confirmação. Consulte [funcionamento, segurança e validação](docs/custom-categories.md).

## Central de notificações — 10/10/2026

Acesse **Ajustes → Notificações** ou o **sino no painel** para acompanhar teto mensal, orçamentos por categoria e contas próximas do vencimento ou atrasadas. A legenda **Como funcionam os alertas** explica que os avisos acompanham os dados e desaparecem quando deixam de se aplicar — por exemplo, após marcar uma conta como paga.

Escolha os tipos de aviso, o percentual do teto e a antecedência das contas. As preferências ficam neste dispositivo, separadas por conta; os alertas usam os dados financeiros já sincronizados. Esta fase funciona dentro do app, sem notificações com ele fechado. Veja [regras, datas e limites](docs/notifications.md).

## O que já funciona

- **Relatórios** — em Ajustes, comparação de entradas/saídas, gastos por categoria e evolução por dia/hora, com filtros Dia/Semana/Mês compartilhados com o painel e dados do mesmo fluxo sincronizado. Veja [funcionamento e limites](docs/reports.md). A análise por espaço depende da implementação dos espaços.

- **Login com Google e Apple** — autenticação via Supabase OAuth, sem senha
- **Modo visitante** — use sem criar conta, dados ficam salvos no dispositivo
- **Dashboard** — saldo atual, entradas/saídas do mês, orbe do Termômetro
- **Termômetro Sereno** — orbe animada que muda cor e expressão conforme os gastos (5 estados)
- **Formulário de transações** — registre entradas e saídas com valor, categoria, data e descrição
- **Categorias com emojis** — 22 categorias padrão e categorias personalizadas compartilhadas entre os formulários
- **Lista de movimentações** — agrupada por data (Hoje, Ontem, etc), swipe pra deletar
- **Saldo calculado automaticamente** — entradas − saídas do mês
- **GPS automático** — captura localização ao registrar transação (reverse geocoding via Nominatim)
- **Mapa com pin** — ajuste visual da localização no mapa (OpenStreetMap + flutter_map)
- **Edição manual de endereço** — corrija o endereço digitando direto
- **Contas recorrentes** — aluguel, internet, assinaturas com frequência, vencimento e status (paga/pendente/atrasada)
- **Diário financeiro** — reflexões com 8 humores (emoji), 8 tags contextuais e texto livre
- **Orçamento por categoria** — teto mensal por categoria com barra de progresso e cores do termômetro
- **Tema Light + Dark** — Material 3, segue preferência do sistema
- **Auth guard** — redirecionamento automático por estado de autenticação
- **Sessão persistida** — não desloga ao fechar o app
- **Deploy web** — acessível em qualquer navegador via Vercel
- **Banco de dados** — Supabase (Postgres) com Row Level Security
- **Sync offline** — fila automática para lançamentos, teto, categorias, orçamentos e recorrências ao voltar online; diário permanece local
- **Indicador de sync** — mostra status no dashboard (sincronizando, pendente, erro, sincronizado)
- **Detecção automática de rede** — connectivity_plus monitora e sincroniza quando volta online

## Roadmap

| Versão | Status | Features |
|--------|--------|----------|
| **V1** | 🚧 Em desenvolvimento | Cartão de crédito, parcelamento, sync offline |
| **V2** | 📋 Planejado | Compartilhamento de espaços, mapa de gastos, comprovantes/anexos |
| **V3** | 📋 Planejado | OCR de notas, busca avançada, IA financeira |
| **V4** | 📋 Planejado | QR Code, Pix, Open Finance |
| **V1** | ✅ Completo | Login, modo visitante, transações, GPS, mapa, categorias, orçamento, contas recorrentes, diário financeiro, sync offline |

O V1 do Sereno está completo com tudo funcionando na web:

✅ Login (Google, Apple, Visitante)
✅ Dashboard com Termômetro Sereno
✅ CRUD de transações com categorias padrão e personalizadas
✅ GPS automático + mapa com pin
✅ Contas recorrentes
✅ Diário financeiro
✅ Orçamento por categoria
✅ Sync offline
✅ Deploy no Vercel
✅ Documentação no GitHub

Perfeito! O APK fica pra quando quiser — o comando é simples quando estiver pronto:

powershell
flutter build apk --release

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

## Estrutura do Projeto

```
lib/
├── main.dart
├── app/
│   ├── app.dart
│   ├── theme/
│   │   ├── app_colors.dart
│   │   ├── app_typography.dart
│   │   └── app_theme.dart
│   └── router/
│       └── app_router.dart
├── core/
│   ├── constants/app_constants.dart
│   ├── network/supabase_client.dart
│   └── services/
│       ├── guest_service.dart
│       ├── location_service.dart
│       └── map_picker_screen.dart
└── features/
    ├── auth/
    │   └── presentation/
    │       ├── providers/auth_provider.dart
    │       ├── screens/welcome_screen.dart
    │       ├── screens/login_screen.dart
    │       └── widgets/oauth_buttons.dart
    ├── dashboard/
    │   └── presentation/
    │       ├── screens/dashboard_screen.dart
    │       └── widgets/
    │           ├── termometro_orb.dart
    │           └── guest_banner.dart
    ├── transactions/
    │   ├── data/
    │   │   ├── transaction_model.dart
    │   │   ├── local_transaction_service.dart
    │   │   └── default_categories.dart
    │   └── presentation/
    │       ├── providers/transaction_provider.dart
    │       ├── screens/transaction_form_screen.dart
    │       └── widgets/transaction_tile.dart
    ├── recurring/
    │   ├── data/
    │   │   ├── recurring_model.dart
    │   │   └── local_recurring_service.dart
    │   └── presentation/
    │       ├── providers/recurring_provider.dart
    │       └── screens/
    │           ├── recurring_list_screen.dart
    │           └── recurring_form_screen.dart
    ├── journal/
    │   ├── data/
    │   │   ├── journal_model.dart
    │   │   └── local_journal_service.dart
    │   └── presentation/
    │       ├── providers/journal_provider.dart
    │       └── screens/
    │           ├── journal_list_screen.dart
    │           └── journal_form_screen.dart
    ├── budget/
    │   ├── data/
    │   │   ├── budget_model.dart
    │   │   └── local_budget_service.dart
    │   └── presentation/
    │       ├── providers/budget_provider.dart
    │       └── screens/
    │           ├── budget_list_screen.dart
    │           └── budget_form_screen.dart
    └── settings/
        └── presentation/
            └── screens/settings_screen.dart
```

## Setup

### Pré-requisitos

- [Flutter SDK](https://docs.flutter.dev/get-started/install) 3.24+
- Conta no [Supabase](https://supabase.com)
- Projeto no [Google Cloud Console](https://console.cloud.google.com) com OAuth

### Referência do login Google do Sereno

> **Sincronização por conta:** entradas, saídas, teto mensal, categorias personalizadas, orçamentos e recorrências usam o Supabase. Entre com a mesma conta nos dispositivos e confirme a importação dos registros antigos que deseja aproveitar em cada um deles. Consulte [sincronização dos lançamentos](docs/transaction-sync.md) e [categorias e registros relacionados](docs/custom-categories.md).

> **Conta Google com acesso confirmado: `danyellmedeiros22@gmail.com` (Danyell Medeiros).**
> O projeto existente é **App financeiro**. Use essa conta e esse projeto para consultar a configuração OAuth do Sereno.

| Identificação | Valor verificado em 09/10/2026 |
| --- | --- |
| Conta Google com acesso | `danyellmedeiros22@gmail.com` |
| Nome do projeto | **App financeiro** |
| Organização exibida | `danyellmedeiros22-org` |
| Número do projeto | `956821237585` |
| ID do projeto | `project-1777b660-d79a-4253-9eb` |
| Painel | [Abrir o projeto no Google Cloud](https://console.cloud.google.com/welcome?project=project-1777b660-d79a-4253-9eb) |

**Como a correspondência foi conferida:** o número do projeto no Google Cloud coincide com o prefixo numérico do `GOOGLE_WEB_CLIENT_ID` configurado no `.env` local. A sessão Google consultada estava conectada à conta acima. A página IAM apresentou erro de carregamento; portanto, o acesso foi confirmado, mas o papel de proprietária não foi verificado.

O fluxo de login Google já existe no aplicativo, em `lib/features/auth/presentation/providers/auth_provider.dart`. Na Web, ele usa o provedor Google do Supabase; no mobile, usa `google_sign_in` com `GOOGLE_WEB_CLIENT_ID`. Para conferir as credenciais do fluxo Web, consulte **Authentication > Sign In / Providers > Google** no [projeto Supabase atual](https://supabase.com/dashboard/project/rdlofauxvsbdytvvmlzd).

Esta verificação foi somente de leitura: nenhuma credencial, permissão ou configuração de autenticação foi alterada. Não registrar client secrets, tokens ou chaves privadas nesta documentação nem no repositório.

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

```powershell
flutter pub get
flutter run -d web-server --web-hostname=localhost --web-port=5000
```

Abra `http://localhost:5000` manualmente no navegador habitual e mantenha o terminal aberto. Para testar persistência, use o mesmo perfil, host e porta, sem modo anônimo. O launcher `-d chrome` pode usar um perfil temporário. Para encerrar, pressione `q` no terminal. Se a porta 5000 estiver ocupada, encerre a execução anterior antes de iniciar novamente. O OAuth local precisa permitir `http://localhost:5000` nos redirects do Supabase.

### Deploy (Vercel)

A integração GitHub → Vercel é definida em [`vercel.json`](vercel.json) e [`scripts/vercel-build.sh`](scripts/vercel-build.sh). O script usa Flutter **3.44.9**, revisão fixa, respeita `pubspec.lock`, executa os testes direcionados do teto e dos lançamentos e a análise dos arquivos relacionados e gera `build/web` em release. Se uma etapa falhar, a publicação não avança.

- **`main`**: cada push/merge inicia um deploy de produção. A nova versão entra no domínio público depois do build aprovado.
- **Outras branches/PRs**: geram uma URL de prévia para revisão.
- **Edição local**: não publica por si só. É preciso commit e push ou merge na branch correspondente.

Para solicitar uma prévia manual pela CLI, usar a raiz do repositório, com os arquivos fonte:

```powershell
vercel link --project sereno-app --scope dandev3 --yes
vercel deploy --yes --scope dandev3
```

Usar `--prod` somente para uma publicação autorizada. O fluxo principal de produção é o merge na `main`; não executar esses comandos a partir de `build/web` com a configuração nova.

O diretório publicado é somente `build/web`. O asset `assets/.env` contém parâmetros públicos de cliente e `MONTHLY_LIMIT_CLOUD_SYNC=true`. `.env.local`, `.vercel/`, backups e arquivos locais estão excluídos do upload por `.vercelignore`. Nunca inserir service-role ou segredos de servidor nos assets Web. Consulte [a documentação de publicação](docs/monthly-limit-sync.md#publicação).

## Cartão Minhas finanças

Na tela inicial, o cartão mostra a foto da conta, o período selecionado (Dia/Semana/Mês), a quantidade de lançamentos e uma barra segmentada de uso do teto mensal. Para trocar ou restaurar a foto, toque no avatar do cartão de perfil em **Ajustes**. A foto personalizada é privada e sincroniza pela conta. O botão **Editar nome** nos cartões da tela inicial e de Ajustes salva um nome de exibição sincronizado, sem alterar o e-mail ou o login Google; a saudação também acompanha a mudança. Saldo, movimentações, barra e **Meus limites** compartilham o período e os valores atualizados. Veja [perfil, privacidade e funcionamento](docs/profile-summary.md).

## Limpeza de registros

Em **Ajustes → Limpar registros**, escolha entradas, saídas, diário, contas recorrentes ou selecione tudo, por dia, mês, ano ou todo o histórico. A revisão mostra as quantidades; excluir exige autorização marcada e a palavra **EXCLUIR**. A ação não pode ser desfeita no aplicativo. Lançamentos e recorrências da conta sincronizam a exclusão; diário permanece local. Tema, login, categorias, teto mensal e orçamentos são preservados. Veja [alcance dos filtros e confirmação](docs/record-deletion.md).

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
