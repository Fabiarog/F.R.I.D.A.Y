(function attachFridayBrain(globalScope) {
  "use strict";

  const TRAINING_DATA = {
    open_app: [
      "abra o aplicativo", "abrir um programa", "inicie o programa", "execute o aplicativo",
      "quero usar o navegador", "roda o jogo", "jogar agora", "abre a calculadora",
      "iniciar spotify", "pode abrir o discord", "liga o minecraft", "abre o bloco de notas",
      "open the app", "open discord", "open spotify", "launch minecraft", "start chrome",
      "run the game", "open steam", "open youtube", "open calculator", "open notepad",
      "open whatsapp", "open roblox", "open valorant", "open vs code",
      "abra o discord", "abre o spotify", "inicia o minecraft", "roda o valorant",
      "abre o chrome", "abrir a steam", "abre o roblox", "abre o vs code", "abre o youtube",
      "abrir discorde", "abre discorde", "abra o discorde", "pode abrir o discorde",
      "abrir spotify", "abrir espotifai", "abre o espotifai", "abrir spotfy", "abrir espotify",
      "inicia o discorde", "inicie o espotifai", "abrir maincrafte", "abre o maincrafte",
      "abril de discord", "abril de discorde", "abril discord", "abril discorde", "abril o discorde",
      "abril spotify", "abril de spotify", "abril esporte vai", "abri discord", "abriu discord",
    ],
    close_app: [
      "feche o aplicativo", "encerre o programa", "fecha o discord", "mate o processo",
      "desligue o navegador", "pode fechar o jogo", "encerra o spotify", "sair do aplicativo",
      "close the app", "close discord", "close spotify", "quit minecraft", "exit the game",
      "kill the process", "close chrome", "close steam", "close youtube",
      "fecha o discord", "feche o spotify", "encerra o minecraft", "fecha a steam",
      "fechar discorde", "feche o discorde", "fecha o discorde", "encerre o discorde",
      "fechar de discord", "fechar de discorde", "fecha de discord", "feche de discord",
      "fechar spotify", "feche o espotifai", "fecha o espotifai", "feche o spotfy",
    ],
    spotify_search: [
      "coloque uma musica no spotify", "toca uma musica", "quero ouvir uma banda",
      "busque uma faixa no spotify", "toque essa cancao", "ouvir no spotify",
      "coloca uma musica do artista", "procure esse album no spotify",
      "play some music", "play starboy on spotify", "play a song", "put some music",
      "listen to the weeknd", "play the album", "spotify play", "play track",
      "toque starboy no spotify", "coloca uma musica", "toca the weeknd",
      "ouvir musica no spotify", "reproduza uma faixa", "toca no spotify",
      "toca no espotifai", "tocar no espotifai", "coloque starboy no espotifai",
      "toca starboy no espotifai", "toca no esporte vai", "coloque no esporte vai",
    ],
    spotify_playlist: [
      "reproduza uma playlist", "toque a playlist", "coloque minha playlist",
      "quero ouvir a playlist", "abre a playlist no spotify", "toca uma lista no spotify",
      "play playlist", "play my playlist", "play discoveries of the week", "start playlist",
      "open playlist on spotify", "toca a lista no spotify", "playlist no espotifai",
    ],
    web_search: [
      "pesquise no google", "procure na internet", "busque na web", "google sobre isso",
      "quero pesquisar uma coisa", "encontre no google", "faz uma busca", "pesquisa o clima",
      "search on google", "google this", "search the web", "look up the weather",
      "find on google", "search cats", "search online",
    ],
    media_play_pause: [
      "pause a musica", "continue a musica", "play na musica", "parar ou tocar",
      "dar pause", "retome a faixa", "pausar o som",
      "play pause", "pause the music", "resume playback", "stop the music",
      "play the track", "pause", "resume", "play song",
    ],
    media_next: [
      "proxima musica", "pule essa faixa", "avanca a musica", "toca a seguinte",
      "passa para a proxima", "mude de faixa",
      "next track", "next song", "skip track", "skip this song", "next", "skip",
    ],
    media_previous: [
      "musica anterior", "volte a faixa", "toca a anterior", "retorne uma musica",
      "voltar a faixa anterior",
      "previous track", "previous song", "go back a track", "previous", "prev",
    ],
    volume_up: [
      "aumente o volume", "som mais alto", "suba o volume", "aumentar o audio",
      "deixa mais alto", "volume up", "louder", "turn it up", "increase volume", "boost volume",
    ],
    volume_down: [
      "abaixe o volume", "som mais baixo", "diminua o volume", "reduza o audio",
      "deixa mais baixo", "volume down", "quieter", "turn it down", "decrease volume", "lower volume",
    ],
    volume_mute: [
      "mute o computador", "tire o som", "silencie o audio", "ativar mudo",
      "desmutar o som", "mute the sound", "unmute", "mute pc", "silence audio", "mute",
    ],
    volume_set: [
      "coloque o volume em cinquenta", "volume em vinte por cento", "defina o som",
      "ajuste o volume para", "deixe o volume em",
      "set volume to fifty", "volume fifty percent", "volume twenty", "set sound to eighty",
    ],
    get_time: [
      "que horas sao", "me diga a hora", "qual o horario", "horas agora",
      "what time is it", "tell me the time", "current time", "what time",
    ],
    get_date: [
      "que dia e hoje", "qual a data", "data de hoje", "dia atual",
      "what day is today", "what is the date", "today's date",
    ],
    help: [
      "o que voce sabe fazer", "me ajude", "mostrar comandos", "quais sao os recursos",
      "como usar", "suas funcoes", "lista de comandos",
      "help", "what can you do", "commands list", "show commands", "how to use",
    ],
    greeting: [
      "oi", "ola", "bom dia", "boa tarde", "boa noite", "e ai friday", "tudo bem",
      "hello", "hi friday", "hey", "good morning", "good evening", "how are you",
    ],
  };

  const INTENT_LABELS = {
    open_app: "abrir aplicativo",
    close_app: "fechar aplicativo",
    spotify_search: "Spotify",
    spotify_playlist: "playlist Spotify",
    web_search: "pesquisa web",
    media_play_pause: "mídia",
    media_next: "próxima faixa",
    media_previous: "faixa anterior",
    volume_up: "volume",
    volume_down: "volume",
    volume_mute: "volume",
    volume_set: "volume",
    get_time: "hora local",
    get_date: "data local",
    help: "ajuda",
    greeting: "conversa local",
    unknown: "não identificado",
  };

  // Mapeamento fonético de frases completas e compostas
  // Resolve quando o Vosk divide uma palavra em inglês em múltiplos tokens em português
  const PHONETIC_PHRASES = [
    // Spotify — Variações em português ouvidas pelo microfone
    [/\b(?:esporte|suporte|porto|porta)\s+(?:vai|pai|fai|faia|fatia|fine|fim|fay)\b/gi, "spotify"],
    [/\b(?:espot|spot|sporting|esporte)\s+(?:fai|fay|fye|fae|vai|pai)\b/gi, "spotify"],
    [/\bespot\s*fai\b/gi, "spotify"],
    [/\bspot\s*fai\b/gi, "spotify"],
    [/\besporte\s+fai\b/gi, "spotify"],
    [/\bsuporte\s+vai\b/gi, "spotify"],
    [/\bporto\s+vai\b/gi, "spotify"],
    [/\bporta\s+vai\b/gi, "spotify"],
    [/\b(?:no|pelo|do)\s+esporte\b/gi, "no spotify"],

    // Discord — Variações em português ("discorde", "disco de", "discordi", etc.)
    [/\b(?:dis|diz)\s+cor(?:de|di)?\b/gi, "discord"],
    [/\bdisco\s+(?:de|da)\b/gi, "discord"],
    [/\bdisco\s+r(?:de|di)\b/gi, "discord"],

    // Minecraft
    [/\bmai(?:n)?\s+craf(?:t|te|ti)?\b/gi, "minecraft"],
    [/\bmine\s+craf(?:t|te)?\b/gi, "minecraft"],
    [/\bmai\s+ne\s+craf(?:t|ti)?\b/gi, "minecraft"],
    [/\bmani\s+craf(?:t|te)?\b/gi, "minecraft"],

    // YouTube
    [/\b(?:you|u|iu|eu)\s+(?:tube|tubi|tuber)\b/gi, "youtube"],

    // Netflix
    [/\bnet(?:i)?\s+(?:flix|flixi|flics|fliqui)\b/gi, "netflix"],

    // WhatsApp
    [/\b(?:uot|uats|zap)\s+(?:zap|zapi|ape|eipe)\b/gi, "whatsapp"],
    [/\buats\s+ap\b/gi, "whatsapp"],
    [/\bzap\s+zap\b/gi, "whatsapp"],

    // VS Code
    [/\b(?:ve|vi)\s+(?:esse|ese)\s+(?:code|codi)\b/gi, "vscode"],
    [/\bvisual\s+studio\s+code\b/gi, "vscode"],

    // Valorant
    [/\bvalo\s+ran(?:te|ti|t)?\b/gi, "valorant"],

    // Fortnite
    [/\bfor(?:t|te)\s+nai(?:t|te|ti)\b/gi, "fortnite"],

    // Roblox
    [/\bro\s*blo(?:quis|ques|x)\b/gi, "roblox"],

    // Google
    [/\bgug(?:ol|le|li)\b/gi, "google"],
    [/\bgugol\s+(?:crome|cromi|chrome)\b/gi, "google chrome"],

    // Playlist
    [/\bplei\s+lis(?:t|te|ti)\b/gi, "playlist"],
    [/\bplay\s+lis(?:t|te)\b/gi, "playlist"],

    // Wake phrase variations
    [/\bcesta\s+(?:feira|freira|fera|feia)\b/gi, "sexta-feira"],
    [/\bsexta\s+(?:freira|fera|feia)\b/gi, "sexta-feira"],
    [/\bfrai\s+dei\b/gi, "friday"],

    // Verbos e preposições parasitas comuns do Vosk ("abril de discorde", "abril o discord", etc.)
    [/\b(?:abril|abri|abriu|abrem)\s+(?:de\s+|do\s+|da\s+|no\s+|na\s+|o\s+|a\s+)?/gi, "abrir "],
    [/\babrir\s+(?:de\s+|do\s+|da\s+)/gi, "abrir "],
    [/\b(?:abre|abra)\s+(?:de\s+|do\s+|da\s+)/gi, "abrir "],
    [/\b(?:fechar|feche|fecha|fecho|fechou)\s+(?:de\s+|do\s+|da\s+)/gi, "fechar "],
    [/\b(?:iniciar|inicie|inicia)\s+(?:de\s+|do\s+|da\s+)/gi, "iniciar "],
    [/\b(?:executar|execute|executa)\s+(?:de\s+|do\s+|da\s+)/gi, "executar "],
    [/\b(?:tocar|toque|toca|colocar|coloque|coloca|botar|bote|bota)\s+(?:de\s+)/gi, "tocar "],
    [/\b(?:botar|bote|bota)\s+(?:no|na|em|o|a)?\s*/gi, "coloque "],
  ];

  // Dicionário fonético de termos individuais em inglês
  const PHONETIC_WORDS = {
    // Spotify — Variações completas e palavras que lembram Spotify
    "espotifai": "spotify",
    "spotifai": "spotify",
    "spotfai": "spotify",
    "espotfai": "spotify",
    "espotify": "spotify",
    "spotfy": "spotify",
    "espotfy": "spotify",
    "spoti": "spotify",
    "espoti": "spotify",
    "espot": "spotify",
    "sportify": "spotify",
    "spotifay": "spotify",
    "espotifay": "spotify",

    // Formas faladas de "abrir" ("abril", "abri", "abriu") produzidas pelo Vosk
    "abril": "abrir",
    "abri": "abrir",
    "abriu": "abrir",
    "abrem": "abrir",

    // Discord — Variações como "discorde" com 'e', "discordi", "descorde", etc.
    "discorde": "discord",
    "discordi": "discord",
    "descorde": "discord",
    "descordi": "discord",
    "discor": "discord",
    "discordia": "discord",
    "discórdia": "discord",
    "dicord": "discord",
    "dicorde": "discord",

    // Minecraft
    "maincrafte": "minecraft",
    "maincraft": "minecraft",
    "manicraft": "minecraft",
    "mancraft": "minecraft",
    "mincraf": "minecraft",
    "minecrafte": "minecraft",

    // Steam
    "istim": "steam",
    "istime": "steam",
    "stim": "steam",
    "estime": "steam",
    "istin": "steam",
    "estin": "steam",

    // Chrome
    "cromi": "chrome",
    "crome": "chrome",
    "corome": "chrome",

    // YouTube
    "iutubi": "youtube",
    "iutube": "youtube",
    "youtub": "youtube",

    // Netflix
    "netiflics": "netflix",
    "netiflix": "netflix",
    "netflixi": "netflix",

    // WhatsApp
    "uotizape": "whatsapp",
    "uotsap": "whatsapp",
    "uatsap": "whatsapp",
    "uatsape": "whatsapp",
    "uotsape": "whatsapp",

    // Jogos e outros
    "valorante": "valorant",
    "valoranti": "valorant",
    "valoran": "valorant",
    "fortinaiti": "fortnite",
    "fortnaite": "fortnite",
    "robloquis": "roblox",
    "robloques": "roblox",
    "tuitchi": "twitch",
    "tuiche": "twitch",
    "tuitche": "twitch",
    "edji": "edge",
    "edgi": "edge",
    "tuiter": "twitter",
    "tuitere": "twitter",
    "notepedi": "notepad",
    "calcoladora": "calculadora",

    // Ações e Comandos de Mídia
    "oupen": "open",
    "oupan": "open",
    "opem": "open",
    "clouze": "close",
    "clous": "close",
    "plei": "play",
    "pleie": "play",
    "pauze": "pause",
    "pauzi": "pause",
    "pouse": "pause",
    "stope": "stop",
    "istope": "stop",
    "nexte": "next",
    "nequisiti": "next",
    "nequi": "next",
    "privius": "previous",
    "previus": "previous",
    "miute": "mute",
    "miuti": "mute",
    "milti": "mute",
    "anmiute": "unmute",
    "desmutar": "unmute",
    "esquipe": "skip",
    "volumi": "volume",
    "serchi": "search",
    "cerche": "search",
    "fainde": "find",
    "treque": "track",
    "songue": "song",
    "pleiliste": "playlist",
    "gugol": "google",
    "gugli": "google",
    "gugle": "google",
    "fraidei": "friday",
    "fraide": "friday",
  };

  // Nomes canônicos formatados para o Windows / menu Iniciar
  const CANONICAL_ENTITIES = {
    "spotify": "Spotify",
    "espotifai": "Spotify",
    "spotifai": "Spotify",
    "spotfy": "Spotify",
    "espotify": "Spotify",
    "discord": "Discord",
    "discorde": "Discord",
    "discordi": "Discord",
    "descorde": "Discord",
    "discordia": "Discord",
    "discórdia": "Discord",
    "minecraft": "Minecraft",
    "maincrafte": "Minecraft",
    "maincraft": "Minecraft",
    "steam": "Steam",
    "istim": "Steam",
    "istime": "Steam",
    "chrome": "Chrome",
    "crome": "Chrome",
    "cromi": "Chrome",
    "google chrome": "Google Chrome",
    "youtube": "YouTube",
    "iutubi": "YouTube",
    "netflix": "Netflix",
    "netiflics": "Netflix",
    "whatsapp": "WhatsApp",
    "uotizape": "WhatsApp",
    "valorant": "Valorant",
    "valorante": "Valorant",
    "fortnite": "Fortnite",
    "fortnaite": "Fortnite",
    "roblox": "Roblox",
    "robloquis": "Roblox",
    "twitch": "Twitch",
    "tuitchi": "Twitch",
    "vscode": "Visual Studio Code",
    "vs code": "Visual Studio Code",
    "visual studio code": "Visual Studio Code",
    "notepad": "Bloco de Notas",
    "bloco de notas": "Bloco de Notas",
    "calculadora": "Calculadora",
    "calculator": "Calculadora",
    "paint": "Paint",
    "terminal": "Terminal",
    "edge": "Microsoft Edge",
    "microsoft edge": "Microsoft Edge",
    "twitter": "Twitter",
  };

  // Mapeamento de números escritos por extenso em português e inglês
  const WORD_NUMBERS = {
    "zero": "0", "um": "1", "uma": "1", "dois": "2", "duas": "2", "tres": "3", "três": "3",
    "quatro": "4", "cinco": "5", "seis": "6", "sete": "7", "oito": "8", "nove": "9", "dez": "10",
    "quinze": "15", "vinte": "20", "trinta": "30", "quarenta": "40", "cinquenta": "50",
    "sessenta": "60", "setenta": "70", "oitenta": "80", "noventa": "90", "cem": "100",
    "cento": "100", "metade": "50", "maximo": "100", "máximo": "100", "minimo": "0", "mínimo": "0",
    "one": "1", "two": "2", "three": "3", "four": "4", "five": "5", "six": "6", "seven": "7",
    "eight": "8", "nine": "9", "ten": "10", "twenty": "20", "thirty": "30", "forty": "40",
    "fifty": "50", "sixty": "60", "seventy": "70", "eighty": "80", "ninety": "90", "hundred": "100",
    "max": "100", "half": "50"
  };

  function levenshtein(a, b) {
    if (a === b) return 0;
    if (!a.length) return b.length;
    if (!b.length) return a.length;
    const matrix = [];
    for (let i = 0; i <= b.length; i++) matrix[i] = [i];
    for (let j = 0; j <= a.length; j++) matrix[0][j] = j;
    for (let i = 1; i <= b.length; i++) {
      for (let j = 1; j <= a.length; j++) {
        matrix[i][j] = b.charAt(i - 1) === a.charAt(j - 1)
          ? matrix[i - 1][j - 1]
          : Math.min(matrix[i - 1][j - 1] + 1, matrix[i][j - 1] + 1, matrix[i - 1][j] + 1);
      }
    }
    return matrix[b.length][a.length];
  }

  function normalize(text) {
    return String(text || "")
      .normalize("NFD")
      .replace(/[\u0300-\u036f]/g, "")
      .toLowerCase()
      .replace(/[^a-z0-9%\s]/g, " ")
      .replace(/\s+/g, " ")
      .trim();
  }

  /**
   * Lê cada palavra como foi dita, mapeando variações fonéticas e termos em inglês
   * sem perder a ordem ou a intenção da instrução falada.
   */
  function readWordsAndInterpret(rawText) {
    if (!rawText) return "";
    let text = String(rawText);

    // 1. Aplica padrões compostos (ex: "esporte vai" -> "spotify", "disco de" -> "discord")
    for (const [pattern, replacement] of PHONETIC_PHRASES) {
      text = text.replace(pattern, replacement);
    }

    // 2. Lê palavra por palavra e substitui correspondências fonéticas e fuzzy
    const words = text.split(/\s+/).filter(Boolean);
    const mapped = words.map((word) => {
      const normWord = normalize(word);
      if (PHONETIC_WORDS[normWord]) {
        return PHONETIC_WORDS[normWord];
      }
      // Similaridade sonora fuzzy para variações não mapeadas diretamente
      if (normWord.length >= 5) {
        if (normWord.startsWith("d") && levenshtein(normWord, "discord") <= 2) {
          return "discord";
        }
        if ((normWord.startsWith("s") || normWord.startsWith("es")) && levenshtein(normWord, "spotify") <= 2) {
          return "spotify";
        }
        if (normWord.startsWith("m") && levenshtein(normWord, "minecraft") <= 2) {
          return "minecraft";
        }
      }
      return word;
    });

    return mapped.join(" ");
  }

  function tokensFor(text) {
    const words = normalize(text).split(" ").filter(Boolean);
    const bigrams = [];
    for (let index = 0; index < words.length - 1; index += 1) {
      bigrams.push(`${words[index]}_${words[index + 1]}`);
    }
    return words.concat(bigrams);
  }

  class NaiveBayesIntentClassifier {
    constructor(trainingData = TRAINING_DATA) {
      this.classes = Object.keys(trainingData);
      this.documentCounts = new Map();
      this.tokenCounts = new Map();
      this.totalTokens = new Map();
      this.vocabulary = new Set();
      this.totalDocuments = 0;
      this.train(trainingData);
    }

    train(trainingData) {
      Object.entries(trainingData).forEach(([intent, examples]) => {
        this.documentCounts.set(intent, examples.length);
        this.totalDocuments += examples.length;
        const classTokens = new Map();
        let tokenTotal = 0;

        examples.forEach((example) => {
          tokensFor(example).forEach((token) => {
            this.vocabulary.add(token);
            classTokens.set(token, (classTokens.get(token) || 0) + 1);
            tokenTotal += 1;
          });
        });

        this.tokenCounts.set(intent, classTokens);
        this.totalTokens.set(intent, tokenTotal);
      });
    }

    predict(text) {
      const features = tokensFor(text);
      const vocabularySize = Math.max(1, this.vocabulary.size);
      const scores = this.classes.map((intent) => {
        const documents = this.documentCounts.get(intent) || 0;
        let score = Math.log((documents + 1) / (this.totalDocuments + this.classes.length));
        const classTokens = this.tokenCounts.get(intent);
        const denominator = (this.totalTokens.get(intent) || 0) + vocabularySize;

        features.forEach((token) => {
          score += Math.log(((classTokens.get(token) || 0) + 1) / denominator);
        });
        return { intent, score };
      });

      scores.sort((left, right) => right.score - left.score);
      const maxScore = scores[0].score;
      const probabilities = scores.map((item) => Math.exp(item.score - maxScore));
      const probabilitySum = probabilities.reduce((sum, value) => sum + value, 0);
      const confidence = probabilities[0] / probabilitySum;
      return { intent: scores[0].intent, confidence };
    }
  }

  const OPEN_WORDS = [
    "abra", "abre", "abrir", "abril", "abri", "abriu", "abrem", "inicie", "inicia", "iniciar", "execute", "executa",
    "rodar", "rode", "jogar", "jogue", "liga", "ligue",
    "open", "launch", "start", "run",
  ];
  const CLOSE_WORDS = [
    "feche", "fecha", "fechar", "encerre", "encerra", "encerrar",
    "mate", "matar", "finalize", "finalizar",
    "close", "quit", "exit", "kill", "terminate", "stop",
  ];
  const SEARCH_WORDS = [
    "pesquise", "pesquisa", "pesquisar", "procure", "procurar", "busque", "buscar",
    "google", "search", "find", "lookup",
  ];
  const SPOTIFY_WORDS = [
    "spotify", "musica", "música", "faixa", "album", "álbum", "playlist", "ouvir",
    "toque", "toca", "reproduza", "reproduzir", "coloque", "coloca",
    "play", "listen", "song", "track",
  ];

  function hasAny(normalizedText, terms) {
    const padded = ` ${normalizedText} `;
    return terms.some((term) => padded.includes(` ${normalize(term)} `));
  }

  function cleanEntity(original, intent) {
    let value = readWordsAndInterpret(original);
    const patterns = {
      open_app: /^(?:(?:por favor|pode|poderia|você pode|voce pode|please|can you)\s+)?(?:abrir|abra|abre|abril|abri|abriu|abrem|iniciar|inicie|inicia|executar|execute|executa|rodar|rode|jogar|jogue|ligar|liga|ligue|open|launch|start|run)\s+(?:(?:o|a|um|uma|de|do|da|no|na|the|an)\s+)?(?:aplicativo|app|programa|jogo|game)?\s*/i,
      close_app: /^(?:(?:por favor|pode|poderia|você pode|voce pode|please|can you)\s+)?(?:fechar|feche|fecha|fecho|fechou|encerrar|encerre|encerra|matar|mate|finalize|finalizar|close|quit|exit|kill|terminate)\s+(?:(?:o|a|um|uma|de|do|da|the|an)\s+)?(?:aplicativo|app|programa|processo|jogo|game)?\s*/i,
      web_search: /^(?:(?:por favor|please)\s+)?(?:pesquisar|pesquise|pesquisa|procurar|procure|buscar|busque|google|search|find|lookup)\s*(?:(?:por|sobre|no google|na internet|na web|for|about|on google|on the web)\s+)?/i,
      spotify_search: /^(?:(?:por favor|please)\s+)?(?:coloque|coloca|tocar|toque|toca|reproduzir|reproduza|quero ouvir|ouvir|buscar|busque|procurar|procure|pesquisar|pesquise|play|listen to|put on)\s*(?:(?:a|uma|the|an)?\s*(?:música|musica|faixa|playlist|álbum|album|song|track)?\s*)?/i,
      spotify_playlist: /^(?:(?:por favor|please)\s+)?(?:coloque|coloca|tocar|toque|toca|reproduzir|reproduza|quero ouvir|ouvir|abrir|abra|abre|buscar|busque|procurar|procure|play|start|open)\s*(?:(?:a|minha|uma|the|my)?\s*(?:playlist|lista)(?:\s+de\s+músicas)?\s*)?/i,
    };

    if (patterns[intent]) value = value.replace(patterns[intent], "");

    value = value.replace(/^(?:de|do|da|o|a|no|na|em|the|an)\s+/i, "");

    if (intent === "spotify_search" || intent === "spotify_playlist") {
      value = value
        .replace(/\s*(?:no|pelo|do|on)\s+spotify\s*$/i, "")
        .replace(/^spotify\s*/i, "")
        .replace(/\s+spotify\s*$/i, "")
        .replace(/^(?:no|pelo|do|da|de|by|on)\s+/i, "")
        .replace(/^(?:de|do|da|by)\s+/i, "");
    }

    if (intent === "web_search") {
      value = value
        .replace(/\s+(?:no|pelo|on)\s+google\s*$/i, "")
        .replace(/^(?:no\s+google|na\s+internet|na\s+web|on\s+google|on\s+the\s+web)\s*/i, "")
        .replace(/\s+(?:na\s+internet|na\s+web|on\s+the\s+web)\s*$/i, "");
    }

    let cleaned = value.trim().replace(/[?.!,;:]+$/g, "").trim();
    cleaned = cleaned.replace(/^(?:de|do|da|o|a|no|na|em|the|an)\s+/i, "").trim();
    const canonKey = normalize(cleaned);
    if (CANONICAL_ENTITIES[canonKey]) {
      cleaned = CANONICAL_ENTITIES[canonKey];
    } else if (canonKey.includes("discord")) {
      cleaned = "Discord";
    } else if (canonKey.includes("spotify")) {
      cleaned = "Spotify";
    } else if (canonKey.includes("minecraft")) {
      cleaned = "Minecraft";
    } else if (canonKey.includes("steam")) {
      cleaned = "Steam";
    } else if (cleaned && cleaned === cleaned.toLowerCase()) {
      // Se veio em minúsculas da fala, coloca a primeira letra em maiúscula (ex: "starboy" -> "Starboy")
      cleaned = cleaned.charAt(0).toUpperCase() + cleaned.slice(1);
    }
    return cleaned;
  }

  function numberEntity(text) {
    const norm = normalize(text);
    const digitMatch = norm.match(/\b(100|[1-9]?[0-9])\s*%?/);
    if (digitMatch) return digitMatch[1];
    for (const [word, num] of Object.entries(WORD_NUMBERS)) {
      const regex = new RegExp(`\\b${word}\\b`, "i");
      if (regex.test(norm)) return num;
    }
    return "";
  }

  function stripWakePhrase(transcript) {
    const spoken = String(transcript || "").trim();
    if (!spoken) return null;

    // Reconhece a palavra de ativação mesmo se dita rapidamente, com saudações,
    // preposições ou variações fonéticas comuns do Vosk em português e inglês:
    // "Sexta-feira", "Sexta freira", "Sesta fera", "Sexta", "Cesta feira", "Cesta",
    // "Nesta feira", "Na sexta feira", "Fala sexta", "Friday", "Frai dei", etc.
    const pattern = /^(?:(?:e\s+aí|e\s+ai|fala|alô|alo|ó|ou|aí|ai|ei|oi|olá|ola|ok|hey|hi|hello|por\s+favor)\s+)?(?:(?:sexta(?:-|\s+)(?:feira|freira|fera|feia|féria|feria|fira|fia|filha|fria)|cesta(?:-|\s+)(?:feira|freira|fera|feia|féria|feria|fira|fia|filha|fria)|sesta(?:-|\s+)(?:feira|freira|fera|feia)|seta(?:-|\s+)(?:feira|freira|fera|feia)|senta(?:-|\s+)(?:feira|freira|fera|feia)|serra(?:-|\s+)(?:feira|freira|fera|feia)|cerra(?:-|\s+)(?:feira|freira|fera|feia)|(?:nesta|esta|da\s+sexta|na\s+sexta|pra\s+sexta)\s+(?:feira|freira|fera|feia)|sexta|cesta|sesta|frai\s+(?:dei|dai|de|day)|fraidei|fraiday|fraide|fraidi|frayday|friday|frida|fride)\b)(?:\s+(?:por\s+favor|meu\s+bem))?(?:\s*[,.:;-]?\s*)(.*)$/i;

    const match = spoken.match(pattern);
    if (!match) return null;
    return match[1] ? match[1].trim() : "";
  }

  class FridayBrain {
    constructor() {
      this.classifier = new NaiveBayesIntentClassifier();
    }

    classify(text) {
      const interpreted = readWordsAndInterpret(text);
      const normalizedText = normalize(interpreted);
      let intent = null;
      let confidence = 0.99;

      if (!normalizedText) return this.result("unknown", "", 0);

      if (hasAny(normalizedText, CLOSE_WORDS)) {
        intent = "close_app";
      } else if (
        /\b(playlist|lista de musica|lista de musicas)\b/.test(normalizedText)
        && hasAny(normalizedText, ["toque", "toca", "reproduza", "reproduzir", "coloque", "coloca", "ouvir", "abra", "abre", "play", "start"])
      ) {
        intent = "spotify_playlist";
      } else if (
        normalizedText.includes("spotify")
        && (hasAny(normalizedText, SPOTIFY_WORDS.filter((word) => normalize(word) !== "spotify")) || hasAny(normalizedText, SEARCH_WORDS))
      ) {
        const maybeEntity = cleanEntity(interpreted, "spotify_search");
        if (maybeEntity && normalize(maybeEntity) !== "spotify") {
          intent = "spotify_search";
        } else {
          intent = "open_app";
        }
      } else if (
        /\b(pause|pausa|pausar|continue|continuar|dar pause|dar play|play na musica|play no som|retome|resume)\b/.test(normalizedText)
      ) {
        intent = "media_play_pause";
      } else if (
        hasAny(normalizedText, ["toque", "toca", "reproduza", "reproduzir", "coloque", "coloca", "ouvir", "play", "listen"])
        && /\b(musica|faixa|cancao|album|artista|song|track)\b/.test(normalizedText)
      ) {
        intent = "spotify_search";
      } else if (hasAny(normalizedText, SEARCH_WORDS)) {
        intent = "web_search";
      } else if (/\b(proxima|próxima|seguinte|next|skip)\b/.test(normalizedText) || /\bpule\b/.test(normalizedText)) {
        intent = "media_next";
      } else if (/\b(anterior|volte|voltar|retorne|previous|prev|back)\b/.test(normalizedText) && /\b(musica|faixa|som|track|song)\b/.test(normalizedText)) {
        intent = "media_previous";
      } else if (/\b(play|pause)\b/.test(normalizedText) && !/\b(playlist|game|jogo)\b/.test(normalizedText) && normalizedText.split(" ").length <= 4) {
        intent = "media_play_pause";
      } else if (/\b(mute|mudo|silencie|silenciar|desmutar|unmute)\b/.test(normalizedText) || normalizedText.includes("tire o som")) {
        intent = "volume_mute";
      } else if (/\b(volume|som|audio|sound)\b/.test(normalizedText) && (/\b(100|[1-9]?[0-9])\s*%?\b/.test(normalizedText) || numberEntity(normalizedText))) {
        intent = "volume_set";
      } else if (/\b(aumente|aumentar|suba|alto|louder|up|boost)\b/.test(normalizedText) && /\b(volume|som|audio|sound)\b/.test(normalizedText)) {
        intent = "volume_up";
      } else if (/\b(abaixe|abaixar|diminua|diminuir|reduza|baixo|lower|down|quieter)\b/.test(normalizedText) && /\b(volume|som|audio|sound)\b/.test(normalizedText)) {
        intent = "volume_down";
      } else if (/\b(que horas|qual horario|hora agora|me diga a hora|what time|time now)\b/.test(normalizedText)) {
        intent = "get_time";
      } else if (/\b(que dia|qual a data|data de hoje|dia atual|what date|what day|today)\b/.test(normalizedText)) {
        intent = "get_date";
      } else if (hasAny(normalizedText, OPEN_WORDS)) {
        intent = "open_app";
      } else {
        const prediction = this.classifier.predict(interpreted);
        intent = prediction.intent;
        confidence = prediction.confidence;
        if (confidence < 0.24) intent = "unknown";
      }

      let entity = "";
      if (["open_app", "close_app", "web_search", "spotify_search", "spotify_playlist"].includes(intent)) {
        entity = cleanEntity(interpreted, intent);
        // Fallback inteligente para termos comuns quando a entidade ficou vazia ou genérica
        if (intent === "open_app" || intent === "close_app") {
          if (normalizedText.includes("discord") || normalizedText.includes("discorde")) {
            entity = "Discord";
          } else if (normalizedText.includes("spotify") || normalizedText.includes("espotifai")) {
            entity = "Spotify";
          } else if (normalizedText.includes("minecraft") || normalizedText.includes("maincrafte")) {
            entity = "Minecraft";
          } else if (normalizedText.includes("steam") || normalizedText.includes("istim")) {
            entity = "Steam";
          } else if (normalizedText.includes("chrome") || normalizedText.includes("crome")) {
            entity = "Chrome";
          }
        }
      } else if (intent === "volume_set") {
        entity = numberEntity(interpreted);
      }

      if (["open_app", "close_app", "web_search", "spotify_search", "spotify_playlist", "volume_set"].includes(intent) && !entity) {
        confidence *= 0.55;
      }

      return this.result(intent, entity, confidence);
    }

    result(intent, entity, confidence) {
      return {
        intent,
        entity,
        confidence: Math.max(0, Math.min(1, confidence)),
        label: INTENT_LABELS[intent] || intent,
        destructive: intent === "close_app",
      };
    }
  }

  const exported = {
    FridayBrain,
    NaiveBayesIntentClassifier,
    normalize,
    cleanEntity,
    stripWakePhrase,
    readWordsAndInterpret,
    numberEntity,
    TRAINING_DATA,
    PHONETIC_WORDS,
  };

  globalScope.FridayBrain = FridayBrain;
  globalScope.FridayVoice = { stripWakePhrase, readWordsAndInterpret };
  if (typeof module !== "undefined" && module.exports) module.exports = exported;
})(typeof window !== "undefined" ? window : globalThis);

