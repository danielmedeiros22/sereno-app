# Cartão Minhas finanças

O cartão da tela inicial mostra a foto, o nome da conta, o mês consultado, a quantidade de lançamentos e uma barra de dez segmentos com o percentual do teto utilizado. Toque no mês para consultar outro mês; saldo, entradas, saídas, lista e contagem usam essa mesma seleção. O teto é a configuração atual da conta, não um histórico de tetos por mês.

## Foto

Toque na foto/ícone de câmera para **Escolher imagem** ou **Usar foto da conta Google**. Sem foto, aparecem as iniciais. Falhas ao carregar a imagem também usam essa alternativa.

A imagem escolhida é reduzida e reencodada em PNG antes do envio (sem metadados do arquivo original). O bucket privado `profile-avatars` limita o arquivo a 512 KB e PNG. Cada conta acessa apenas seu próprio caminho `<uid>/avatar.png`, com RLS para leitura, inserção, atualização e exclusão. Não há URL pública nem imagem incluída nos dados do token de login.

A foto personalizada sincroniza ao abrir, retomar ou atualizar a tela e a cada 30 segundos com o recurso ativo. A mesma imagem aparece nos Ajustes. O cache é separado por conta e visitante. Visitantes guardam a imagem apenas no dispositivo. Trocar/restaurar a foto da conta exige conexão; falha de envio preserva a foto anterior e mostra erro. A foto original do Google não é modificada.

Migração `supabase/migrations/202610100004_profile_avatars.sql` aplicada ao projeto `rdlofauxvsbdytvvmlzd` em 10/10/2026 após confirmar ausência de buckets e políticas. Não reaplicar sem conferir o esquema.

## Teto e gastos

A barra e o termômetro usam os mesmos totais reativos dos lançamentos do mês e o mesmo provider do teto mensal. **Ver meus limites** abre a configuração existente, com confirmação antes de gravar. A tela aberta acompanha mudanças nos gastos. Digitar um teto mostra uma prévia na tela de limites; o cartão usa o teto salvo até a confirmação.

A barra usa dez segmentos com preenchimento parcial para precisão. Acima de 100%, fica cheia e o texto conserva o percentual real. As cores seguem as faixas do termômetro. Ela tem descrição acessível para leitores de tela.

## Validação

Testes simulados cobrem foto em dispositivo limpo, restauração, isolamento entre contas/visitante, falha de envio, limites de tamanho, cancelamento e igualdade das barras após mudanças nos gastos e no teto com o painel aberto. O teste SQL `supabase/tests/profile_avatars.sql` verifica leitura/gravação do dono, isolamento de outra identidade e recusa a visitante, com rollback e sem criar contas/arquivos reais. A proteção do Storage proíbe DELETE direto por SQL; restauração usa a API oficial de Storage. Nenhuma foto pessoal foi enviada pelo agente.
