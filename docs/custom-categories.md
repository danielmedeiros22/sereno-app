# Categorias personalizadas — Android, iOS e Web

Em **Novo orçamento**, **Nova movimentação** ou **Nova conta recorrente**, escolha **Adicionar categoria**. Informe o nome e um emoji e confirme em **Criar categoria**. A categoria criada fica selecionada e aparece nos demais formulários do mesmo tipo. Categorias de entrada e saída são separadas; orçamento e recorrência usam categorias de saída.

O campo Emoji aceita o teclado nativo, colagem e sugestões dentro do aplicativo. O armazenamento é texto Unicode, sem imagens, arquivos locais ou código específico de plataforma. Bandeiras, tons de pele e sequências de família permanecem inteiros. O desenho pode variar entre Android, iOS e navegador; emojis muito recentes dependem das fontes disponíveis no aparelho. Não é necessário instalar um teclado ou serviço pago. Nomes vazios, nomes com mais de 40 caracteres e duplicatas do mesmo tipo são recusados. Espaços repetidos e diferenças entre maiúsculas/minúsculas não criam categorias duplicadas. A versão atual permite criar categorias; não renomeia nem remove definições já utilizadas.

## Sincronização da conta

- **Categorias:** catálogo próprio por conta, compartilhado entre os três seletores. Nome e emoji ficam também registrados nos lançamentos, orçamentos e recorrências, preservando a identificação do registro.
- **Lançamentos:** continuam usando a sincronização existente de `account_transactions`, incluindo nome e emoji personalizados.
- **Orçamentos:** teto por categoria, alterações e exclusões passam a sincronizar. Gastos são calculados a partir dos lançamentos da conta autenticada, sem misturar dados antigos de visitante. O orçamento é mensal e usa o mês atual, independentemente do filtro Dia/Semana/Mês do dashboard.
- **Recorrências:** definição da conta, ativação/desativação, exclusão e marcação/desmarcação de pagamento por mês sincronizam. Marcar como paga mantém o comportamento existente: não cria uma movimentação automaticamente.
- **Offline:** gravação no dispositivo e fila persistente por conta. Envio após alteração, ao atualizar/retomar o dashboard, recuperar a conexão e a cada 30 segundos enquanto os providers estiverem ativos. Outro dispositivo recebe os dados após sincronizar; não é atualização instantânea via Realtime. A última gravação aceita prevalece nos conflitos. Uma resposta atrasada não apaga uma edição local pendente.
- **Visitante:** categorias, registros e pagamentos permanecem no dispositivo. Login não importa automaticamente dados sem dono. Cada conta possui cache próprio.

Os registros antigos de orçamento e recorrência continuam preservados nas chaves locais. Na respectiva tela, **Importar dados antigos** permite copiá-los para a conta após confirmação, sem apagar os originais nem substituir registros existentes. Recorrências importam também as marcações de pagamento disponíveis neste dispositivo. Repita a importação apenas nos aparelhos que tenham dados antigos a aproveitar. Exclusões sincronizadas mantêm marcadores para evitar ressurreição de registros; a importação respeita esses marcadores.

**Limpar registros** também usa a exclusão sincronizada das recorrências e preserva a revisão e confirmação existentes. Diário financeiro continua local. Categorias, teto mensal e orçamentos permanecem fora dessa limpeza, conforme a seleção já apresentada ao usuário.

## Banco e segurança

Migração aditiva `supabase/migrations/20261011003004_custom_categories_and_related_records.sql`, gerada pela CLI e aplicada ao projeto existente `rdlofauxvsbdytvvmlzd`. Não cria projetos, branches, buckets ou serviços pagos. Não altera as tabelas antigas de categorias/transações/espaços.

`account_categories` usa chave `(user_id, type, name_key)`. `account_financial_records` usa `(user_id, kind, id)` para orçamento, recorrência e pagamento. Ambas têm RLS, políticas de SELECT/INSERT/UPDATE restritas a `auth.uid()`, grants explícitos e timestamp do servidor. Anônimo não possui acesso; DELETE físico não é concedido. Registros financeiros são excluídos por tombstones com payload nulo. Chaves secretas não entram no cliente.

## Validação e limites

`test/custom_categories_test.dart` cobre Unicode composto, validação, duplicatas, cache por conta, dispositivo limpo, retomada offline, pagamento/desmarcação, exclusão, respostas atrasadas, preservação após revisão e integração dos seletores. Os testes direcionados existentes também são executados no build da Vercel.

`supabase/tests/custom_categories_and_records.sql` valida leitura/gravação do dono, isolamento de outra identidade, bloqueio anônimo, impossibilidade de transferir propriedade, rejeição de valores inválidos, timestamp e exclusão lógica. Executado com rollback, sem criar/modificar contas nem deixar registros de teste. O advisor não apontou novos problemas de segurança; há um aviso anterior de proteção contra senhas vazadas desativada, sem alteração nesta tarefa.

A conferência física de ponta a ponta em Android e iOS continua pendente. Testes automatizados usam transporte simulado para dois dispositivos e verificações de permissões no banco real; não equivalem a teste manual nos aparelhos.
