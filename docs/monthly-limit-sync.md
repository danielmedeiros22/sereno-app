# Sincronização do teto mensal

Implementação com publicação autorizada em 09/10/2026. A tabela foi criada no projeto Supabase atual `rdlofauxvsbdytvvmlzd` em 09/10/2026, após autorização do usuário. A sincronização está ativada no `.env` local; o build inclui essa flag para ativar a sincronização.

## Estado verificado

- Tabela `monthly_spending_limits` criada com RLS ativo, três políticas de acesso e leitura anônima recusada.
- Testes reais no SQL Editor passaram: escrita/leitura da própria conta, bloqueio de outra identidade e de visitante, faixa de valores e timestamp gerado no servidor. O teste usou uma conta existente apenas dentro da transação e terminou com rollback, sem criar contas nem deixar valores de teste no banco.
- Os 15 testes direcionados passaram; análise sem problemas. O build Web anterior passou. A ativação da flag exige reiniciar o processo Flutter para recarregar `.env`.
- URL e chave pública existentes não foram alteradas. Backup do `.env` anterior em `_backup_prototipo_20261008/.env.before-monthly-limit-sync`.
- Falta o teste manual final de login e sincronização entre dois navegadores/dispositivos. A conferência autenticada em dois dispositivos deve ser realizada com a mesma conta.

## Ambiente de desenvolvimento

1. Criar um projeto Supabase separado, destinado a desenvolvimento. Não usar o projeto atual de produção para estes testes.
2. No SQL Editor desse projeto, executar `supabase/migrations/202610090001_monthly_spending_limits.sql` uma única vez. A migração é transacional e adiciona uma tabela, políticas RLS e um trigger; não altera tabelas existentes.
3. Configurar o login Google/Apple no projeto de desenvolvimento, permitindo `http://localhost:5000` nos redirects. O restante do Sereno também depende das tabelas existentes do aplicativo; este arquivo cria somente a estrutura do teto mensal.
4. Fazer uma cópia privada do `.env` atual antes de apontar o ambiente local ao projeto de desenvolvimento. Não enviar o arquivo a terceiros. Atualizar localmente `SUPABASE_URL` e a chave pública de cliente (`SUPABASE_ANON_KEY`), sem usar service-role.
5. Acrescentar ao `.env` local: `MONTHLY_LIMIT_CLOUD_SYNC=true`. Sem essa opção, o novo recurso não faz requisições ao Supabase. O modo visitante permanece local em qualquer configuração.
6. Reiniciar o Flutter (recarregar somente o código não recarrega o asset `.env`). Executar `flutter run -d web-server --web-hostname=localhost --web-port=5000` e abrir o endereço no navegador habitual.

A seção acima descreve como configurar um ambiente separado caso necessário no futuro. No ambiente atual, não reaplicar a migração: a tabela já existe. Somente a flag foi acrescentada ao `.env`; configurações da Vercel e demais tabelas permanecem preservadas. A flag serve para ativação controlada do novo recurso, não para desativar os outros serviços Supabase existentes.

## Comportamento

- Um teto por conta; representa o limite mensal recorrente, não uma configuração diferente para cada mês.
- R$ 3.500 é somente o padrão quando não há teto salvo. Não é enviado automaticamente à nuvem.
- Cache e pendências separados por ID da conta. Trocar de conta recria o estado e não transfere valores de uma conta ou do visitante para outra.
- O valor local antigo não tinha identificação do dono. Ele permanece disponível ao visitante; uma conta autenticada deve buscar seu teto remoto ou informar o valor novamente.
- A edição fica como rascunho até tocar em Salvar alteração e confirmar o valor atual e o novo teto. Cancelar não grava. Após confirmar, o valor é salvo localmente primeiro. A sincronização é agendada após 600 ms sem novas edições, ao abrir o dashboard, retomar o app, recuperar conexão e a cada 30 s enquanto o dashboard está ativo.
- Sem rede ou em caso de falha, a pendência continua salva após reiniciar. A interface mostra que a sincronização está pendente e oferece nova tentativa em caso de erro.
- Conflitos: vence o último envio aceito pelo servidor. Uma edição offline enviada mais tarde pode substituir uma edição feita antes em outro dispositivo. `updated_at` é atribuído pelo servidor, não pelo relógio do cliente.
- Respostas atrasadas não substituem uma edição local posterior nem limpam sua pendência.
- Não é necessário habilitar Realtime: o outro dispositivo carrega o valor ao abrir/retomar ou no próximo intervalo de atualização.
- O valor fica no navegador para visitantes; limpar dados do site ou usar perfil temporário remove o cache local.

## Verificação

Executar `flutter test --no-pub test/monthly_limit_service_test.dart test/monthly_limit_sheet_test.dart` e analisar os arquivos alterados. Os testes locais usam um remoto simulado: validam isolamento, retomada offline, segundo dispositivo, conflitos e requisições em andamento; não comprovam acesso ao banco real.

Depois de aplicar a migração no projeto de desenvolvimento, executar `supabase/tests/monthly_spending_limits.sql` no SQL Editor. O teste verifica permissões de visitante, isolamento entre duas contas, faixa de valores e timestamp do servidor; usa dados temporários e termina com rollback. Usar exclusivamente um projeto de testes.

Teste manual final em dois perfis de navegador:

1. Entrar com a mesma conta nos dois perfis; definir R$ 6.200 no primeiro e aguardar confirmação de sincronização.
2. Abrir/retomar o segundo; conferir R$ 6.200. Alterar ali e conferir o primeiro.
3. Interromper a rede, editar, fechar a guia, reabrir e restabelecer a rede; conferir a pendência e a sincronização.
4. Entrar com outra conta; ela não deve ver o teto anterior. Voltar à primeira e conferir seu teto.
5. Conferir visitante e login separadamente. Não deve haver importação automática do teto do visitante.

Em 09/10/2026, o usuário autorizou publicar após incluir a caixa de confirmação. A flag de sincronização deve acompanhar o build publicado.
