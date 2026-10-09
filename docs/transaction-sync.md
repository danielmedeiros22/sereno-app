# Sincronização dos lançamentos entre dispositivos

## Diagnóstico da versão publicada

Em 09/10/2026, a versão publicada em `main` (`88e5910`) sincroniza somente o teto mensal. O login identifica a conta, mas os lançamentos são gravados exclusivamente na chave `local_transactions` do SharedPreferences. O serviço antigo `SyncService` não está conectado ao fluxo de gravação e sua leitura da nuvem apenas registra contagens, sem atualizar os lançamentos exibidos. Isso explica por que um lançamento feito no celular não aparece na Web, mesmo com a mesma conta Google.

## Funcionamento

- `TransactionSyncService`: cache e fila persistente separados por ID da conta. Visitantes continuam locais. Falha de rede preserva os registros e as alterações pendentes.
- `SupabaseTransactionRemote`: envia e busca dados da tabela isolada `account_transactions`, com verificação da identidade antes/depois das requisições e leitura paginada.
- Sincronização ao carregar, criar/editar/excluir, recuperar conexão, retomar o aplicativo e a cada 30 segundos com o app aberto. Saldo e movimentações usam os dados recuperados.
- Exclusões usam uma marca persistente na nuvem para se propagarem sem reaparecerem em outro dispositivo. Conflitos no mesmo lançamento seguem a última gravação aceita pelo servidor.
- Aviso no dashboard distingue sincronização, sucesso, erro e recurso desativado, com opção de tentar novamente.
- Registros antigos sem dono **não são enviados automaticamente**. O botão de importação pede confirmação da conta atual, preserva a cópia original e usa os IDs existentes para evitar duplicações. Faça a importação em cada dispositivo com registros antigos, após a ativação.

## Ativação autorizada em 09/10/2026

O usuário autorizou aplicar a tabela, validar e publicar. A tabela e a função não existiam e foram criadas em 09/10/2026 no projeto atual. Os testes SQL passaram com rollback: acesso do dono, isolamento de outra identidade, recusa de visitante, rejeição de valor negativo, timestamp do servidor e recusa de exclusão física pelo cliente. A conferência posterior mostrou RLS ativo, três políticas e zero registros de teste persistentes. `TRANSACTION_CLOUD_SYNC=true` foi acrescentado ao `.env`, preservando os demais parâmetros.

A prévia `https://sereno-46l5v10gf-dandev3.vercel.app` passou pelos 28 testes, análise e build release e ficou Ready na Vercel. O aplicativo local autenticado enviou um lançamento temporário de R$ 0,01; o recebimento foi conferido no banco real. A publicação segue a integração do PR #3 à `main` pelo fluxo automático da Vercel. O domínio público é `https://sereno-app-beta.vercel.app/`.

Procedimento para futuras instalações:

1. Conferir se `public.account_transactions` já existe no projeto Supabase `rdlofauxvsbdytvvmlzd`; comparar o esquema antes de executar qualquer migração.
2. Aplicar `supabase/migrations/202610090003_account_transactions.sql` somente se a tabela não existir. A migração adiciona tabela, três políticas de RLS para o próprio usuário e timestamp do servidor; não altera tabelas existentes. Visitantes não têm acesso remoto e exclusões físicas não são permitidas ao cliente.
3. Validar leitura/gravação do dono, isolamento de outra identidade, recusa de visitante e restrições do payload. Não executar testes que criam usuários fictícios no banco publicado.
4. Acrescentar `TRANSACTION_CLOUD_SYNC=true` ao `.env` público do cliente, preservando os parâmetros anteriores. Sem essa opção, o acesso remoto fica desativado.
5. Gerar uma prévia, validar com a mesma conta em duas sessões e somente então integrar/publicar com autorização. Alterações em `main` publicam automaticamente.

O recurso cobre **entradas e saídas**. Diário, orçamentos por categoria, recorrências e espaços compartilhados não passam a sincronizar por esta entrega. Não é necessário ativar faturamento do Google Cloud para autenticação.

## Verificações locais

```powershell
flutter test --no-pub test/monthly_limit_service_test.dart test/monthly_limit_sheet_test.dart test/transaction_sync_service_test.dart test/transaction_sync_banner_test.dart
```

Os testes dos lançamentos cobrem persistência offline, isolamento entre contas/visitante, importação confirmada, duplicação, exclusão, leitura em dispositivo limpo, gravações concorrentes e edição durante envio. Testes locais usam armazenamento e acesso remoto simulados; não comprovam por si só a configuração de RLS no banco real nem o funcionamento da versão publicada.

Validação em 09/10/2026: **28 testes direcionados aprovados**, análise dos arquivos relacionados sem problemas e build Web release concluído. `supabase/tests/account_transactions.sql` passou no banco real usando uma conta existente, sem alterar a conta e revertendo todos os registros de teste por rollback.
