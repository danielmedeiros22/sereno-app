# Limpeza de registros

Em **Ajustes → Limpar registros**, escolha entradas, saídas, diário financeiro, contas recorrentes ou **Selecionar tudo**. Essa seleção reúne essas quatro categorias; não redefine tema, autenticação, teto mensal ou orçamentos por categoria.

Escolha **Dia**, **Mês**, **Ano** ou **Todo o histórico**. A data de referência considera o dia completo, o mês completo ou o ano completo, conforme o filtro. Lançamentos usam sua data financeira; diário usa a data da anotação; recorrências usam a data de criação da regra. Excluir uma regra recorrente remove também sua programação futura, não apenas uma ocorrência.

**Revisar exclusão** carrega os dados e mostra as quantidades por categoria e o período. A exclusão só é liberada após marcar **Autorizo a exclusão dos registros acima** e digitar exatamente **EXCLUIR**. Cancelar não apaga nada. Não existe desfazer no aplicativo.

## Alcance e sincronização

- Entradas e saídas pertencem à conta atual ou ao modo visitante. Para contas com sincronização ativa, a revisão exige uma leitura remota bem-sucedida. Sem conexão, nenhuma categoria daquela operação é excluída antes da revisão.
- A exclusão de lançamentos da conta se propaga aos demais dispositivos por marcadores de exclusão, utilizando as regras de acesso já existentes. Não exige migração nem DELETE físico no Supabase. Se a conexão cair após confirmar, a pendência fica gravada localmente para o próximo envio.
- Diário e recorrências são locais ao navegador/dispositivo, conforme a arquitetura atual, e não são separados por conta. A confirmação informa esse alcance. Suas exclusões não se propagam a outro aparelho.
- Dados de visitantes, outras contas e cópias antigas sem dono não são apagados pela limpeza dos lançamentos da conta atual. Os IDs excluídos não podem ser reimportados sobre os marcadores da mesma conta.
- A operação considera somente os registros exibidos na revisão. Novos registros e registros alterados entre a revisão e a gravação local são preservados. Cada categoria é persistida em uma gravação; não há transação única entre categorias. Em falha parcial, a mensagem informa as exclusões concluídas e pede uma nova revisão.

## Validação

Testes com armazenamento simulado cobrem limites de dia/mês/ano, cancelamento, autorização e palavra de confirmação, isolamento entre contas, persistência da exclusão e propagação dos marcadores, preservação de novos registros, edições posteriores e preferências não selecionadas. Não executar a limpeza dos registros reais do usuário para testar a interface.
