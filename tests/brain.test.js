const test = require("node:test");
const assert = require("node:assert/strict");
const fs = require("node:fs");
const path = require("node:path");

const { FridayBrain, NaiveBayesIntentClassifier, normalize, stripWakePhrase } = require("../frontend/brain.js");

const brain = new FridayBrain();

const cases = [
  ["abra o Spotify", "open_app", "Spotify"],
  ["Pode abrir o Minecraft?", "open_app", "Minecraft"],
  ["feche o Discord", "close_app", "Discord"],
  ["coloque Starboy no Spotify", "spotify_search", "Starboy"],
  ["toque a música Starboy", "spotify_search", "Starboy"],
  ["toque a playlist Descobertas da Semana", "spotify_playlist", "Descobertas da Semana"],
  ["pesquise clima em São Paulo no Google", "web_search", "clima em São Paulo"],
  ["próxima música", "media_next", ""],
  ["volte para a faixa anterior", "media_previous", ""],
  ["pause a música", "media_play_pause", ""],
  ["aumente o volume", "volume_up", ""],
  ["abaixe o som", "volume_down", ""],
  ["coloque o volume em 40%", "volume_set", "40"],
  ["que horas são?", "get_time", ""],
  ["qual a data de hoje?", "get_date", ""],
  ["o que você sabe fazer?", "help", ""],
];

for (const [phrase, expectedIntent, expectedEntity] of cases) {
  test(`reconhece: ${phrase}`, () => {
    const result = brain.classify(phrase);
    assert.equal(result.intent, expectedIntent);
    assert.equal(result.entity, expectedEntity);
    assert.ok(result.confidence > 0);
  });
}

test("normalização remove acentos e preserva números", () => {
  assert.equal(normalize("  Música em 50%  "), "musica em 50%");
});

test("classificador estatístico é treinado localmente", () => {
  const classifier = new NaiveBayesIntentClassifier();
  const prediction = classifier.predict("inicie um programa");
  assert.equal(prediction.intent, "open_app");
  assert.ok(prediction.confidence > 0.2);
});

test("frontend ativo não depende de localhost ou WebSocket", () => {
  const frontend = path.join(__dirname, "..", "frontend");
  const source = ["index.html", "app.js", "brain.js"]
    .map((file) => fs.readFileSync(path.join(frontend, file), "utf8"))
    .join("\n");
  assert.doesNotMatch(source, /localhost/i);
  assert.doesNotMatch(source, /WebSocket/);
});

test("palavra de ativação em português extrai somente o comando", () => {
  assert.equal(stripWakePhrase("Sexta-feira, abra o Spotify"), "abra o Spotify");
  assert.equal(stripWakePhrase("sexta feira abra o Steam"), "abra o Steam");
  assert.equal(stripWakePhrase("sexta-feira"), "");
  assert.equal(stripWakePhrase("ei sexta fera abra o Spotify"), "abra o Spotify");
  assert.equal(stripWakePhrase("cesta feira toque uma música"), "toque uma música");
  assert.equal(stripWakePhrase("sexta feira abril de discorde"), "abril de discorde");
  assert.equal(stripWakePhrase("nesta feira abre o discorde"), "abre o discorde");
  assert.equal(stripWakePhrase("fala sexta feira abre o discord"), "abre o discord");
  assert.equal(stripWakePhrase("cesta abrir discorde"), "abrir discorde");
  assert.equal(stripWakePhrase("abra o Spotify"), null);
});

test("palavra de ativação em inglês e variações fonéticas", () => {
  assert.equal(stripWakePhrase("Friday, open Discord"), "open Discord");
  assert.equal(stripWakePhrase("Hey Friday, play some music"), "play some music");
  assert.equal(stripWakePhrase("frai dei abra o spotify"), "abra o spotify");
  assert.equal(stripWakePhrase("Sexta freira, abra o Discord"), "abra o Discord");
  assert.equal(stripWakePhrase("ok Friday"), "");
});

const englishAndPhoneticCases = [
  // Termos em inglês puros
  ["open Discord", "open_app", "Discord"],
  ["open Spotify", "open_app", "Spotify"],
  ["close Spotify", "close_app", "Spotify"],
  ["open Minecraft", "open_app", "Minecraft"],
  ["open Chrome", "open_app", "Chrome"],
  ["play Starboy on Spotify", "spotify_search", "Starboy"],
  ["next track", "media_next", ""],
  ["pause the music", "media_play_pause", ""],
  ["mute the sound", "volume_mute", ""],
  ["set volume to fifty", "volume_set", "50"],
  ["what time is it", "get_time", ""],
  ["what day is today", "get_date", ""],

  // Termos fonéticos produzidos pelo Vosk ao ouvir inglês e fala rápida/coloquial
  ["abril de discorde", "open_app", "Discord"],
  ["abril discorde", "open_app", "Discord"],
  ["abril de discord", "open_app", "Discord"],
  ["abril o discorde", "open_app", "Discord"],
  ["abril de spotify", "open_app", "Spotify"],
  ["abril spotify", "open_app", "Spotify"],
  ["abri discorde", "open_app", "Discord"],
  ["abriu o discorde", "open_app", "Discord"],
  ["fechar de discorde", "close_app", "Discord"],
  ["fechar de discord", "close_app", "Discord"],
  ["abrir discorde", "open_app", "Discord"],
  ["fechar discorde", "close_app", "Discord"],
  ["abrir o discorde", "open_app", "Discord"],
  ["feche o discorde", "close_app", "Discord"],
  ["abrir spotify", "open_app", "Spotify"],
  ["abrir espotifai", "open_app", "Spotify"],
  ["abrir spotfy", "open_app", "Spotify"],
  ["abrir espotify", "open_app", "Spotify"],
  ["abrir esporte vai", "open_app", "Spotify"],
  ["abra o espotifai", "open_app", "Spotify"],
  ["fechar espotifai", "close_app", "Spotify"],
  ["abra o maincrafte", "open_app", "Minecraft"],
  ["inicie a istime", "open_app", "Steam"],
  ["abra o crome", "open_app", "Chrome"],
  ["abra o uotizape", "open_app", "WhatsApp"],
  ["toca starboy no espotifai", "spotify_search", "Starboy"],
  ["coloque starboy no esporte vai", "spotify_search", "Starboy"],
  ["dar plei na musica", "media_play_pause", ""],
  ["dar pauze", "media_play_pause", ""],
  ["passa para a nexte", "media_next", ""],
  ["miute o som", "volume_mute", ""],
  ["volume em cinquenta", "volume_set", "50"],
];

for (const [phrase, expectedIntent, expectedEntity] of englishAndPhoneticCases) {
  test(`interpreta termo em inglês/fonético: ${phrase}`, () => {
    const result = brain.classify(phrase);
    assert.equal(result.intent, expectedIntent);
    assert.equal(result.entity, expectedEntity);
  });
}

