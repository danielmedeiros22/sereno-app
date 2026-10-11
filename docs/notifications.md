# Central de notificações

Acesse **Ajustes → Notificações** ou o **sino no painel**, que mostra a quantidade de alertas ativos. A legenda expansível **Como funcionam os alertas** explica a central dentro do aplicativo.

A central está ligada aos dados financeiros disponíveis. Os avisos desaparecem quando os dados deixam de justificar o alerta: por exemplo, marcar uma conta como paga remove o aviso correspondente. Não existe histórico de notificações nem uma ação de dispensar que esconda problemas ainda ativos.

## Avisos e preferências

- **Teto mensal:** considera somente saídas do mês atual, independentemente do filtro Dia/Semana/Mês do painel.
- **Orçamentos por categoria:** compara as saídas do mês atual com o teto de cada categoria, incluindo categorias personalizadas.
- **Percentual:** escolha 50%, 75%, 90% (padrão) ou 100% para começar a avisar. Atingir e ultrapassar o teto têm rótulos próprios.
- **Contas recorrentes:** mostra contas ativas não pagas, atrasadas, vencendo hoje ou dentro da antecedência escolhida: no dia, 1, 3 (padrão), 7 ou 14 dias antes. Cada conta gera no máximo um aviso, priorizando o vencimento não pago mais próximo já calculado.
- **Preferências:** cada tipo pode ser desativado. São persistidas neste dispositivo, separadas entre visitante e cada conta; não sincronizam entre aparelhos.

Os alertas são calculados, não gravados numa nova tabela. Contas autenticadas usam os lançamentos, teto, orçamentos, recorrências e pagamentos já sincronizados. Visitantes usam dados locais. Offline, o cálculo usa a última cópia disponível; não comprova que outro dispositivo já enviou suas alterações. Use **Atualizar alertas** para buscar dados da conta. O envio/recebimento automático existente continua ativo enquanto os providers estão em uso. Ao voltar ao aplicativo ou mudar o dia, os avisos são recalculados.

Esta fase é uma central dentro do Sereno: não pede permissão do sistema, não envia push, e-mail ou notificações com o app fechado, nem acrescenta serviços pagos.

## Datas e compatibilidade das contas

O formulário de conta recorrente permite informar **Primeiro vencimento**. A lista oferece **Editar conta recorrente** para ajustar uma regra existente sem duplicá-la. O campo opcional `firstDueDate` integra o JSON da recorrência e acompanha a sincronização existente de `account_financial_records`; não exige migração do banco.

Mensais antigas continuam usando o dia do mês salvo, sem data inicial obrigatória. Os dias 29–31 são ajustados ao último dia dos meses menores. Regras semanais, quinzenais e anuais antigas sem data inicial mostram **Defina a data**: o aplicativo não inventa uma data a partir do dia do mês. Semanal/quinzenal usam intervalos de 7/14 dias a partir da data informada; anual usa mês/dia dessa data.

O pagamento continua sendo registrado **por conta e mês**, conforme o comportamento existente. Marcar uma conta semanal ou quinzenal como paga quita os avisos daquela conta naquele mês, não uma ocorrência individual. O cálculo mensal não recupera dívidas de meses anteriores; para semanal/quinzenal considera a ocorrência mais recente até hoje e as próximas na janela. A marcação de pagamento não cria lançamento automaticamente.

## Validação

`test/notification_center_test.dart` cobre percentuais, mês atual, categorias, desativação de tipos, contas pagas/inativas, atrasos, antecedência, virada do ano, fim de mês/ano bissexto, periodicidades, compatibilidade de registros antigos, persistência e isolamento das preferências, legenda e layout de 390 px, além do estado de erro sem falso aviso de que está tudo em dia. Integra o conjunto de testes direcionados do build da Vercel.

Não foi realizado teste manual em aparelhos Android/iOS nem de sincronização desta central em dois aparelhos físicos.
