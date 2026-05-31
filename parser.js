// ─── PARSERS ESPECÍFICOS POR BANCO ───────────────────────────────────────────
// Detecta o banco pelo conteúdo do texto e extrai transações

export function detectarBanco(texto) {
  if (/Nu Pagamentos|nubank/i.test(texto)) return 'nubank'
  if (/AMAZON MASTERCARD|Bradescard|AMAZONMKTPLC/i.test(texto)) return 'amazon'
  if (/BANCO DO BRASIL|SMILES|Ourocard/i.test(texto)) return 'bb'
  if (/C6 BANK|C6Bank|C6 Carbon/i.test(texto)) return 'c6'
  return 'desconhecido'
}

// ─── NUBANK ──────────────────────────────────────────────────────────────────
// Padrão: "24 ABR CRO-RN - Parcela 2/4\nR$ 156,60"
// ou: "28 ABR Apple.Com/Bill. R$ 19,90"
function parsearNubank(texto) {
  const transacoes = []
  const meses = { JAN:1,FEV:2,MAR:3,ABR:4,MAI:5,JUN:6,JUL:7,AGO:8,SET:9,OUT:10,NOV:11,DEZ:12 }

  // Encontrar seção de transações
  const secao = texto.match(/TRANSAÇÕES DE[\s\S]*/i)?.[0] || texto

  // Padrão: DD MMM descrição ... R$ valor (pode ter quebra de linha entre descrição e valor)
  const regex = /(\d{2})\s+(JAN|FEV|MAR|ABR|MAI|JUN|JUL|AGO|SET|OUT|NOV|DEZ)\s+(.+?)\s+R\$\s*([\d\.]+,\d{2})/gi
  let match

  while ((match = regex.exec(secao)) !== null) {
    const dia = match[1]
    const mes = match[2]
    const desc = match[3].trim()
    const valor = parseValor(match[4])

    // Ignorar pagamentos, estornos, saldo anterior
    if (/Pagamento em|Saldo restante|−R\$|pagamento recebido/i.test(desc)) continue
    if (valor <= 0) continue

    transacoes.push({
      data: `${dia}/${String(meses[mes.toUpperCase()]).padStart(2,'0')}`,
      descricao: limparDesc(desc),
      valor
    })
  }

  return transacoes
}

// ─── AMAZON (BRADESCARD) ─────────────────────────────────────────────────────
// Padrão: "14/01 AMAZONMKTPLC*FUTUROTEC DIADEMA (05/05) 44,33"
function parsearAmazon(texto) {
  const transacoes = []

  // Seção de lançamentos
  const secao = texto.match(/Lançamentos[\s\S]*/i)?.[0] || texto

  // Padrão: DD/MM DESCRIÇÃO valor
  const regex = /(\d{2}\/\d{2})\s+([A-ZÁÉÍÓÚÀÂÃÊÔÕÇ][^\n\r]{3,60?}?)\s{2,}([\d]+,\d{2})\s*$/gm
  let match

  while ((match = regex.exec(secao)) !== null) {
    const data = match[1]
    const desc = match[2].trim()
    const valor = parseValor(match[3])

    if (/PAGAMENTO RECEBIDO|OBRIGADO/i.test(desc)) continue
    if (valor <= 0) continue

    transacoes.push({ data, descricao: limparDesc(desc), valor })
  }

  // Fallback: padrão mais simples
  if (transacoes.length === 0) {
    const regex2 = /(\d{2}\/\d{2})\s+(.+?)\s+([\d]+,\d{2})\s*\n/g
    while ((match = regex2.exec(secao)) !== null) {
      const data = match[1]
      const desc = match[2].trim()
      const valor = parseValor(match[3])
      if (/PAGAMENTO|OBRIGADO/i.test(desc)) continue
      if (valor <= 0) continue
      transacoes.push({ data, descricao: limparDesc(desc), valor })
    }
  }

  return transacoes
}

// ─── BANCO DO BRASIL ─────────────────────────────────────────────────────────
// Padrão: "07/05 ASAAS *life academia Sao Goncalo d BR R$ 110,00"
function parsearBB(texto) {
  const transacoes = []
  const meses = { JAN:1,FEV:2,MAR:3,ABR:4,MAI:5,JUN:6,JUL:7,AGO:8,SET:9,OUT:10,NOV:11,DEZ:12 }

  // Seção de lançamentos
  const secao = texto.match(/Lançamentos nesta fatura[\s\S]*/i)?.[0] || texto

  // Padrão: DD/MM DESCRIÇÃO BR R$ valor
  const regex = /(\d{2}\/\d{2})\s+(.+?)\s+BR\s+R\$\s*([\d\.]+,\d{2})/g
  let match

  while ((match = regex.exec(secao)) !== null) {
    const data = match[1]
    const desc = match[2].trim()
    const valor = parseValor(match[3])

    if (/PAGAMENTO|PGTO|DESC AUTOMATICO|SALDO FATURA/i.test(desc)) continue
    if (valor <= 0) continue

    transacoes.push({ data, descricao: limparDesc(desc), valor })
  }

  // Compras parceladas (sem BR antes)
  const regexParc = /(\d{2}\/\d{2})\s+(.+?PARC\s+\d+\/\d+.+?)\s+BR\s+R\$\s*([\d\.]+,\d{2})/gi
  while ((match = regexParc.exec(secao)) !== null) {
    // já capturado acima
  }

  return transacoes
}

// ─── C6 BANK ─────────────────────────────────────────────────────────────────
// Padrão: " 25 abr SHOPEE *GSHOMEDECOR - Parcela 1/3 234,99"
// Múltiplos cartões: principal + adicionais
function parsearC6(texto) {
  const transacoes = []
  const meses = { jan:1,fev:2,mar:3,abr:4,mai:5,jun:6,jul:7,ago:8,set:9,out:10,nov:11,dez:12 }

  // Padrão C6: DD mmm DESCRIÇÃO valor (no final da linha)
  const regex = /(\d{2})\s+(jan|fev|mar|abr|mai|jun|jul|ago|set|out|nov|dez)\s+(.+?)\s+([\d]+[.,]\d{2})\s*$/gmi
  let match

  while ((match = regex.exec(texto)) !== null) {
    const dia = match[1]
    const mes = match[2].toLowerCase()
    const desc = match[3].trim()
    const valor = parseValor(match[4])

    // Ignorar pagamentos, estornos, inclusão de pagamento, anuidade
    if (/Inclusao de Pagamento|Estorno|Anuidade Diferenciada.*Estorno/i.test(desc)) continue
    if (valor <= 0) continue

    transacoes.push({
      data: `${dia}/${String(meses[mes]).padStart(2,'0')}`,
      descricao: limparDesc(desc),
      valor
    })
  }

  return transacoes
}

// ─── UTILS ───────────────────────────────────────────────────────────────────
function parseValor(str) {
  if (!str) return 0
  return parseFloat(str.replace(/\./g, '').replace(',', '.')) || 0
}

function limparDesc(desc) {
  return desc
    .replace(/\s*-\s*Parcela\s+\d+\/\d+/i, '') // remove "- Parcela X/Y"
    .replace(/\((\d+\/\d+)\)/g, '')              // remove "(X/Y)"
    .replace(/\s+/g, ' ')
    .trim()
}

// ─── ENTRADA PRINCIPAL ───────────────────────────────────────────────────────
export function parsearFatura(texto, nomeArquivo) {
  const banco = detectarBanco(texto)
  let transacoes = []

  switch (banco) {
    case 'nubank': transacoes = parsearNubank(texto); break
    case 'amazon': transacoes = parsearAmazon(texto); break
    case 'bb':     transacoes = parsearBB(texto); break
    case 'c6':     transacoes = parsearC6(texto); break
    default:
      // Fallback genérico: qualquer linha com data e valor monetário
      transacoes = parsearGenerico(texto)
  }

  return transacoes.map(tx => ({
    ...tx,
    banco,
    nomeArquivo: nomeArquivo.replace(/\.[^.]+$/, '')
  }))
}

function parsearGenerico(texto) {
  const transacoes = []
  const regex = /(\d{2}[\/\s]\d{2}(?:[\/\s]\d{2,4})?)\s+(.{5,60}?)\s+R?\$?\s*([\d]+[.,]\d{2})\s*$/gm
  let match
  while ((match = regex.exec(texto)) !== null) {
    const valor = parseValor(match[3])
    if (valor <= 0 || valor > 50000) continue
    transacoes.push({ data: match[1].trim(), descricao: limparDesc(match[2]), valor })
  }
  return transacoes
}
