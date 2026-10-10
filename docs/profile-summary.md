# Cartão Minhas finanças

O cartão da tela inicial mostra a foto, o nome da conta, o período consultado, a quantidade de lançamentos e uma barra de dez segmentos com o percentual do teto utilizado. Escolha **Dia**, **Semana** ou **Mês** e toque na data para consultar outro período. O padrão é o mês atual; a semana vai de segunda a domingo, inclusive quando atravessa meses ou anos. O calendário usa português brasileiro. Saldo, entradas, saídas, lista, contagem e barras usam a mesma seleção e as datas locais do dispositivo.

O teto é a configuração mensal atual da conta, não um histórico de tetos por mês. Nos filtros de dia e semana, a barra compara os gastos desse período com o **teto mensal**, como informa a legenda; não são criados tetos diários ou semanais. A seleção é apenas um filtro local de consulta, sem modificar os registros sincronizados.

## Foto

Toque na foto/ícone de câmera para **Escolher imagem** ou **Usar foto da conta Google**. Sem foto, aparecem as iniciais. Falhas ao carregar a imagem também usam essa alternativa.

A imagem escolhida é reduzida e reencodada em PNG antes do envio (sem metadados do arquivo original). O bucket privado `profile-avatars` limita o arquivo a 512 KB e PNG. Cada conta acessa apenas seu próprio caminho `<uid>/avatar.png`, com RLS para leitura, inserção, atualização e exclusão. Não há URL pública nem imagem incluída nos dados do token de login.

A foto personalizada sincroniza ao abrir, retomar ou atualizar a tela e a cada 30 segundos com o recurso ativo. A mesma imagem aparece nos Ajustes. O cache é separado por conta e visitante. Visitantes guardam a imagem apenas no dispositivo. Trocar/restaurar a foto da conta exige conexão; falha de envio preserva a foto anterior e mostra erro. A foto original do Google não é modificada.

Migração `supabase/migrations/202610100004_profile_avatars.sql` aplicada ao projeto `rdlofauxvsbdytvvmlzd` em 10/10/2026 após confirmar ausência de buckets e políticas. Não reaplicar sem conferir o esquema.

## Teto e gastos

A barra e o termômetro usam os mesmos totais reativos dos lançamentos do período e o mesmo provider do teto mensal. **Ver meus limites** abre a configuração existente, com confirmação antes de gravar e indicação do período consultado. A tela aberta acompanha mudanças nos gastos. Digitar um teto mostra uma prévia na tela de limites; o cartão usa o teto salvo até a confirmação.

A barra usa dez segmentos com preenchimento parcial para precisão. Acima de 100%, fica cheia e o texto conserva o percentual real. As cores seguem as faixas do termômetro. Ela tem descrição acessível para leitores de tela.

## Validação

Testes simulados cobrem filtros diários, semanais e mensais, semanas entre anos, exclusão de datas fora do período, foto em dispositivo limpo, restauração, isolamento entre contas/visitante, falha de envio, limites de tamanho, cancelamento e igualdade das barras após mudanças nos gastos e no teto com o painel aberto. O teste SQL `supabase/tests/profile_avatars.sql` verifica leitura/gravação do dono, isolamento de outra identidade e recusa a visitante, com rollback e sem criar contas/arquivos reais. A proteção do Storage proíbe DELETE direto por SQL; restauração usa a API oficial de Storage. Nenhuma foto pessoal foi enviada pelo agente.
