# F.R.I.D.A.Y. Local 5.3

Assistente desktop leve para Windows. A interface é carregada do próprio aplicativo Tauri e o reconhecimento de comandos acontece localmente, sem API de IA, conta, telemetria externa ou servidor `localhost`.

## O que funciona

- abre aplicativos e jogos instalados pelo nome;
- procura músicas, artistas e playlists no aplicativo Spotify;
- pesquisa no Google usando o navegador padrão;
- fecha aplicativos somente após confirmação;
- controla play/pause, faixas, mudo e volume do Windows;
- mostra uso real de CPU e RAM;
- permanece acessível pela bandeja do sistema;
- ouve comandos em português após a palavra de ativação **“Sexta-feira”**;
- permite escolher e testar o microfone, com medidor e transcrição ao vivo;
- não salva o conteúdo da conversa.

Exemplos:

```text
Abra o Spotify
Pode abrir o Minecraft?
Coloque Starboy no Spotify
Pesquise previsão do tempo no Google
Feche o Discord
Próxima música
Volume em 40%
Sexta-feira, abra o Steam
Sexta-feira, coloque Starboy no Spotify
Sexta-feira, toque a playlist Descobertas da Semana
```

## Usar por voz

Clique em **Ativar “Sexta-feira”** na barra lateral ou no botão de microfone da caixa de texto. Depois diga a palavra de ativação e o comando na mesma frase:

```text
Sexta-feira, abra o Spotify
Sexta-feira, abra o app Xbox
Sexta-feira, abra o Steam
Sexta-feira, pesquise notícias de tecnologia no Google
```

Também é possível dizer apenas “Sexta-feira”, esperar a resposta visual e falar o comando nos próximos oito segundos. Depois da primeira ativação, a preferência fica salva e o microfone volta a ser habilitado ao iniciar o aplicativo. O áudio bruto não é gravado nem enviado: somente a transcrição local concluída chega à interface.

Em **Configurar áudio**, escolha uma entrada, clique em **Usar e testar** e observe o medidor. Durante o teste, a frase reconhecida aparece mesmo sem a palavra de ativação. Para executar ações fora do teste, ainda é necessário dizer “Sexta-feira”.

O Spotify abre a busca apropriada para músicas ou playlists e aceita links/URIs diretos. Para tocar diretamente pelo nome, clique em **Conectar Spotify**: o navegador pede autorização uma única vez por sessão via PKCE, sem Client Secret. O token permanece apenas na memória do aplicativo e não é salvo no projeto.

Na primeira ativação, o modelo incluído no instalador é preparado em `%LOCALAPPDATA%\FridayLocal`. Isso acontece uma única vez e evita falhas causadas por arquivos do modelo incompletos durante a instalação.

## Como a IA local funciona

O arquivo `frontend/brain.js` contém um classificador **Naive Bayes multinomial** treinado na inicialização com pequenas frases em português. Ele usa palavras e pares de palavras para estimar a intenção do comando. Regras determinísticas complementam o modelo nas ações que precisam ser inequívocas, e o núcleo Rust executa apenas a lista de operações permitidas.

Isso é machine learning real, mas não é um modelo generativo como ChatGPT ou Ollama. A vantagem é iniciar instantaneamente e consumir poucos recursos; a limitação é responder somente às intenções previstas.

## Privacidade e segurança

- O frontend ativo não abre WebSocket nem faz requisições a um backend.
- Somente uma pesquisa pedida pelo usuário abre o Google ou o protocolo do Spotify.
- Texto digitado e histórico não são persistidos.
- Não existe execução livre de PowerShell, `cmd` ou shell a partir da conversa.
- Processos críticos do Windows ficam bloqueados.
- Fechar um aplicativo exige confirmação explícita.
- A política CSP bloqueia conexões de rede feitas pela interface.
- O microfone pode ser desligado a qualquer momento pelo mesmo botão que o ativa.

## Executar durante o desenvolvimento

Requisitos:

- Windows 10/11 com WebView2;
- Node.js 20+;
- Rust estável com target MSVC;
- Visual Studio Build Tools com desenvolvimento C++.

Na raiz do projeto:

```powershell
npm install
powershell -ExecutionPolicy Bypass -File .\voice\build_voice.ps1
npm run dev
```

Também é possível dar dois cliques em `start_friday.bat`.

## Testar e gerar o instalador

```powershell
npm test
npm run build
```

Saídas esperadas:

- executável portátil: `src-tauri/target/release/friday-core.exe`;
- instaladores: `src-tauri/target/release/bundle/msi/` e `src-tauri/target/release/bundle/nsis/`.

## Estrutura ativa

```text
frontend/
  index.html       interface desktop
  styles.css       design system e layout
  brain.js         classificador local e extração de entidades
  app.js           conversa e ponte segura para o núcleo nativo
src-tauri/
  src/lib.rs       automações do Windows e telemetria local
  src/main.rs      entrada do aplicativo
  tauri.conf.json  empacotamento sem servidor web externo
tests/
  brain.test.js    testes do reconhecimento de intenção
voice/
  voice_worker.py  captura e transcrição offline
  build_voice.ps1  baixa o modelo e gera o processo auxiliar
```

As pastas `server/` e `friday_mobile/`, além do antigo `index.html` da raiz, são componentes legados e não participam mais da compilação desktop 5.0. Foram mantidos apenas para referência histórica.

## Limites intencionais

- O Spotify abre a tela de busca; iniciar uma faixa automaticamente exigiria autenticação/API ou automação frágil da interface.
- Aplicativos desconhecidos são procurados no catálogo do menu Iniciar. Use o nome exibido pelo Windows.
- Não há resposta generativa, memória longa, acesso a arquivos pessoais ou controle arbitrário do sistema.
- O modelo pequeno de português ocupa cerca de 31 MB em disco. Nesta máquina, a escuta utilizou aproximadamente 190 MB de RAM; o projeto Vosk informa que modelos pequenos podem chegar a cerca de 300 MB. Desligar o microfone encerra esse processo e libera a memória.
