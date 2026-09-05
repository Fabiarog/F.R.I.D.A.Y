(function startFriday() {
  "use strict";

  const brain = new window.FridayBrain();
  const tauriInvoke = window.__TAURI__?.core?.invoke;
  const tauriListen = window.__TAURI__?.event?.listen;
  const isDesktop = typeof tauriInvoke === "function";

  const elements = {
    form: document.getElementById("command-form"),
    input: document.getElementById("command-input"),
    send: document.getElementById("send-button"),
    conversation: document.getElementById("conversation"),
    welcome: document.getElementById("welcome"),
    messages: document.getElementById("message-list"),
    newChat: document.getElementById("new-chat-button"),
    confirmDialog: document.getElementById("confirm-dialog"),
    confirmCopy: document.getElementById("confirm-copy"),
    toastRegion: document.getElementById("toast-region"),
    cpuBadge: document.getElementById("cpu-badge"),
    ramBadge: document.getElementById("ram-badge"),
    voiceButton: document.getElementById("voice-button"),
    voiceNavButton: document.getElementById("voice-nav-button"),
    voiceNavLabel: document.getElementById("voice-nav-label"),
    localLabel: document.getElementById("local-label"),
    audioSettingsButton: document.getElementById("audio-settings-button"),
    audioDialog: document.getElementById("audio-dialog"),
    microphoneSelect: document.getElementById("microphone-select"),
    refreshMicrophones: document.getElementById("refresh-microphones-button"),
    testMicrophone: document.getElementById("test-microphone-button"),
    audioClose: document.getElementById("audio-close-button"),
    audioCancel: document.getElementById("audio-cancel-button"),
    audioMeter: document.getElementById("audio-meter-fill"),
    audioTranscript: document.getElementById("audio-transcript"),
    audioDeviceLabel: document.getElementById("audio-device-label"),
    spotifyConnectButton: document.getElementById("spotify-connect-button"),
    spotifyConnectLabel: document.getElementById("spotify-connect-label"),
    liveSpeechBar: document.getElementById("live-speech-bar"),
    liveSpeechText: document.getElementById("live-speech-text"),
  };

  let working = false;
  let voiceActive = false;
  let wakeArmedUntil = 0;
  let levelResetTimer = 0;
  let silenceWarningTimer = 0;
  let liveSpeechHideTimer = 0;
  const commandQueue = [];

  function showLiveSpeech(text, isFinal = false) {
    if (!elements.liveSpeechBar || !elements.liveSpeechText) return;
    window.clearTimeout(liveSpeechHideTimer);
    const clean = String(text || "").trim();
    if (!clean) {
      elements.liveSpeechBar.hidden = true;
      return;
    }
    const interpreted = window.FridayVoice?.readWordsAndInterpret
      ? window.FridayVoice.readWordsAndInterpret(clean)
      : clean;

    elements.liveSpeechText.textContent = clean !== interpreted
      ? `Ouvindo: “${clean}” ➔ “${interpreted}”`
      : `Ouvindo: “${clean}”`;

    elements.liveSpeechBar.hidden = false;

    if (isFinal) {
      liveSpeechHideTimer = window.setTimeout(() => {
        if (elements.liveSpeechBar) elements.liveSpeechBar.hidden = true;
      }, 3500);
    }
  }

  function selectedDeviceId() {
    const saved = localStorage.getItem("friday.microphoneId");
    if (saved === null || saved === "") return null;
    const value = Number(saved);
    return Number.isInteger(value) ? value : null;
  }

  function assistantAvatar() {
    const wrapper = document.createElement("div");
    wrapper.className = "message-avatar";
    wrapper.innerHTML = '<svg viewBox="0 0 24 24"><path d="M12 3.2a4.4 4.4 0 0 1 4.2 3.1 4.4 4.4 0 0 1 3.1 6.8 4.4 4.4 0 0 1-3.6 6.7 4.4 4.4 0 0 1-7.3.1 4.4 4.4 0 0 1-3.6-6.8 4.4 4.4 0 0 1 3.1-6.8A4.4 4.4 0 0 1 12 3.2Z"/><path d="m8 8.2 4-2.3 4 2.3v4.6l-4 2.3-4-2.3V8.2Z"/></svg>';
    return wrapper;
  }

  function addMessage(role, text, label = "") {
    elements.welcome.hidden = true;
    const article = document.createElement("article");
    article.className = `message ${role}`;

    if (role === "assistant") {
      article.appendChild(assistantAvatar());
    } else {
      const avatar = document.createElement("div");
      avatar.className = "message-avatar";
      avatar.textContent = "VOCÊ";
      article.appendChild(avatar);
    }

    const content = document.createElement("div");
    content.className = "message-content";
    const meta = document.createElement("div");
    meta.className = "message-meta";
    meta.append(document.createTextNode(role === "assistant" ? "F.R.I.D.A.Y." : "Você"));

    if (label) {
      const pill = document.createElement("span");
      pill.className = "intent-pill";
      pill.textContent = label;
      meta.appendChild(pill);
    }

    const body = document.createElement("div");
    body.className = "message-text";
    body.textContent = text;
    content.append(meta, body);
    article.appendChild(content);
    elements.messages.appendChild(article);
    scrollToBottom();
    return article;
  }

  function addTyping() {
    elements.welcome.hidden = true;
    const article = document.createElement("article");
    article.className = "message assistant";
    article.dataset.typing = "true";
    article.appendChild(assistantAvatar());

    const content = document.createElement("div");
    content.className = "message-content";
    const meta = document.createElement("div");
    meta.className = "message-meta";
    meta.textContent = "F.R.I.D.A.Y.";
    const dots = document.createElement("div");
    dots.className = "typing-dots";
    dots.innerHTML = "<i></i><i></i><i></i>";
    content.append(meta, dots);
    article.appendChild(content);
    elements.messages.appendChild(article);
    scrollToBottom();
    return article;
  }

  function scrollToBottom() {
    requestAnimationFrame(() => {
      elements.conversation.scrollTop = elements.conversation.scrollHeight;
    });
  }

  function toast(message, type = "") {
    const node = document.createElement("div");
    node.className = `toast ${type}`.trim();
    node.textContent = message;
    elements.toastRegion.appendChild(node);
    window.setTimeout(() => node.remove(), 3500);
  }

  function setLocalLabel(text) {
    const textNode = Array.from(elements.localLabel.childNodes).find((node) => node.nodeType === Node.TEXT_NODE);
    if (textNode) textNode.textContent = ` ${text}`;
  }

  function setSpotifyStatus(status) {
    const connected = Boolean(status?.connected);
    elements.spotifyConnectLabel.textContent = connected ? "Spotify conectado" : "Conectar Spotify";
    elements.spotifyConnectButton.classList.toggle("active", connected);
    elements.spotifyConnectButton.title = status?.message || "Conectar sua conta para tocar diretamente";
  }

  async function connectSpotify() {
    if (!isDesktop) return;
    try {
      const result = await tauriInvoke("spotify_connect");
      toast(result.message, result.success ? "" : "error");
    } catch (error) {
      toast(`Não consegui iniciar o login do Spotify: ${String(error)}`, "error");
    }
  }

  function setVoiceState(active, status = "") {
    voiceActive = active;
    elements.voiceButton.classList.toggle("active", active);
    elements.voiceNavButton.classList.toggle("active", active);
    elements.voiceButton.setAttribute("aria-pressed", String(active));
    elements.voiceButton.setAttribute("aria-label", active ? "Desativar reconhecimento de voz" : "Ativar reconhecimento de voz");
    elements.voiceButton.title = active ? "Desativar microfone" : "Ativar “Sexta-feira”";
    elements.voiceNavLabel.textContent = active ? "Ouvindo “Sexta-feira”" : "Ativar “Sexta-feira”";
    setLocalLabel(active ? (status || "Ouvindo somente neste dispositivo") : "IA leve · neste dispositivo");
  }

  function extractVoiceCommand(transcript) {
    const spoken = String(transcript || "").trim();
    if (!spoken) return { woke: false, command: "" };

    const wakeCommand = window.FridayVoice?.stripWakePhrase
      ? window.FridayVoice.stripWakePhrase(spoken)
      : null;

    if (wakeCommand !== null) {
      // Reconheceu "Sexta-feira" ou "Friday" — arma a janela de escuta por 10 segundos
      wakeArmedUntil = Date.now() + 10000;
      return { woke: true, command: wakeCommand };
    }

    if (Date.now() < wakeArmedUntil) {
      // Estende a janela ativa enquanto o usuário está falando para não cancelar comandos longos ou pausados
      wakeArmedUntil = Date.now() + 8000;
      return { woke: true, command: spoken };
    }

    return { woke: false, command: "" };
  }

  function handleVoiceTranscript(transcript) {
    const raw = String(transcript || "").trim();
    if (!raw) return;

    elements.audioTranscript.textContent = `Reconhecido: “${raw}”`;
    elements.audioTranscript.classList.add("detected");
    showLiveSpeech(raw, true);

    const heard = extractVoiceCommand(raw);
    if (!heard.woke) return;

    if (!heard.command) {
      addMessage("assistant", "Estou ouvindo. Pode dizer o comando.", "voz local");
      return;
    }

    // Se já estiver processando uma ação anterior, enfileira o comando para NÃO HAVER CANCELAMENTO
    if (working) {
      commandQueue.push(heard.command);
      toast(`Comando “${heard.command}” enfileirado para execução.`);
      return;
    }

    elements.input.value = heard.command;
    resizeInput();
    toast(`Comando ouvido: “${heard.command}”`);
    processCommand(heard.command);
  }

  async function toggleVoice(forceState, deviceId = selectedDeviceId()) {
    if (!isDesktop) {
      toast("O microfone está disponível somente no aplicativo instalado.", "error");
      return;
    }
    const shouldEnable = typeof forceState === "boolean" ? forceState : !voiceActive;
    try {
      const result = shouldEnable
        ? await tauriInvoke("voice_start", { deviceId })
        : await tauriInvoke("voice_stop");
      if (!result.success) {
        localStorage.removeItem("friday.voiceEnabled");
        setVoiceState(false);
        toast(result.message, "error");
        return;
      }
      setVoiceState(shouldEnable, shouldEnable ? "Iniciando microfone local…" : "");
      if (shouldEnable) {
        localStorage.setItem("friday.voiceEnabled", "true");
        wakeArmedUntil = Date.now() + 12000;
      } else {
        localStorage.removeItem("friday.voiceEnabled");
        wakeArmedUntil = 0;
      }
      toast(result.message);
    } catch (error) {
      localStorage.removeItem("friday.voiceEnabled");
      setVoiceState(false);
      toast(`Não consegui alterar o microfone: ${String(error)}`, "error");
    }
  }

  async function loadMicrophones() {
    if (!isDesktop) return;
    elements.microphoneSelect.disabled = true;
    elements.microphoneSelect.replaceChildren(new Option("Consultando microfones…", ""));
    try {
      const devices = await tauriInvoke("voice_devices");
      elements.microphoneSelect.replaceChildren();
      if (!devices.length) {
        elements.microphoneSelect.appendChild(new Option("Nenhum microfone encontrado", ""));
        elements.testMicrophone.disabled = true;
        return;
      }
      const saved = selectedDeviceId();
      devices.forEach((device) => {
        const suffix = device.is_default ? " · padrão do Windows" : "";
        const option = new Option(`${device.name}${suffix}`, String(device.id));
        option.selected = saved === device.id || (saved === null && device.is_default);
        elements.microphoneSelect.appendChild(option);
      });
      if (!elements.microphoneSelect.value) elements.microphoneSelect.selectedIndex = 0;
      elements.microphoneSelect.disabled = false;
      elements.testMicrophone.disabled = false;
    } catch (error) {
      elements.microphoneSelect.replaceChildren(new Option("Falha ao listar microfones", ""));
      elements.testMicrophone.disabled = true;
      toast(`Não consegui consultar os microfones: ${String(error)}`, "error");
    }
  }

  async function openAudioSettings() {
    elements.audioTranscript.textContent = "Clique em “Usar e testar” e fale normalmente. A transcrição aparecerá aqui mesmo sem dizer “Sexta-feira”.";
    elements.audioTranscript.classList.remove("detected");
    elements.audioMeter.style.width = "0%";
    elements.audioDialog.showModal();
    await loadMicrophones();
  }

  async function testSelectedMicrophone() {
    const deviceId = Number(elements.microphoneSelect.value);
    if (!Number.isInteger(deviceId)) return;
    localStorage.setItem("friday.microphoneId", String(deviceId));
    elements.audioTranscript.textContent = "Iniciando o teste… fale uma frase perto do microfone.";
    elements.audioTranscript.classList.remove("detected");
    elements.testMicrophone.disabled = true;
    if (voiceActive) {
      await toggleVoice(false);
      await new Promise((resolve) => window.setTimeout(resolve, 220));
    }
    await toggleVoice(true, deviceId);
    window.clearTimeout(silenceWarningTimer);
    silenceWarningTimer = window.setTimeout(() => {
      if (elements.audioDialog.open && Number.parseFloat(elements.audioMeter.style.width) < 2) {
        elements.audioTranscript.textContent = "Nenhum sinal de áudio foi detectado. Verifique se o headset está no mudo ou tente outro microfone da lista.";
        elements.audioTranscript.classList.remove("detected");
      }
    }, 4500);
    elements.testMicrophone.disabled = false;
  }

  async function initializeVoice() {
    if (!isDesktop || typeof tauriListen !== "function") return;
    await tauriListen("voice-status", (event) => {
      setVoiceState(true, "Ouvindo “Sexta-feira” neste dispositivo");
      toast(String(event.payload || "Microfone local ativo."));
    });
    await tauriListen("voice-transcript", (event) => handleVoiceTranscript(event.payload));
    await tauriListen("voice-partial", (event) => {
      const partial = String(event.payload || "").trim();
      if (!partial) return;
      showLiveSpeech(partial, false);
      if (elements.audioDialog.open) {
        elements.audioTranscript.textContent = `Identificando: “${partial}”`;
        elements.audioTranscript.classList.add("detected");
      }
    });
    await tauriListen("voice-level", (event) => {
      const level = Math.max(0, Math.min(100, Number(event.payload) || 0));
      if (level >= 2) window.clearTimeout(silenceWarningTimer);
      elements.audioMeter.style.width = `${level}%`;
      window.clearTimeout(levelResetTimer);
      levelResetTimer = window.setTimeout(() => { elements.audioMeter.style.width = "0%"; }, 420);
    });
    await tauriListen("voice-device", (event) => {
      elements.audioDeviceLabel.textContent = String(event.payload || "Microfone ativo");
    });
    await tauriListen("voice-warning", (event) => toast(String(event.payload), "error"));
    await tauriListen("voice-error", (event) => {
      localStorage.removeItem("friday.voiceEnabled");
      setVoiceState(false);
      toast(String(event.payload), "error");
    });
    await tauriListen("voice-stopped", async () => {
      const stillActive = await tauriInvoke("voice_is_active").catch(() => false);
      if (voiceActive && !stillActive) {
        localStorage.removeItem("friday.voiceEnabled");
        setVoiceState(false);
      }
    });

    await tauriListen("spotify-status", (event) => {
      const status = event.payload || {};
      setSpotifyStatus(status);
      if (status.message) toast(String(status.message), status.connected ? "" : "error");
    });

    try {
      setSpotifyStatus(await tauriInvoke("spotify_status"));
    } catch (_) {}

    if (localStorage.getItem("friday.voiceEnabled") === "true") {
      toggleVoice(true);
    }
  }

  function localResponse(prediction) {
    const now = new Date();
    switch (prediction.intent) {
      case "greeting":
        return "Olá! Estou pronta. Posso abrir ou fechar aplicativos, procurar músicas no Spotify, pesquisar no Google e controlar sua mídia.";
      case "get_time":
        return `Agora são ${now.toLocaleTimeString("pt-BR", { hour: "2-digit", minute: "2-digit" })}.`;
      case "get_date":
        return `Hoje é ${now.toLocaleDateString("pt-BR", { weekday: "long", day: "2-digit", month: "long", year: "numeric" })}.`;
      case "help":
        return [
          "Posso ajudar com comandos como:",
          "• “Abra o Spotify” ou “Abra o Minecraft”",
          "• “Toque Starboy” ou “Toque a playlist Descobertas da Semana”",
          "• “Pesquise previsão do tempo no Google”",
          "• “Feche o Discord” — com confirmação",
          "• “Pause a música”, “Próxima faixa” ou “Volume em 40%”",
          "Tudo é reconhecido localmente e eu não executo comandos arbitrários de terminal.",
        ].join("\n");
      case "unknown":
        return "Não entendi essa ação com segurança. Tente algo direto, como “abra a calculadora”, “pesquise gatos no Google” ou “coloque uma música no Spotify”.";
      default:
        return null;
    }
  }

  function missingEntityResponse(prediction) {
    if (prediction.entity) return null;
    if (prediction.intent === "open_app") return "Qual aplicativo ou jogo você quer abrir?";
    if (prediction.intent === "close_app") return "Qual aplicativo você quer fechar?";
    if (prediction.intent === "web_search") return "O que você quer pesquisar no Google?";
    if (prediction.intent === "spotify_search") return "Qual música, artista ou playlist você quer procurar no Spotify?";
    if (prediction.intent === "spotify_playlist") return "Qual playlist você quer abrir no Spotify?";
    if (prediction.intent === "volume_set") return "Qual nível de volume você quer, de 0 a 100%?";
    return null;
  }

  function confirmClose(target) {
    return new Promise((resolve) => {
      elements.confirmCopy.textContent = `Vou solicitar ao Windows que encerre “${target}”. Alterações não salvas nesse aplicativo podem ser perdidas.`;
      const onClose = () => {
        elements.confirmDialog.removeEventListener("close", onClose);
        resolve(elements.confirmDialog.returnValue === "confirm");
      };
      elements.confirmDialog.addEventListener("close", onClose);
      elements.confirmDialog.showModal();
    });
  }

  async function executeNative(prediction) {
    if (!isDesktop) {
      return {
        success: false,
        message: "A interface está em modo de visualização. Inicie pelo aplicativo Tauri para executar ações no Windows.",
      };
    }

    try {
      return await tauriInvoke("execute_intent", {
        intent: prediction.intent,
        entity: prediction.entity || "",
      });
    } catch (error) {
      return { success: false, message: `Não consegui concluir a ação: ${String(error)}` };
    }
  }

  async function processCommand(rawText) {
    const text = String(rawText || "").trim();
    if (!text || working) return;

    working = true;
    updateComposerState();
    addMessage("user", text);
    elements.input.value = "";
    resizeInput();
    const typing = addTyping();

    await new Promise((resolve) => window.setTimeout(resolve, 180));
    const prediction = brain.classify(text);
    const simpleResponse = localResponse(prediction);
    const missingResponse = missingEntityResponse(prediction);

    typing.remove();

    if (simpleResponse || missingResponse) {
      addMessage("assistant", simpleResponse || missingResponse, prediction.label);
      finishCommand();
      return;
    }

    if (prediction.destructive) {
      const confirmed = await confirmClose(prediction.entity);
      if (!confirmed) {
        addMessage("assistant", "Tudo bem — não fechei o aplicativo.", prediction.label);
        finishCommand();
        return;
      }
    }

    const result = await executeNative(prediction);
    addMessage("assistant", result.message, prediction.label);
    if (!result.success) toast(result.message, "error");

    finishCommand();
  }

  function finishCommand() {
    working = false;
    updateComposerState();
    elements.input.focus();
    if (commandQueue.length > 0) {
      const nextCommand = commandQueue.shift();
      window.setTimeout(() => processCommand(nextCommand), 320);
    }
  }

  function updateComposerState() {
    elements.send.disabled = working || !elements.input.value.trim();
  }

  function resizeInput() {
    elements.input.style.height = "auto";
    elements.input.style.height = `${Math.min(elements.input.scrollHeight, 110)}px`;
    updateComposerState();
  }

  function resetConversation() {
    elements.messages.replaceChildren();
    elements.welcome.hidden = false;
    elements.input.value = "";
    resizeInput();
    elements.conversation.scrollTop = 0;
    elements.input.focus();
  }

  function useCommand(command) {
    if (command === "pesquise no Google") {
      elements.input.value = "pesquise ";
      resizeInput();
      elements.input.focus();
      elements.input.setSelectionRange(elements.input.value.length, elements.input.value.length);
      return;
    }
    processCommand(command);
  }

  async function updateTelemetry() {
    if (!isDesktop) return;
    try {
      const snapshot = await tauriInvoke("system_snapshot");
      elements.cpuBadge.textContent = `CPU ${Math.round(snapshot.cpu_percent)}%`;
      elements.ramBadge.textContent = `RAM ${Math.round(snapshot.memory_percent)}%`;
    } catch (_) {
      elements.cpuBadge.textContent = "CPU —%";
      elements.ramBadge.textContent = "RAM —%";
    }
  }

  async function windowCommand(command) {
    if (!isDesktop) return;
    try {
      await tauriInvoke(command);
    } catch (error) {
      toast(`Controle de janela indisponível: ${String(error)}`, "error");
    }
  }

  elements.form.addEventListener("submit", (event) => {
    event.preventDefault();
    processCommand(elements.input.value);
  });

  elements.input.addEventListener("input", resizeInput);
  elements.input.addEventListener("keydown", (event) => {
    if (event.key === "Enter" && !event.shiftKey) {
      event.preventDefault();
      elements.form.requestSubmit();
    }
  });

  elements.newChat.addEventListener("click", resetConversation);
  elements.voiceButton.addEventListener("click", () => toggleVoice());
  elements.voiceNavButton.addEventListener("click", () => toggleVoice());
  elements.audioSettingsButton.addEventListener("click", openAudioSettings);
  elements.spotifyConnectButton.addEventListener("click", connectSpotify);
  elements.refreshMicrophones.addEventListener("click", loadMicrophones);
  elements.testMicrophone.addEventListener("click", testSelectedMicrophone);
  elements.audioClose.addEventListener("click", () => elements.audioDialog.close());
  elements.audioCancel.addEventListener("click", () => elements.audioDialog.close());
  elements.microphoneSelect.addEventListener("change", () => {
    if (elements.microphoneSelect.value) {
      localStorage.setItem("friday.microphoneId", elements.microphoneSelect.value);
    }
  });
  document.querySelectorAll("[data-command]").forEach((button) => {
    button.addEventListener("click", () => useCommand(button.dataset.command));
  });

  document.getElementById("model-info-button").addEventListener("click", () => {
    toast("Classificador Naive Bayes local · sem modelo generativo · sem envio de dados");
  });
  document.getElementById("minimize-button").addEventListener("click", () => windowCommand("cmd_minimize"));
  document.getElementById("maximize-button").addEventListener("click", () => windowCommand("cmd_maximize"));
  document.getElementById("close-button").addEventListener("click", () => windowCommand("cmd_close"));

  updateTelemetry();
  window.setInterval(updateTelemetry, 3000);
  initializeVoice();
  resizeInput();
  window.setTimeout(() => elements.input.focus(), 250);

  if (!isDesktop) {
    toast("Modo de visualização: ações do Windows estão desativadas.");
  }
})();
