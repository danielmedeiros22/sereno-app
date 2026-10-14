# Espaços individuais

Em **Ajustes → Meus espaços**, use **Pessoal, Casa, Empresa e Viagem**, crie espaços com nome/emoji e edite o nome/emoji dos espaços existentes. Pessoal é permanente e não pode ser renomeado. Esta etapa não permite compartilhar espaços com outras contas nem excluir espaços.

O seletor **Espaço** aparece no cartão do painel e em Relatórios. **Todos os espaços** preserva a visão consolidada; selecionar um espaço filtra lista, contagem, entradas, saídas, saldo e gráficos. Período e espaço são compartilhados entre essas duas telas, mas são preferências locais de consulta: não movem registros e são reiniciados quando a conta muda.

No formulário de **Nova movimentação**, o espaço selecionado no painel é sugerido; na visão Todos, o padrão é Pessoal. Escolha outro antes de salvar. Para reorganizar um lançamento existente, toque nele no painel, escolha o destino e confirme. Cancelar não grava. Nome, valor, categoria, descrição, data, localização e identidade do lançamento são preservados. Se a conta ou o registro mudar durante a revisão, reabra o diálogo. Não há movimentação automática de registros feita pela migração.

## Compatibilidade e sincronização

Registros anteriores sem `spaceId` continuam em **Pessoal**, por compatibilidade na leitura; não são regravados em lote. Os lançamentos passam a transportar `spaceId` e `spaceName` no JSON já sincronizado em `account_transactions`. O ID do espaço não muda ao renomeá-lo. O nome no catálogo prevalece na interface; o nome guardado no lançamento serve de alternativa caso ele chegue antes do catálogo.

Os quatro espaços padrão têm IDs fixos e estão disponíveis sem gravação automática. Personalizações e novos espaços usam `account_financial_records`, tipo `space`, com o mesmo cache/fila por conta, RLS e sincronização existente (ao abrir, alterações, conexão e polling de 30 segundos). O painel também atualiza os espaços ao retomar/Atualizar; Relatórios e Meus espaços têm atualização manual. Pendências offline são preservadas. Cada conta acessa apenas os próprios registros; visitantes guardam espaços e lançamentos neste navegador/dispositivo. Dados de visitante não são adotados pela conta automaticamente. Atualize o aplicativo em todos os aparelhos para usar os novos campos.

Migração aditiva `20261014232543_individual_spaces.sql` amplia os tipos aceitos e valida o payload do espaço, preservando as regras anteriores, os dados, as três políticas e os privilégios. O teste `supabase/tests/individual_spaces.sql` usa rollback, sem criar contas ou persistir espaços de teste.

## Alcance financeiro

**O teto mensal e o termômetro continuam sendo da conta inteira**, considerando os gastos do período consultado em todos os espaços. A legenda do cartão e a referência em Meus limites explicam esse alcance. Filtrar Casa não transforma o teto global em um teto da Casa. Os orçamentos por categoria e os alertas também permanecem globais. Não há tetos, recorrências ou diário separados por espaço nesta etapa.

**Limpar registros abrange todos os espaços** da conta/visitante atual, de acordo com tipos e datas revisados; o filtro de espaço do painel não limita a limpeza. O catálogo de espaços é preservado. A tela avisa esse alcance antes da confirmação.

Os testes cobrem registros antigos, preservação dos dados ao mover, catálogo offline, dispositivo com cache limpo, renomeação com ID estável, isolamento por conta/visitante, transporte do vínculo em lançamentos, exclusão sincronizada, criação/cancelamento/edição e seleção no formulário, além da igualdade dos totais entre painel e relatórios. Conferência física em dois dispositivos continua separada dos testes simulados.
