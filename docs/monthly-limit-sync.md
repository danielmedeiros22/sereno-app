# Teto mensal: persistência, confirmação e sincronização

Estado documentado em 09/10/2026. A correção está publicada em [Sereno](https://sereno-app-beta.vercel.app/).

## Uso e valores permitidos

1. Abrir **Meus limites** pelo indicador do dashboard.
2. Digitar um valor entre **R$ 1 e R$ 50.000**, incluindo centavos com vírgula ou ponto.
3. Selecionar **Salvar alteração** e conferir o teto atual e o novo na caixa de confirmação.
4. Selecionar **Confirmar** para gravar. Digitar, cancelar ou fechar o rascunho não grava.

R$ 1 e R$ 50 são aceitos. O mínimo anterior de R$ 100 foi removido tanto da validação Flutter quanto da restrição do banco. R$ 0,99, zero e valores negativos não são aceitos; o máximo permanece R$ 50.000.

R$ 3.500 é apenas o padrão na ausência de um valor salvo e nunca é enviado automaticamente ao Supabase. O teto é uma configuração mensal recorrente da conta, sem histórico separado por mês.

## Persistência e sincronização

- Visitantes: SharedPreferences no navegador/dispositivo atual. Usar o mesmo perfil, host e porta para recuperar o valor. Limpar os dados do site ou usar perfil temporário remove esse cache.
- Contas autenticadas: cache e pendências separados por ID da conta, sincronizados com `public.monthly_spending_limits`. O teto do visitante não é importado automaticamente para uma conta.
- Depois da confirmação, o valor é salvo localmente primeiro. A sincronização é agendada após 600 ms, ao abrir o dashboard, retomar o app, recuperar conexão e a cada 30 segundos enquanto o dashboard estiver ativo.
- Sem rede ou diante de falha, a alteração permanece pendente após reiniciar. A interface informa a situação e oferece nova tentativa quando há erro.
- O outro dispositivo carrega o valor ao abrir/retomar o dashboard ou na próxima atualização periódica. Não depende de Realtime.
- Em conflito, vence a última gravação aceita pelo servidor, inclusive se uma edição offline for enviada depois. `updated_at` usa o relógio do servidor.
- Respostas atrasadas não sobrescrevem uma edição local posterior nem limpam sua pendência.
- A chave local antiga sem identificação do dono só é reaproveitada para visitantes.

A opção pública `MONTHLY_LIMIT_CLOUD_SYNC=true` ativa o novo acesso ao Supabase para contas autenticadas. Sem ela, o teto permanece local. Alterar `.env` exige reiniciar o Flutter ou gerar novo build para recarregar o asset; hot reload não basta. URL e chave pública anteriores foram preservadas. Nunca colocar service-role ou segredos de servidor nesse arquivo, pois ele é distribuído como asset Web.

## Banco e migrações

Projeto atual: `rdlofauxvsbdytvvmlzd`. As duas migrações abaixo já foram aplicadas em 09/10/2026; conferir o esquema antes de executar novamente.

| Migração | Efeito |
| --- | --- |
| [202610090001_monthly_spending_limits.sql](../supabase/migrations/202610090001_monthly_spending_limits.sql) | Cria a tabela do teto, RLS, três políticas por usuário e trigger de timestamp. |
| [202610090002_monthly_limit_minimum_one.sql](../supabase/migrations/202610090002_monthly_limit_minimum_one.sql) | Reduz o mínimo de R$ 100 para R$ 1, mantendo o máximo de R$ 50.000. |

A segunda migração não altera valores salvos nem políticas de acesso. A tabela tem `user_id` como chave primária vinculada a `auth.users`, `amount numeric(12,2)` e `updated_at`. Usuários autenticados podem ler, inserir e atualizar somente a própria linha; acesso anônimo é recusado.

Para um ambiente de desenvolvimento novo, preparar também as tabelas existentes do aplicativo, aplicar as duas migrações em ordem, configurar OAuth e permitir `http://localhost:5000` nos redirects. Usar os parâmetros públicos desse ambiente no `.env` local e ativar a flag. O SQL de teste que cria usuários fictícios deve ser executado exclusivamente em um projeto de testes.

## Execução local

No PowerShell, a partir da pasta do projeto:

```powershell
flutter pub get
flutter run -d web-server --web-hostname=localhost --web-port=5000
```

Abrir `http://localhost:5000` no navegador habitual, fora do modo anônimo. Manter o mesmo perfil, host e porta; o launcher `-d chrome` pode criar um perfil temporário e não é referência confiável para persistência entre execuções. Manter o terminal aberto e usar `q` para encerrar. Se a porta estiver ocupada, encerrar a execução anterior.

## Validação realizada

```powershell
flutter test --no-pub test/monthly_limit_service_test.dart test/monthly_limit_sheet_test.dart
flutter analyze --no-pub lib/features/dashboard test/monthly_limit_service_test.dart test/monthly_limit_sheet_test.dart
flutter build web --release --no-pub
```

- **18 testes direcionados aprovados**: restauração, faixa válida, isolamento de contas/visitante, pendência offline, conflitos, respostas atrasadas, confirmação/cancelamento, falha de gravação e valores de R$ 1 e R$ 50. Os testes de serviço usam um remoto simulado.
- Análise dos arquivos alterados sem problemas; build Web release concluído.
- Banco real: leitura/gravação do dono, isolamento de outra identidade, recusa a visitante, faixa e timestamp verificados. O teste da correção aprovou R$ 1 e R$ 50 e recusou R$ 0,99. Todos os valores de teste foram revertidos por rollback; nenhuma conta foi criada ou modificada.
- Navegador: persistência após reload como visitante na prévia e confirmação de R$ 1 disponível no site público. O valor de demonstração em produção foi cancelado.
- O hash de `main.dart.js` servido pelo domínio público correspondeu ao build local da correção. O asset público de configuração também foi conferido na publicação anterior, sem exibir valores de chaves.

Isso não representa aprovação da suíte inteira: `test/widget_test.dart` é um exemplo antigo e referencia `MyApp`, inexistente.

### Verificação manual pendente

A sincronização autenticada de ponta a ponta em dois navegadores/dispositivos ainda precisa ser validada:

1. Entrar com a mesma conta nos dois dispositivos, definir um teto no primeiro, confirmar e aguardar a sincronização.
2. Abrir/retomar o dashboard no segundo e conferir o valor; alterar ali, confirmar e conferir o primeiro.
3. Testar uma alteração offline, fechar/reabrir e restabelecer a conexão para conferir a retomada.
4. Trocar de conta e conferir isolamento. Conferir também que o teto de visitante não é importado automaticamente.

## Publicação

Referência da publicação manual validada em 09/10/2026, antes da integração automática:

| Item | Referência |
| --- | --- |
| Site | https://sereno-app-beta.vercel.app/ |
| Commit do código publicado | `29ab169258eb326c1027346e7f5df27082af0b3a` |
| Branch do código | `align/published-90ec94a` |
| Deploy | `BQmNePeGhUmuCKjSogTygm9mrVYr` |
| URL do deploy | https://sereno-l8rfvfthn-dandev3.vercel.app |
| Painel do deploy | https://vercel.com/dandev3/sereno-app/BQmNePeGhUmuCKjSogTygm9mrVYr |
| PR de integração | https://github.com/danielmedeiros22/sereno-app/pull/1 |

### Integração GitHub → Vercel

O PR #1 integra o código e a documentação à `main`. A configuração versionada em `vercel.json` define `bash scripts/vercel-build.sh` como comando de build, dispensa instalação Node e publica apenas `build/web`.

O script instala Flutter 3.44.9, confere a revisão `6b182d2c7585eba26d4edce0f97630effd256c33`, resolve dependências com `--enforce-lockfile`, executa os 18 testes direcionados e a análise dos arquivos do teto e compila a aplicação em release. Também exige o asset de configuração e a flag de sincronização. Qualquer falha interrompe a implantação.

- Push/merge na `main`: build de produção; o domínio público passa para a nova versão somente depois de aprovado.
- Push em outras branches: prévia para revisão, preservando o domínio público.
- Alterações locais sem commit/push não são publicadas.

A referência corrente deve ser conferida no [painel Vercel](https://vercel.com/dandev3/sereno-app) junto ao commit da [branch main](https://github.com/danielmedeiros22/sereno-app/tree/main). A tabela anterior registra a publicação manual da correção, não os deploys posteriores da integração.

Para uma prévia manual, executar `vercel link --project sereno-app --scope dandev3 --yes` e `vercel deploy --yes --scope dandev3` na raiz do repositório. A compilação ocorre na Vercel. O fluxo principal de produção é o merge na `main`; `--prod` exige autorização. O procedimento antigo de enviar `build/web` pela CLI foi substituído pelo build a partir dos arquivos fonte.

`.vercelignore` exclui tokens locais, metadados da Vercel, SDK temporário, build local, backups e capturas de validação do envio pela CLI. A saída pública é exclusivamente `build/web`. A CLI pode criar `.env.local` com token efêmero: nunca versionar, exibir ou enviar esse arquivo. `assets/.env` é público e deve conter somente parâmetros de cliente e a flag de sincronização.

Se o navegador continuar mostrando a versão anterior após a publicação, usar **Ctrl + F5**.
