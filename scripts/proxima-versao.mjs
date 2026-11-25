import { execSync } from 'node:child_process';
import { appendFileSync, writeFileSync } from 'node:fs';

function git(cmd) {
  return execSync(cmd, { encoding: 'utf8' }).trim();
}

function escreverOutput(chave, valor) {
  const arquivo = process.env.GITHUB_OUTPUT;
  if (arquivo) {
    appendFileSync(arquivo, `${chave}=${valor}\n`, 'utf8');
  }
  console.log(`${chave}=${valor}`);
}

const tagsBrutas = git('git tag -l "v*.*.*" --sort=-v:refname');
const ultimaTag = tagsBrutas ? tagsBrutas.split('\n')[0].trim() : '';

const intervalo = ultimaTag ? `${ultimaTag}..HEAD` : 'HEAD';
const logBruto = git(`git log ${intervalo} --format=%s%x1f%b%x1e`);
const commits = logBruto
  .split('\x1e')
  .map((bloco) => bloco.trim())
  .filter(Boolean)
  .map((bloco) => {
    const [assunto = '', corpo = ''] = bloco.split('\x1f');
    return { assunto: assunto.trim(), corpo: corpo.trim() };
  });

const funcionalidades = [];
const correcoes = [];
const breaking = [];

let temMajor = false;
let temMinor = false;
let temPatch = false;

const regexCC = /^([a-z]+)(?:\(([^)]+)\))?(!)?:\s*(.+)$/i;

for (const { assunto, corpo } of commits) {
  const match = assunto.match(regexCC);
  const ehBreaking = Boolean(match?.[3]) || /BREAKING CHANGE:/i.test(corpo);
  if (ehBreaking) {
    temMajor = true;
    breaking.push(assunto);
  }
  if (!match) continue;

  const tipo = match[1].toLowerCase();
  if (tipo === 'feat') {
    temMinor = true;
    funcionalidades.push(assunto);
  } else if (tipo === 'fix' || tipo === 'perf') {
    temPatch = true;
    correcoes.push(assunto);
  }
}

let gerar = false;
let proximaVersao = '';

if (!ultimaTag) {
  gerar = true;
  proximaVersao = '1.0.0';
} else if (temMajor || temMinor || temPatch) {
  gerar = true;
  const [major, minor, patch] = ultimaTag.replace(/^v/, '').split('.').map(Number);
  if (temMajor) {
    proximaVersao = `${major + 1}.0.0`;
  } else if (temMinor) {
    proximaVersao = `${major}.${minor + 1}.0`;
  } else {
    proximaVersao = `${major}.${minor}.${patch + 1}`;
  }
}

escreverOutput('gerar', gerar ? 'true' : 'false');
escreverOutput('versao', proximaVersao);
escreverOutput('tag', proximaVersao ? `v${proximaVersao}` : '');

const linhasNotas = [];
linhasNotas.push(`## GeoRush v${proximaVersao || '0.0.0'}`);
linhasNotas.push('');

if (!ultimaTag) {
  linhasNotas.push('Primeira baseline oficial do projeto GeoRush gerada pelo pipeline de Entrega Contínua.');
  linhasNotas.push('');
}

if (breaking.length > 0) {
  linhasNotas.push('### Mudanças Incompatíveis (Breaking Changes)');
  for (const item of breaking) linhasNotas.push(`- ${item}`);
  linhasNotas.push('');
}

if (funcionalidades.length > 0) {
  linhasNotas.push('### Funcionalidades');
  for (const item of funcionalidades) linhasNotas.push(`- ${item}`);
  linhasNotas.push('');
}

if (correcoes.length > 0) {
  linhasNotas.push('### Correções');
  for (const item of correcoes) linhasNotas.push(`- ${item}`);
  linhasNotas.push('');
}

if (ultimaTag && funcionalidades.length === 0 && correcoes.length === 0 && breaking.length === 0) {
  linhasNotas.push('Sem alterações de funcionalidade ou correção desde a última release.');
}

writeFileSync('notas-release.md', `${linhasNotas.join('\n').trim()}\n`, 'utf8');