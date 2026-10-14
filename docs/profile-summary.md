# Cartão Minhas finanças

## Aparência do aplicativo instalado

Na Web para iPhone/iPad, as páginas Material (rotas do GoRouter e formulários abertos com Navigator) não recebem uma segunda animação lateral do Flutter. O iOS já pode animar seu gesto de histórico; a combinação provocava páginas aparentemente repetidas durante a troca de tela, conforme o problema Flutter #114324. Os botões de abrir/voltar e a pilha de navegação permanecem. A alteração não bloqueia eventos de toque do navegador nem muda animações de modais ou do botão +. Android, Web de computador e aplicativos nativos conservam as transições anteriores. A verificação do gesto real requer um aparelho iOS.

Na Web, o fundo de `html`/`body` e a cor informada ao navegador acompanham o tema efetivo do Sereno (claro, escuro ou sistema), inclusive após carregar a preferência salva ou alterá-la em Ajustes. O manifesto usa o fundo escuro do Sereno na abertura. A configuração Apple mantém o conteúdo abaixo da barra de status, sem modo translúcido nem espaçamento adicional sobre o `SafeArea` existente. Isso evita o fundo branco padrão por trás da interface escura; efeitos específicos do iOS precisam de confirmação no aparelho.

Após uma atualização, feche completamente o aplicativo aberto pelo ícone e abra novamente. A aparência da barra de status pode depender das configurações guardadas pelo iOS na instalação; se persistir, verifique primeiro a versão carregada. Evite remover o aplicativo sem proteger os dados de visitante, que são locais.

O botão **+** do painel responde ao clique com uma animação de 220 ms: encolhe levemente, retorna com um pequeno impulso e gira o ícone antes de abrir **Nova movimentação**. Cliques repetidos durante a abertura não duplicam o formulário. Quando a preferência de acessibilidade solicita animações reduzidas, o formulário abre diretamente.

O cartão da tela inicial mostra a foto, o nome da conta, o período consultado, a quantidade de lançamentos e uma barra de dez segmentos com o percentual do teto utilizado. Escolha **Dia**, **Semana** ou **Mês** e toque na data para consultar outro período. O padrão é o mês atual; a semana vai de segunda a domingo, inclusive quando atravessa meses ou anos. O calendário usa português brasileiro. Saldo, entradas, saídas, lista, contagem e barras usam a mesma seleção e as datas locais do dispositivo.

O teto é a configuração mensal atual da conta, não um histórico de tetos por mês. Nos filtros de dia e semana, a barra compara os gastos desse período com o **teto mensal**, como informa a legenda; não são criados tetos diários ou semanais. A seleção é apenas um filtro local de consulta, sem modificar os registros sincronizados.

## Foto

Em **Ajustes**, toque na foto/ícone de câmera do cartão de perfil para **Escolher imagem** ou **Usar foto da conta Google**. Na tela inicial, a foto é apenas exibida. Sem foto, aparecem as iniciais. Falhas ao carregar a imagem também usam essa alternativa.

A imagem escolhida é reduzida e reencodada em PNG antes do envio (sem metadados do arquivo original). O bucket privado `profile-avatars` limita o arquivo a 512 KB e PNG. Cada conta acessa apenas seu próprio caminho `<uid>/avatar.png`, com RLS para leitura, inserção, atualização e exclusão. Não há URL pública nem imagem incluída nos dados do token de login.

A foto personalizada sincroniza ao abrir, retomar ou atualizar a tela e a cada 30 segundos com o recurso ativo. A mesma imagem aparece no painel e nos Ajustes; a troca e a restauração ficam em Ajustes. O cache é separado por conta e visitante. Visitantes também podem trocar a foto em Ajustes, mas guardam a imagem apenas no dispositivo. Trocar/restaurar a foto da conta exige conexão; falha de envio preserva a foto anterior e mostra erro. A foto original do Google não é modificada.

Migração `supabase/migrations/202610100004_profile_avatars.sql` aplicada ao projeto `rdlofauxvsbdytvvmlzd` em 10/10/2026 após confirmar ausência de buckets e políticas. Não reaplicar sem conferir o esquema.

## Nome de exibição

Contas conectadas possuem um botão **Editar nome** (lápis) no cartão **Minhas finanças** e no perfil em **Ajustes**. O formulário permite até 80 caracteres, exige um nome preenchido e só grava ao tocar em **Salvar**. **Cancelar** descarta o rascunho. A alteração aparece nos dois cartões e na saudação do painel.

O nome é salvo no metadado `sereno_display_name` da própria conta pelo Auth do Supabase. O e-mail, a identidade do login e o nome original do Google permanecem iguais. Sem personalização, usa o nome original da conta. Esse metadado serve apenas para exibição, nunca para permissões. Não exige tabela nem migração nova.

A leitura ocorre ao abrir, retomar ou atualizar o painel e a cada 30 segundos enquanto o recurso está ativo. Cada conta usa seu próprio estado; respostas de outra identidade são ignoradas. Salvar exige conexão; uma falha mantém o nome anterior e permite tentar novamente. Visitantes continuam identificados como **Visitante**. Testes simulam dois dispositivos, reabertura, falha, cancelamento e preservação do e-mail; não representam teste manual físico entre aparelhos.

## Teto e gastos

Na Web, `web/index.html` mantém invisíveis os caracteres selecionados da camada HTML de edição do Flutter (`.flt-text-editing`). O texto, o cursor e o destaque visíveis continuam desenhados pelo Flutter. Isso evita a aparência de números sobrepostos ao selecionar valores; a mesma regra atende entradas, saídas, orçamentos e recorrências, sem mudar os valores ou a sincronização. Aplicativos nativos não usam esse CSS.

A barra e o termômetro usam os mesmos totais reativos dos lançamentos do período e o mesmo provider do teto mensal. **Ver meus limites** abre a configuração existente, com confirmação antes de gravar e indicação do período consultado. A tela aberta acompanha mudanças nos gastos. Digitar um teto mostra uma prévia na tela de limites; o cartão usa o teto salvo até a confirmação.

A barra usa dez segmentos com preenchimento parcial para precisão. Acima de 100%, fica cheia e o texto conserva o percentual real. As cores seguem as faixas do termômetro. Ela tem descrição acessível para leitores de tela.

## Validação

Testes simulados cobrem filtros diários, semanais e mensais, semanas entre anos, exclusão de datas fora do período, foto em dispositivo limpo, restauração, isolamento entre contas/visitante, falha de envio, limites de tamanho, cancelamento e igualdade das barras após mudanças nos gastos e no teto com o painel aberto. O teste SQL `supabase/tests/profile_avatars.sql` verifica leitura/gravação do dono, isolamento de outra identidade e recusa a visitante, com rollback e sem criar contas/arquivos reais. A proteção do Storage proíbe DELETE direto por SQL; restauração usa a API oficial de Storage. Nenhuma foto pessoal foi enviada pelo agente.
