# Relatórios

Em **Ajustes → Relatórios**, consulte entradas, saídas, saldo do período, distribuição das saídas por categoria e evolução dos gastos. As barras por categoria mostram valores em reais e percentuais das saídas. A evolução mostra cada dia da semana/mês ou cada hora do dia; toque nas barras para consultar o valor e deslize horizontalmente para ver o período completo.

Os filtros **Dia, Semana e Mês** e a data de referência são compartilhados com o painel. No filtro mensal, escolha qualquer dia do mês desejado; a semana começa na segunda-feira. Alterar o período é apenas uma consulta local. Não há agrupamento por espaço: os espaços ainda não estão implementados nem vinculados aos lançamentos.

Os cálculos usam `transactionListProvider`, o mesmo fluxo de lançamentos da conta/visitante, sem gravar uma cópia dos resultados. Inclusões, edições, exclusões e dados recebidos pela sincronização recalculam os relatórios. Categorias personalizadas preservam seu nome/emoji; nomes equivalentes usam a normalização já aplicada aos orçamentos. Os totais são agregados em centavos. Contas futuras, recorrências não lançadas e diário não entram nos valores. Não há exportação nesta primeira versão.

Contas usam os lançamentos sincronizados existentes; visitantes usam os registros locais. O estado da sincronização aparece na tela. **Atualizar** ou puxar para baixo relê e sincroniza os lançamentos; sem conexão, os resultados refletem os dados disponíveis localmente. Estado de carregamento, falha de leitura e período vazio têm indicação própria. Preferências de período continuam locais e os gráficos não exigem nova tabela, permissão ou biblioteca externa.

Testes cobrem limites de período, semana entre anos, fevereiro bissexto, horas, centavos, categorias personalizadas, consistência entre barras/totais e atualização da interface em largura de celular. Testes simulados não substituem conferência física entre dispositivos.
