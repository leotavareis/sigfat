// Função serverless do Vercel: lê uma fatura PDF com a IA (Claude) e devolve
// as transações em JSON. A chave da Anthropic fica SÓ aqui no servidor —
// nunca é exposta no navegador.
import Anthropic from '@anthropic-ai/sdk'

const client = new Anthropic({ apiKey: process.env.ANTHROPIC_API_KEY })

const PROMPT = `Você é um leitor de faturas de cartão de crédito brasileiras (Nubank, Amazon/Bradescard, Banco do Brasil, C6 Bank e outros).

Extraia TODAS as compras/lançamentos reais desta fatura. Para cada lançamento, retorne:
- "data": dia/mês da compra no formato "DD/MM"
- "descricao": nome do estabelecimento, limpo (sem cidade quando possível, sem "- Parcela X/Y")
- "valor": número (use ponto decimal, ex: 156.60)
- "parcela": { "atual": N, "total": M } APENAS quando for compra parcelada; caso contrário omita o campo

REGRAS:
- IGNORE: pagamentos recebidos, estornos, créditos, "saldo fatura anterior", PGTO, descontos automáticos, valores negativos.
- INCLUA compras parceladas (com o número da parcela atual/total) e compras à vista.
- INCLUA tarifas reais como IOF de assinaturas quando aparecerem como linha própria.
- Mantenha a descrição fiel ao que está na fatura, mas remova o sufixo de parcela da descrição.

Responda SOMENTE com um objeto JSON válido, sem texto antes ou depois, neste formato exato:
{
  "nome": "<nome do banco/cartão>",
  "total": <soma dos valores, número>,
  "transacoes": [
    { "data": "DD/MM", "descricao": "...", "valor": 0.00, "parcela": { "atual": 1, "total": 10 } }
  ]
}`

export default async function handler(req, res) {
  if (req.method !== 'POST') {
    res.status(405).json({ error: 'Método não permitido' })
    return
  }
  if (!process.env.ANTHROPIC_API_KEY) {
    res.status(500).json({ error: 'ANTHROPIC_API_KEY não configurada no servidor' })
    return
  }

  try {
    const { nome, pdfBase64 } = req.body || {}
    if (!pdfBase64) {
      res.status(400).json({ error: 'pdfBase64 ausente' })
      return
    }

    const response = await client.messages.create({
      model: 'claude-sonnet-4-6',
      max_tokens: 16000,
      messages: [{
        role: 'user',
        content: [
          { type: 'document', source: { type: 'base64', media_type: 'application/pdf', data: pdfBase64 } },
          { type: 'text', text: `${PROMPT}\n\nO nome desta fatura é: "${nome || 'Cartão'}". Use-o no campo "nome".` }
        ]
      }]
    })

    const texto = response.content.find(b => b.type === 'text')?.text || ''
    // Extrai o bloco JSON mesmo que venha cercado por crases ou texto
    const match = texto.match(/\{[\s\S]*\}/)
    if (!match) {
      res.status(502).json({ error: 'A IA não retornou JSON válido', raw: texto.slice(0, 500) })
      return
    }
    const bruto = JSON.parse(match[0])

    // Normaliza para o MESMO schema que o sistema já usa (evita quebras):
    // fatura: { nome, total, transacoes: [ { data, descricao, valor, parcela? } ] }
    const transacoes = (bruto.transacoes || []).map(t => {
      const tx = {
        data: String(t.data || ''),
        descricao: String(t.descricao || '').trim(),
        valor: Number(t.valor) || 0
      }
      if (t.parcela && Number(t.parcela.atual) && Number(t.parcela.total)) {
        tx.parcela = { atual: Number(t.parcela.atual), total: Number(t.parcela.total) }
      }
      return tx
    })
    const fatura = {
      nome: bruto.nome || nome || 'Cartão',
      total: Number(bruto.total) || Number(transacoes.reduce((s, t) => s + t.valor, 0).toFixed(2)),
      transacoes
    }
    res.status(200).json(fatura)
  } catch (e) {
    console.error('Erro ao processar fatura:', e)
    res.status(500).json({ error: e.message || 'Erro ao processar a fatura' })
  }
}
